# terraform.tfvars - Variable values for Terraform configuration
# Ostad Capstone Project - Production Environment

# Basic Configuration
aws_region   = "us-east-1"
project_name = "ostad-capstone"
environment  = "production"
owner        = "Md Arif Ahammedrez"

# EC2 Instance Configuration
instance_count        = 3
master_instance_type  = "t3.large"   # 2 vCPUs, 8 GB RAM
worker_instance_type  = "t3.medium"  # 2 vCPUs, 4 GB RAM
root_volume_size      = 20           # GB
additional_volume_size = 30          # GB

# Networking Configuration
allowed_ssh_cidrs   = ["0.0.0.0/0"]  # WARNING: Restrict this in production
allowed_http_cidrs  = ["0.0.0.0/0"]
allowed_https_cidrs = ["0.0.0.0/0"]
kubernetes_api_port = 6443

# Storage Configuration
create_s3_buckets      = true
s3_bucket_names        = ["application-storage", "backup-storage", "logs-storage"]
s3_versioning_enabled  = true
s3_lifecycle_enabled   = true

# Kubernetes Configuration
kubernetes_version     = "1.28"
pod_network_cidr      = "10.244.0.0/16"  # Flannel default
service_network_cidr  = "10.96.0.0/12"   # Kubernetes default

# Monitoring and Logging
enable_cloudwatch_monitoring = true
enable_vpc_flow_logs         = false  # Can be expensive, enable if needed

# Backup Configuration
enable_automated_backups = true
backup_retention_days   = 7

# Note: For production use, consider:
# - Restricting SSH access to specific IP ranges
# - Using larger instance types for better performance
# - Enabling VPC Flow Logs for security monitoring
# - Setting up proper backup and disaster recovery procedures
