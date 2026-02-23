###############################################################
# Packer: Pre-bake AMI with all software already installed
#
# Philosophy: Bake everything at AMI build time.
# Instances launch in seconds because nothing is installed at boot.
# This is the true "immutable infrastructure" pattern.
#
# Usage:
#   packer init .
#   packer validate .
#   packer build .
###############################################################

packer {
  required_version = ">= 1.10.0"

  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

###############################################################
# Variables
###############################################################

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "project_name" {
  type    = string
  default = "cloud-init-demo"
}

###############################################################
# Source: Which base AMI to start from
###############################################################

source "amazon-ebs" "al2023" {
  ami_name        = "${var.project_name}-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  ami_description = "Pre-baked AMI for ${var.project_name}. Built by Packer."
  instance_type   = var.instance_type
  region          = var.aws_region

  # Dynamic AMI resolution — same pattern as Terraform data source
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

  # IMDSv2 on the builder instance
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Project   = var.project_name
    BuildDate = formatdate("YYYY-MM-DD", timestamp())
    BaseAMI   = "{{ .SourceAMI }}"
    ManagedBy = "Packer"
  }
}

###############################################################
# Build: Run provisioners on the temporary instance
###############################################################

build {
  sources = ["source.amazon-ebs.al2023"]

  # Step 1: System updates
  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y git rpm-build ansible-core",
    ]
  }

  # Step 2: Build and install the monitoring agent RPM at AMI time
  # (Not at instance launch time — this is the key difference)
  provisioner "shell" {
    inline = [
      "mkdir -p /tmp/rpm_build",
      "git clone https://github.com/chefgs/create_dummy_rpm.git /tmp/rpm_build/",
      "chmod +x /tmp/rpm_build/create_rpm.sh",
      "cd /tmp/rpm_build && ./create_rpm.sh spec_file/my-monitoring-agent.spec",
      # Install the built RPM into the AMI
      "sudo rpm -i /tmp/rpm_build/RPMS/noarch/my-monitoring-agent-*.rpm || true",
      "rm -rf /tmp/rpm_build",
    ]
  }

  # Step 3: Run Ansible to configure the base system
  provisioner "ansible" {
    playbook_file   = "../ansible/playbook.yml"
    extra_arguments = ["-v"]
  }

  # Step 4: Create agent config directory (hostname set at launch via cloud-config)
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /etc/mon-agent",
      "sudo chmod 755 /etc/mon-agent",
    ]
  }

  # Step 5: Clean up build artifacts from AMI
  provisioner "shell" {
    inline = [
      "sudo dnf clean all",
      "sudo rm -rf /tmp/*",
      "sudo rm -f /root/.bash_history /home/ec2-user/.bash_history",
    ]
  }

  # Emit AMI ID for downstream use (e.g., update Terraform variable)
  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}
