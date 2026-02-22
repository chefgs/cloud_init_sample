###############################################################
# Outputs — useful info after apply
###############################################################

output "asg_name" {
  description = "Auto Scaling Group name (use this to find instances)"
  value       = aws_autoscaling_group.demo.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.demo.id
}

output "ami_id" {
  description = "AMI resolved dynamically (no hardcoded IDs)"
  value       = data.aws_ami.amazon_linux_2023.id
}

output "ami_name" {
  description = "AMI name for reference"
  value       = data.aws_ami.amazon_linux_2023.name
}

output "ssm_connect_command" {
  description = "How to connect to instances — no SSH, no port 22"
  value       = "aws ssm start-session --target <instance-id> --region ${var.aws_region}"
}

output "list_instances_command" {
  description = "List all Demo instances"
  value       = "aws ec2 describe-instances --filters 'Name=tag:Purpose,Values=Demo' 'Name=instance-state-name,Values=running' --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PrivateIpAddress}' --output table --region ${var.aws_region}"
}

output "scale_down_command" {
  description = "Scale to zero instances (replaces terminate_instances.sh)"
  value       = "terraform apply -var instance_count=0"
}
