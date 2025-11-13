# outputs.tf - Output values for Terraform configuration
# Ostad Capstone Project - Infrastructure Outputs

# VPC Information
output "vpc_id" {
  description = "ID of the default VPC"
  value       = data.aws_vpc.default.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = data.aws_vpc.default.cidr_block
}

output "subnet_ids" {
  description = "List of subnet IDs in the default VPC"
  value       = data.aws_subnets.default.ids
}

# EC2 Instances
output "master_instance_id" {
  description = "Instance ID of the Kubernetes master node"
  value       = aws_instance.k8s_master.id
}

output "master_public_ip" {
  description = "Public IP address of the Kubernetes master node"
  value       = aws_instance.k8s_master.public_ip
}

output "master_private_ip" {
  description = "Private IP address of the Kubernetes master node"
  value       = aws_instance.k8s_master.private_ip
}

output "master_elastic_ip" {
  description = "Elastic IP address of the Kubernetes master node"
  value       = aws_eip.k8s_master_eip.public_ip
}

output "worker_instance_ids" {
  description = "Instance IDs of the Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].id
}

output "worker_public_ips" {
  description = "Public IP addresses of the Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IP addresses of the Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].private_ip
}

# Security Groups
output "master_security_group_id" {
  description = "Security group ID for the Kubernetes master node"
  value       = aws_security_group.k8s_master.id
}

output "worker_security_group_id" {
  description = "Security group ID for the Kubernetes worker nodes"
  value       = aws_security_group.k8s_worker.id
}

output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer"
  value       = aws_security_group.alb.id
}

# Load Balancer
output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.k8s_alb.dns_name
}

output "load_balancer_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.k8s_alb.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.k8s_tg.arn
}

# S3 Buckets
output "s3_bucket_names" {
  description = "Names of the created S3 buckets"
  value       = var.create_s3_buckets ? { for k, v in aws_s3_bucket.storage_buckets : k => v.bucket } : {}
}

output "s3_bucket_arns" {
  description = "ARNs of the created S3 buckets"
  value       = var.create_s3_buckets ? { for k, v in aws_s3_bucket.storage_buckets : k => v.arn } : {}
}

output "s3_access_logs_bucket" {
  description = "Name of the S3 access logs bucket"
  value       = var.create_s3_buckets ? aws_s3_bucket.access_logs[0].bucket : null
}

# EFS File System
output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.shared_storage.id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.shared_storage.dns_name
}

# Key Pair
output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.ec2_key_pair.key_name
}

output "private_key_path" {
  description = "Path to the private key file"
  value       = "${path.module}/keys/${aws_key_pair.ec2_key_pair.key_name}.pem"
}

# IAM
output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

# Kubernetes Information
output "kubernetes_api_endpoint" {
  description = "Kubernetes API endpoint URL"
  value       = "https://${aws_eip.k8s_master_eip.public_ip}:${var.kubernetes_api_port}"
}

output "kubernetes_dashboard_url" {
  description = "Kubernetes Dashboard URL (if installed)"
  value       = "https://${aws_eip.k8s_master_eip.public_ip}:8443"
}

# Connection Information
output "ssh_connection_commands" {
  description = "SSH connection commands for all instances"
  value = {
    master = "ssh -i ${path.module}/keys/${aws_key_pair.ec2_key_pair.key_name}.pem ubuntu@${aws_eip.k8s_master_eip.public_ip}"
    workers = [
      for i, instance in aws_instance.k8s_workers :
      "ssh -i ${path.module}/keys/${aws_key_pair.ec2_key_pair.key_name}.pem ubuntu@${instance.public_ip}"
    ]
  }
}

# Kubeconfig Setup Command
output "kubeconfig_setup_command" {
  description = "Command to setup kubeconfig from master node"
  value       = "scp -i ${path.module}/keys/${aws_key_pair.ec2_key_pair.key_name}.pem ubuntu@${aws_eip.k8s_master_eip.public_ip}:~/.kube/config ~/.kube/config"
}

# Join Command for Worker Nodes
output "worker_join_command_file" {
  description = "Location of the worker join command file on master"
  value       = "/tmp/kubeadm-join-command.sh"
}

# Application URLs
output "application_urls" {
  description = "URLs to access the deployed applications"
  value = {
    load_balancer = "http://${aws_lb.k8s_alb.dns_name}"
    master_direct = "http://${aws_eip.k8s_master_eip.public_ip}"
  }
}

# CloudWatch Log Groups
output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value = {
    ec2_logs = aws_cloudwatch_log_group.k8s_logs.name
    s3_access_logs = var.create_s3_buckets ? aws_cloudwatch_log_group.s3_access_logs[0].name : null
    vpc_flow_logs = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.vpc_flow_log[0].name : null
  }
}

# Resource Summary
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    total_instances = var.instance_count
    master_instances = 1
    worker_instances = var.instance_count - 1
    s3_buckets = var.create_s3_buckets ? length(var.s3_bucket_names) : 0
    security_groups = 4 # master, worker, alb, efs
    load_balancers = 1
    elastic_ips = 1
    efs_file_systems = 1
  }
}

# Cost Optimization Tips
output "cost_optimization_tips" {
  description = "Tips for optimizing AWS costs"
  value = [
    "Consider using Spot Instances for worker nodes in non-production environments",
    "Enable S3 lifecycle policies to move old data to cheaper storage classes",
    "Use CloudWatch to monitor resource utilization and right-size instances",
    "Set up billing alerts to monitor costs",
    "Delete unused EBS snapshots and volumes",
    "Use Reserved Instances for predictable workloads"
  ]
}

# Next Steps
output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = [
    "1. Connect to master node: ${aws_eip.k8s_master_eip.public_ip}",
    "2. Wait for kubeadm initialization to complete (check /var/log/cloud-init-output.log)",
    "3. Copy kubeconfig: scp ubuntu@${aws_eip.k8s_master_eip.public_ip}:~/.kube/config ~/.kube/config",
    "4. Join worker nodes using the command in /tmp/kubeadm-join-command.sh",
    "5. Install CNI plugin (Flannel/Calico) if not automatically installed",
    "6. Deploy your applications using kubectl or ArgoCD",
    "7. Configure ingress controller for external access",
    "8. Set up monitoring with Prometheus and Grafana"
  ]
}
