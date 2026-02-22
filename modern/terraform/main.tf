###############################################################
# Modern equivalent of create_instance.sh + cloud_init_*.txt
# Uses Terraform for declarative, state-managed infrastructure
###############################################################

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Shared state — replace with your own S3 bucket + DynamoDB table
  # backend "s3" {
  #   bucket         = "my-terraform-state"
  #   key            = "cloud-init-demo/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}

###############################################################
# Data: Dynamically resolve latest AMI — no hardcoded IDs
###############################################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################
# IAM: Instance role with SSM access (replaces key pairs)
###############################################################

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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.demo_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_params" {
  role       = aws_iam_role.demo_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_instance_profile" "demo" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.demo_instance.name
}

###############################################################
# Security Group: No port 22 — SSM Session Manager only
###############################################################

resource "aws_security_group" "demo" {
  name        = "${var.project_name}-sg"
  description = "Demo instances - outbound only, SSM access via VPC endpoint"
  vpc_id      = data.aws_vpc.default.id

  # No inbound rules — instances accessed via SSM only

  egress {
    description = "Allow all outbound (package installs, SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

data "aws_vpc" "default" {
  default = true
}

###############################################################
# SSM Parameters: Config values — not hardcoded in scripts
###############################################################

resource "aws_ssm_parameter" "agent_hostname" {
  name  = "/${var.project_name}/agent_hostname"
  type  = "String"
  value = var.agent_hostname
  tags  = local.common_tags
}

###############################################################
# Launch Template: Replaces aws ec2 run-instances flags
###############################################################

resource "aws_launch_template" "demo" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.demo.name
  }

  vpc_security_group_ids = [aws_security_group.demo.id]

  # cloud-config YAML — not a bash script
  user_data = base64encode(templatefile("${path.module}/../cloud-config/cloud-config.yaml", {
    project_name   = var.project_name
    agent_hostname = var.agent_hostname
    users          = var.demo_users
  }))

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 only — security best practice
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-instance" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################
# Auto Scaling Group: True cattle at scale
# Replaces the for-loop in create_instance.sh
###############################################################

resource "aws_autoscaling_group" "demo" {
  name                = "${var.project_name}-asg"
  desired_capacity    = var.instance_count
  min_size            = 0
  max_size            = 20
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.demo.id
    version = "$Latest"
  }

  # Health check — ASG replaces unhealthy instances automatically
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Enables rolling updates (replaces terminate + recreate pattern)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Purpose"
    value               = "Demo"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

###############################################################
# Locals
###############################################################

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
