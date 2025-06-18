# Terraform outputs for CI/CD pipeline infrastructure
# These values are used by GitHub Actions and other automation

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.app_server.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.app_server.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.app_server.public_dns
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.app_server.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for artifacts"
  value       = aws_s3_bucket.app_artifacts.bucket
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2"
  value       = aws_iam_role.ec2_role.arn
}

output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.app_key.key_name
}

# Output for GitHub Actions (JSON format for easy parsing)
output "deployment_info" {
  description = "Deployment information in JSON format for GitHub Actions"
  value = jsonencode({
    instance_id       = aws_instance.app_server.id
    public_ip         = aws_eip.app_server.public_ip
    private_ip        = aws_instance.app_server.private_ip
    public_dns        = aws_instance.app_server.public_dns
    s3_bucket         = aws_s3_bucket.app_artifacts.bucket
    security_group_id = aws_security_group.app_server.id
    key_pair_name     = aws_key_pair.app_key.key_name
    app_port          = var.app_port
    project_name      = var.project_name
    environment       = var.environment
  })
}
