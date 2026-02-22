# Part 3: The Modern Rebuild — Here's How You'd Build It Today

*Series: Modernizing a Cloud-Init Repo — from 2012 Shell Scripts to Production-Grade IaC*

---

Parts 1 and 2 were about understanding what worked, what aged, and why. This part is about building it right, today.

Same problem, same goal: provision N identical EC2 instances, fully configured, reproducibly. But now with the tooling that 13 years of production pain has given us.

I've added a `/modern` directory to the original repo with working, runnable code for every layer. Let's walk through it.

---

## The Stack

| Layer | 2012 | 2025 |
|---|---|---|
| Orchestration | `create_instance.sh` (bash) | Terraform |
| Instance bootstrap | bash script as user-data | `#cloud-config` YAML |
| Config management | Chef 14 / Ansible (downloaded at boot) | Ansible 9+ baked into AMI via Packer |
| OS | RHEL 7 (EOL) | Amazon Linux 2023 |
| Access | SSH + port 22 + key pair | SSM Session Manager, zero open ports |
| Secrets | Hardcoded or positional args | SSM Parameter Store |
| Lifecycle | `terminate_instances.sh` | `terraform destroy` |
| CI/CD | Manual | GitHub Actions + OIDC |

---

## Layer 1: Terraform Replaces the Shell Script

The original `create_instance.sh` was 30 lines of bash that called `aws ec2 run-instances` with hardcoded values and positional arguments.

The modern equivalent is a Terraform configuration that's declarative, state-managed, and safe to run repeatedly.

```hcl
# Dynamically resolve the latest Amazon Linux 2023 AMI — no hardcoded IDs
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
```

No more `ami-28e07e50`. The AMI is resolved at `terraform plan` time — always the latest, always the right region, always patched.

The instance creation itself moves from a one-shot `run-instances` call to a proper Launch Template + Auto Scaling Group:

```hcl
resource "aws_launch_template" "demo" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.demo.name  # Roles, not key pairs
  }

  user_data = base64encode(templatefile("cloud-config.yaml", {
    project_name   = var.project_name
    agent_hostname = var.agent_hostname
    users          = var.demo_users
  }))

  metadata_options {
    http_tokens = "required"  # IMDSv2 only — blocks SSRF attacks
  }
}

resource "aws_autoscaling_group" "demo" {
  desired_capacity = var.instance_count
  min_size         = 0
  max_size         = 20

  launch_template {
    id      = aws_launch_template.demo.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"  # Rolling updates instead of terminate-and-recreate
  }
}
```

**The key differences from the original:**
- `terraform plan` shows exactly what will be created before anything happens
- `terraform destroy` replaces `terminate_instances.sh` — and it tracks everything it created
- Rolling updates instead of terminate-and-recreate
- State file means no orphaned instances

---

## Layer 2: cloud-config YAML Replaces the Bash User-Data

The original cloud-init files were bash scripts that cloud-init executed. The modern format is proper YAML using cloud-init's built-in modules.

```yaml
#cloud-config

# Hostname — one line, no scripting
hostname: ${agent_hostname}
fqdn: ${agent_hostname}.internal
manage_etc_hosts: true

# Users and groups — declarative, idempotent, distro-agnostic
groups:
  - my-staff

users:
  - default
  - name: alice
    groups: [my-staff]
    shell: /bin/bash
    lock_passwd: true   # No password auth — SSM access only
  - name: bob
    groups: [my-staff]
    shell: /bin/bash
    lock_passwd: true

# Packages — cloud-init handles the package manager
package_update: true
packages:
  - git
  - ansible-core

# Write files declaratively — no echo/cat scripting
write_files:
  - path: /etc/mon-agent/agent.conf
    permissions: "0644"
    content: |
      hostname=${agent_hostname}
      log_level=INFO

# runcmd only for what modules can't handle
runcmd:
  - /opt/demo/run-playbook.sh
```

The bash user-data was ~40 lines of imperative scripting. The YAML cloud-config is shorter, readable, and validated by `cloud-init schema --config-file cloud-config.yaml` before it ever touches an instance.

The `${agent_hostname}` and `${users}` variables are injected by Terraform's `templatefile()` function at plan time — so the cloud-config is parameterized without any bash string manipulation.

---

## Layer 3: Zero-Port Security with SSM

The original required port 22 open and a key pair to access instances. The modern setup has:

```hcl
resource "aws_iam_role" "demo_instance" {
  name = "${var.project_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.demo_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_security_group" "demo" {
  # No inbound rules at all — zero open ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

To access an instance:

```bash
# Before: ssh -i mykey.pem ec2-user@1.2.3.4  (port 22 open)
# After:
aws ssm start-session --target i-0abc1234567890def
```

No open ports. No key pair. Full CloudTrail audit log of every session. Works in private subnets with no public IPs.

---

## Layer 4: Packer for Pre-Baked AMIs

The original downloaded and installed Chef/Ansible at instance boot time. Every instance spent minutes downloading packages from external sources before becoming useful.

Packer flips this: build a custom AMI once, with everything already installed. Instances launch in seconds.

```hcl
# packer.pkr.hcl

source "amazon-ebs" "al2023" {
  ami_name      = "${var.project_name}-${formatdate("YYYY-MM-DD", timestamp())}"
  instance_type = "t3.micro"

  # Dynamic AMI resolution — same pattern as Terraform
  source_ami_filter {
    filters = { name = "al2023-ami-*-x86_64" }
    most_recent = true
    owners      = ["amazon"]
  }
}

build {
  sources = ["source.amazon-ebs.al2023"]

  # Install everything at AMI build time — not instance launch time
  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y git rpm-build ansible-core",
    ]
  }

  # Build and bake the monitoring agent RPM into the AMI
  provisioner "shell" {
    inline = [
      "git clone https://github.com/chefgs/create_dummy_rpm.git /tmp/rpm_build/",
      "cd /tmp/rpm_build && ./create_rpm.sh spec_file/my-monitoring-agent.spec",
      "sudo rpm -i /tmp/rpm_build/RPMS/noarch/my-monitoring-agent-*.rpm",
    ]
  }

  # Run Ansible to configure the base system
  provisioner "ansible" {
    playbook_file = "playbook.yml"
  }

  # Clean build artifacts before snapshotting the AMI
  provisioner "shell" {
    inline = ["sudo dnf clean all", "sudo rm -rf /tmp/*"]
  }
}
```

Think of the Packer AMI the same way you think of a container image. It's a versioned, tested artifact. You build it in CI, you test it, and you ship it to production. Rollback is launching the previous AMI version.

The cloud-config YAML then handles only the per-instance, runtime-specific config: hostname, per-environment variables, users. Everything else is already on the AMI.

---

## Layer 5: GitHub Actions Replaces Manual Execution

The original workflow was manual: clone, run script, wait, check. The modern workflow is a pipeline.

```yaml
# .github/workflows/deploy.yml

name: Deploy Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  plan:
    runs-on: ubuntu-latest
    permissions:
      id-token: write    # OIDC — no stored AWS credentials

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: us-east-1

      - name: Terraform Plan
        run: |
          terraform init
          terraform plan -out=tfplan

  apply:
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production    # Requires manual approval in GitHub UI

    steps:
      - name: Terraform Apply
        run: terraform apply tfplan
```

**What this gives you:**
- **No stored AWS credentials** — OIDC federated identity instead
- **Plan on every PR** — reviewers see exactly what will change before approving
- **Manual approval gate** via GitHub Environments before any production apply
- **Full audit trail** — every run is logged in GitHub Actions history

---

## The Migration Path

If you're working with an existing repo structured like the original, here's how to move incrementally:

**Phase 1 — Security wins, low effort**
- Replace hardcoded AMI ID with a dynamic data source or SSM parameter lookup
- Add an IAM instance profile with SSM; remove the key pair requirement and close port 22
- Update RHEL 7 → Amazon Linux 2023

**Phase 2 — Proper IaC**
- Wrap the `aws ec2 run-instances` call in Terraform
- Use `aws_launch_template` + `aws_autoscaling_group`
- Store Terraform state in S3 + DynamoDB for team use

**Phase 3 — Immutable AMIs**
- Build a Packer AMI in CI with software pre-installed
- cloud-config YAML handles only final runtime configuration
- Instances launch in seconds, with no runtime external dependencies

**Phase 4 — GitOps**
- Merge to main triggers `terraform apply`
- Infrastructure changes go through PR review with `terraform plan` output as a comment
- No manual AWS console or CLI use in production

You don't have to do all four phases at once. Phase 1 alone meaningfully reduces your attack surface. Phase 2 alone makes your infrastructure auditable and team-friendly. Each phase delivers independent value.

---

## What Stayed the Same

The right mental model for this problem hasn't changed:

- Instances are cattle — disposable, replaceable, identical
- Config lives in Git, not on machines
- Orchestration and configuration are separate concerns
- Tag everything; lifecycle is a first-class concern, not an afterthought

The 2012 repo understood all of this. The 2025 version just has better tools to express those same ideas — with more safety, more security, and more operational leverage.

---

## The Code

The full working modernization is in the `/modern` directory of the original repo:

```
modern/
├── terraform/
│   ├── main.tf          # Launch Template + ASG + IAM + Security Group
│   ├── variables.tf     # Typed, documented parameters
│   └── outputs.tf       # Instance IDs, ASG name, SSM connect command
├── cloud-config/
│   └── cloud-config.yaml  # Replaces cloud_init_chef.txt and cloud_init_ansible.txt
├── packer/
│   └── packer.pkr.hcl   # Pre-baked AMI definition
└── .github/
    └── workflows/
        └── deploy.yml    # Plan on PR, apply on merge
```

Clone it, point it at your AWS account, and run:

```bash
cd modern/terraform
terraform init
terraform plan -var="instance_count=3"
terraform apply
```

---

*The original repo: [github.com/chefgs/cloud_init_sample](https://github.com/chefgs/cloud_init_sample)*
*The `/modern` directory has all the code from this series*

---

*That's the series. Three parts: what we built, what changed, how to build it now. If you're modernizing legacy infrastructure or teaching someone how to think about cloud provisioning — the patterns here apply broadly, not just to this repo.*

---
`#DevOps` `#Terraform` `#AWS` `#CloudInit` `#Packer` `#IaC` `#InfrastructureAsCode` `#GitOps` `#CloudEngineering` `#AWSCloud`
