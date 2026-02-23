# Modernizing Cloud-Init Sample: A 2012 Repo Meets Modern IaC

> **Context**: This repo was created in 2012 as an early demonstration of the "Cattle" instance
> provisioning pattern using AWS EC2, cloud-init, and configuration management (Chef/Ansible).
> The concepts were ahead of their time. This document shows how those same ideas map to the
> modern Infrastructure as Code (IaC) landscape.

---

## What the Original Repo Got Right

Even by 2012 standards, this repo demonstrated patterns that are now mainstream:

| Original Concept | Modern Equivalent |
|---|---|
| "Cattle" instances (disposable, reproducible) | Immutable infrastructure, Auto Scaling Groups |
| cloud-init user-data for bootstrapping | cloud-config YAML, Launch Templates, Packer AMIs |
| Chef/Ansible for desired state | Still valid — now with Ansible 9+, Chef Infra 18+ |
| AWS CLI scripting | Terraform, AWS CDK, CloudFormation, Pulumi |
| Bulk instance creation by re-running a script | Auto Scaling Groups, Spot fleets |
| DEMO tag for grouping/lifecycle | AWS Resource Groups, tag-based governance |
| Local-mode Chef (no Chef Server) | Still a valid pattern (Chef Zero) |

---

## The Gap: What Needs Modernizing

### 1. Infrastructure Orchestration: Shell Scripts → Declarative IaC

**Problem with original:** `create_instance.sh` is imperative — it tells AWS *how* to do things,
has no state tracking, and requires manual cleanup via `terminate_instances.sh`.

**Modern approach: Terraform / OpenTofu**

```hcl
# main.tf — Declarative, state-managed, plan-before-apply
resource "aws_launch_template" "demo" {
  name_prefix   = "cloud-init-demo-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"  # t3, not t2 — better price/perf

  iam_instance_profile {
    name = aws_iam_instance_profile.demo.name  # Roles, not key pairs
  }

  user_data = base64encode(file("cloud-config.yaml"))

  tag_specifications {
    resource_type = "instance"
    tags = { Purpose = "Demo", ManagedBy = "Terraform" }
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
}
```

**Key improvements:**
- `terraform plan` shows *exactly* what will change before it happens
- `terraform destroy` replaces `terminate_instances.sh`
- State file tracks all resources — no more orphaned instances
- Parameterized via `variables.tf` — no positional bash arguments

---

### 2. AMI Selection: Hardcoded ID → Dynamic Data Source

**Problem with original:** `ami-28e07e50` is hardcoded, region-specific (us-east-1 only),
and now stale (RHEL 7 is EOL as of June 2024).

**Modern approach:**

```hcl
# Dynamically resolve the latest Amazon Linux 2023 AMI for current region
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# For Graviton/ARM (up to 40% cheaper):
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}
```

---

### 3. cloud-init Script: Bash → cloud-config YAML

**Problem with original:** `cloud_init_chef.txt` and `cloud_init_ansible.txt` are plain bash
scripts passed as user-data. This works, but misses the full power of cloud-init's YAML format.

**Modern approach: `#cloud-config` YAML format**

```yaml
#cloud-config
# Declarative, human-readable, no bash required for common operations

hostname: cloud-init-server
fqdn: cloud-init-server.internal

# Users and groups — declarative, no useradd scripting
groups:
  - my-staff

users:
  - default
  - name: alice
    groups: [my-staff, sudo]
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - "{{ lookup_from_secrets_manager }}"
  - name: bob
    groups: [my-staff]
    shell: /bin/bash
    lock_passwd: true

# Package installation — handled by cloud-init, not yum in a loop
packages:
  - git
  - ansible

package_update: true
package_upgrade: true

# Write config files declaratively
write_files:
  - path: /etc/mon-agent/agent.conf
    permissions: "0644"
    owner: root:root
    content: |
      hostname=cloud-init-server
      # Additional agent configuration

# Run commands only when declarative modules are insufficient
runcmd:
  - ansible-playbook /opt/playbooks/playbook.yml

# Signal completion (works with CloudFormation cfn-signal or Terraform null_resource)
final_message: "Cloud-init completed in $UPTIME seconds"
```

**Why YAML cloud-config over bash:**
- Idempotent by design — safe to re-run
- Modules for packages, users, files, mounts are built-in and tested across distros
- Easier to validate with `cloud-init schema --config-file cloud-config.yaml`
- Works identically on Ubuntu, RHEL, Amazon Linux, Debian

---

### 4. Security: SSH Key Pairs → IAM Roles + AWS SSM

**Problem with original:** Requires SSH key pairs and open port 22 in security groups.
Key management is a security and operational burden.

**Modern approach: No SSH, no port 22**

```hcl
# IAM role with SSM access — instances are managed without SSH
resource "aws_iam_role" "demo_instance" {
  name = "cloud-init-demo-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.demo_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

**Access instances via SSM Session Manager:**
```bash
# Instead of: ssh -i mykey.pem ec2-user@1.2.3.4
aws ssm start-session --target i-0abc1234567890def
```

**Benefits:**
- No open inbound ports (port 22 closed entirely)
- No key pair management or rotation
- Full audit trail via CloudTrail
- Works even in private subnets with no public IPs

---

### 5. Package/Software Installation: Runtime Downloads → Pre-baked AMIs

**Problem with original:** Every new instance downloads Chef, git, clones repos — slow boot,
dependent on external network, failure-prone.

**Modern approach: Packer to pre-bake AMIs**

```hcl
# packer.pkr.hcl
packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "demo" {
  ami_name      = "cloud-init-demo-${formatdate("YYYY-MM-DD", timestamp())}"
  instance_type = "t3.micro"
  region        = "us-east-1"

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.demo"]

  # Install everything at AMI build time, not instance launch time
  provisioner "ansible" {
    playbook_file = "playbook.yml"
  }
}
```

**Benefits:**
- Instance boot time: seconds (not minutes waiting for Chef/Ansible)
- No runtime dependency on GitHub, Chef package servers
- AMI is the versioned, tested artifact — just like a container image
- Rollback = launch previous AMI version

---

### 6. Configuration Management: Chef 14 / Ansible → Modern Versions + Ansible Collections

**Chef 14 (2018) → Chef Infra 18+ (2024)**

```ruby
# Modern Chef: use unified_mode, no more Chef::Log.info everywhere
unified_mode true

resource_name :monitoring_agent
provides :monitoring_agent

action :install do
  package 'my-monitoring-agent' do
    version new_resource.version
    action :install
  end

  template '/etc/mon-agent/agent.conf' do
    source 'agent.conf.erb'
    variables hostname: new_resource.hostname
    notifies :restart, 'service[mon-agent]'
  end
end
```

**Ansible (2013 style) → Ansible 9+ with Collections**

```yaml
# Modern Ansible: use FQCN (Fully Qualified Collection Names)
- name: Configure monitoring agent
  hosts: all
  become: true
  collections:
    - ansible.builtin
    - community.general

  vars:
    agent_hostname: "{{ ansible_hostname }}"

  tasks:
    - name: Install monitoring agent
      ansible.builtin.package:
        name: my-monitoring-agent
        state: present

    - name: Configure agent
      ansible.builtin.template:
        src: agent.conf.j2
        dest: /etc/mon-agent/agent.conf
        mode: "0644"
      notify: Restart mon-agent

    - name: Manage staff group
      ansible.builtin.group:
        name: my-staff
        state: present

    - name: Manage users
      ansible.builtin.user:
        name: "{{ item }}"
        groups: my-staff
        append: true
        state: present
      loop: [alice, bob]

  handlers:
    - name: Restart mon-agent
      ansible.builtin.service:
        name: mon-agent
        state: restarted
```

---

### 7. Secrets and Configuration: Hardcoded Values → Parameter Store / Secrets Manager

**Problem with original:** Config values are hardcoded in scripts.

**Modern approach:**

```bash
# Fetch secrets at runtime via SSM Parameter Store (free tier)
HOSTNAME=$(aws ssm get-parameter --name "/demo/hostname" --query Parameter.Value --output text)

# Or Secrets Manager for sensitive values
DB_PASS=$(aws secretsmanager get-secret-value --secret-id demo/db --query SecretString --output text)
```

```hcl
# Terraform: pass SSM parameter ARN via user-data, not the value itself
resource "aws_ssm_parameter" "agent_hostname" {
  name  = "/demo/agent_hostname"
  type  = "String"
  value = "cloud-init-server"
}
```

---

### 8. CI/CD: Manual Script Execution → GitHub Actions Pipeline

**Problem with original:** All operations are manual — clone repo, run script, track state manually.

**Modern approach: `.github/workflows/deploy.yml`**

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  TF_VERSION: "1.9.0"

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # OIDC auth — no stored AWS credentials
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/github-actions-role
          aws-region: ${{ env.AWS_REGION }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Upload Plan
        uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: tfplan

  apply:
    name: Terraform Apply
    needs: plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment: production  # Requires manual approval in GitHub

    steps:
      - uses: actions/checkout@v4

      - name: Download Plan
        uses: actions/download-artifact@v4
        with:
          name: tfplan

      - name: Terraform Apply
        run: terraform apply tfplan
```

**Key improvements:**
- No AWS credentials stored in CI — OIDC federated identity
- Plan on every PR, apply only on merge to main
- Manual approval gate via GitHub Environments
- Full audit trail in GitHub Actions history

---

## Architecture Evolution Summary

```
2012 Original                    2025 Modern
─────────────────────────────    ────────────────────────────────────────
Manual CLI script                Terraform / OpenTofu (declarative state)
  └─ aws ec2 run-instances         └─ aws_autoscaling_group + launch_template

Hardcoded AMI (RHEL 7)           Dynamic AMI data source (Amazon Linux 2023)
                                  └─ or Packer-built custom AMI

Bash user-data script             cloud-config YAML
  └─ downloads Chef/Ansible         └─ built-in modules for users/packages/files
     at runtime                     └─ runcmd only for truly custom logic

SSH + key pairs (port 22 open)   IAM Instance Profile + SSM Session Manager
                                  └─ zero open ports

Chef 14 local-mode               Chef 18+ / Ansible 9+ with Collections
  └─ cloned from GitHub at boot    └─ baked into AMI via Packer

Manual terminate_instances.sh    terraform destroy / ASG scale-to-zero

No CI/CD                         GitHub Actions with OIDC + manual approval

No secrets management            SSM Parameter Store / Secrets Manager
```

---

## Migration Path

If modernizing this repo incrementally:

**Phase 1 — Low effort, high security gain**
- Replace hardcoded AMI with `aws_ami` data source or `aws ssm get-parameter` lookup
- Add IAM instance profile with SSM; remove open port 22 and key pairs
- Update RHEL 7 → Amazon Linux 2023 (free, AWS-maintained, not EOL)
- Pin Chef/Ansible versions and upgrade to current releases

**Phase 2 — Proper IaC tooling**
- Wrap `create_instance.sh` logic in Terraform (or AWS CDK if your team prefers TypeScript/Python)
- Use `aws_launch_template` + `aws_autoscaling_group` for true cattle pattern at scale
- Store state in S3 + DynamoDB for team collaboration

**Phase 3 — Immutable infrastructure**
- Build Packer AMI in CI/CD pipeline; instances only pull from pre-baked AMI
- cloud-config YAML handles only final runtime config (hostname, per-environment vars)
- All config management baked in, not downloaded at boot

**Phase 4 — Full GitOps**
- Merge to `main` triggers `terraform apply`
- Infrastructure changes reviewed as code (PRs with `terraform plan` comments)
- No manual AWS console or CLI usage in production

---

## Tools Reference

| Category | Tool | Why |
|---|---|---|
| IaC orchestration | [Terraform](https://www.terraform.io) / [OpenTofu](https://opentofu.org) | Declarative, state, plan/apply |
| IaC (code-first) | [AWS CDK](https://aws.amazon.com/cdk/) / [Pulumi](https://www.pulumi.com) | TypeScript/Python/Go for infra |
| AMI building | [Packer](https://www.packer.io) | Immutable, versioned machine images |
| Config mgmt | [Ansible 9+](https://docs.ansible.com) / [Chef 18+](https://www.chef.io) | Still valid; use collections/unified_mode |
| Secrets | [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/) / [SSM Param Store](https://aws.amazon.com/systems-manager/features/) | No secrets in scripts |
| Access | [AWS SSM Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) | No SSH, no port 22 |
| CI/CD | [GitHub Actions](https://github.com/features/actions) / [GitLab CI](https://docs.gitlab.com/ee/ci/) | Pipeline-driven infra changes |
| cloud-init ref | [cloud-init docs](https://cloudinit.readthedocs.io) | YAML cloud-config module reference |
