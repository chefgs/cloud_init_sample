# Modern IaC Examples

This directory contains modern Infrastructure as Code equivalents of the original 2012 shell
scripts. Each subdirectory maps directly to a concept from the original repo.

```
modern/
├── terraform/              # Replaces create_instance.sh + terminate_instances.sh
│   ├── main.tf             # ASG, Launch Template, IAM, Security Group
│   ├── variables.tf        # Replaces positional bash args
│   └── outputs.tf          # Connection info, SSM commands
│
├── cloud-config/           # Replaces cloud_init_chef.txt + cloud_init_ansible.txt
│   ├── cloud-config.yaml          # Terraform templatefile version (with variables)
│   └── cloud-config-standalone.yaml  # Standalone version for direct use
│
├── packer/                 # Optional: pre-bake AMI (immutable infra)
│   └── packer.pkr.hcl      # Builds AMI with everything pre-installed
│
└── .github/workflows/      # Replaces manual script execution
    ├── deploy.yml           # Plan on PR, Apply on merge, Destroy on demand
    └── packer-build.yml     # Build new AMI when packer/ansible config changes
```

## Quick Start

### Using Terraform (recommended)

```bash
cd modern/terraform

# Initialize
terraform init

# Preview changes
terraform plan -var="instance_count=1"

# Deploy
terraform apply -var="instance_count=1"

# Connect (no SSH needed — uses SSM)
aws ssm start-session --target $(terraform output -raw instance_id)

# Scale to zero (replaces terminate_instances.sh)
terraform apply -var="instance_count=0"

# Full teardown
terraform destroy
```

### Using cloud-config YAML directly (without Terraform)

```bash
# Validate the cloud-config syntax
cloud-init schema --config-file modern/cloud-config/cloud-config-standalone.yaml

# Use with AWS CLI (replaces cloud_init_ansible.txt)
aws ec2 run-instances \
  --image-id $(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query Parameter.Value --output text) \
  --instance-type t3.micro \
  --iam-instance-profile Name=cloud-init-demo-instance-profile \
  --user-data file://modern/cloud-config/cloud-config-standalone.yaml \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Purpose,Value=Demo}]'
```

### Building a pre-baked AMI with Packer

```bash
cd modern/packer
packer init .
packer validate .
packer build .
```

## Key Differences from Original

| Concern | Original (2012) | Modern |
|---|---|---|
| Orchestration | `create_instance.sh` bash | Terraform `aws_autoscaling_group` |
| AMI | Hardcoded `ami-28e07e50` (RHEL 7, stale) | Dynamic `aws_ami` data source (AL2023) |
| user-data | Bash script | `#cloud-config` YAML |
| Instance access | SSH + key pair + port 22 | SSM Session Manager (zero open ports) |
| Software install | At boot, downloads from internet | Pre-baked in AMI via Packer |
| Cleanup | `terminate_instances.sh` | `terraform destroy` or scale to 0 |
| Config changes | Terminate + recreate manually | ASG instance refresh (rolling update) |
| CI/CD | None — all manual | GitHub Actions (plan on PR, apply on merge) |
| Secrets | Hardcoded in scripts | SSM Parameter Store |
| Instance type | `t2.micro` | `t3.micro` (same price, better perf) |
