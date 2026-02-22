###############################################################
# Variables — replaces positional bash args in create_instance.sh
###############################################################

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as a prefix for all resources"
  type        = string
  default     = "cloud-init-demo"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "instance_count" {
  description = "Number of EC2 instances (desired_capacity of ASG)"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 0 && var.instance_count <= 20
    error_message = "instance_count must be between 0 and 20."
  }
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro replaces original t2.micro (same cost, better performance)"
  type        = string
  default     = "t3.micro"
}

variable "agent_hostname" {
  description = "Hostname to set for the monitoring agent configuration"
  type        = string
  default     = "cloud-init-server"
}

variable "demo_users" {
  description = "List of users to create and add to my-staff group"
  type        = list(string)
  default     = ["alice", "bob"]
}
