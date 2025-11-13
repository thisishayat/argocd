# variables.tf - Input variables for Terraform configuration
# Ostad Capstone Project - Variable Definitions

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "AWS region must be in the format: us-east-1, eu-west-1, etc."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ostad-capstone"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, stage, production)"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["dev", "stage", "production"], var.environment)
    error_message = "Environment must be one of: dev, stage, production."
  }
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "Md Arif Ahammedrez"
}

# EC2 Configuration Variables
variable "instance_type" {
  description = "EC2 instance type for Kubernetes nodes"
  type        = string
  default     = "t3.medium"
  
  validation {
    condition = contains([
      "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge"
    ], var.instance_type)
    error_message = "Instance type must be suitable for Kubernetes workloads."
  }
}

variable "master_instance_type" {
  description = "EC2 instance type for Kubernetes master node"
  type        = string
  default     = "t3.large"
}

variable "worker_instance_type" {
  description = "EC2 instance type for Kubernetes worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 3
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB."
  }
}

variable "additional_volume_size" {
  description = "Size of additional EBS volume for container storage in GB"
  type        = number
  default     = 30
  
  validation {
    condition     = var.additional_volume_size >= 10 && var.additional_volume_size <= 200
    error_message = "Additional volume size must be between 10 and 200 GB."
  }
}

# Networking Configuration Variables
variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH to instances"
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Restrict this in production
}

variable "allowed_http_cidrs" {
  description = "List of CIDR blocks allowed HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidrs" {
  description = "List of CIDR blocks allowed HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "kubernetes_api_port" {
  description = "Kubernetes API server port"
  type        = number
  default     = 6443
}

# Storage Configuration Variables
variable "create_s3_buckets" {
  description = "Whether to create S3 buckets"
  type        = bool
  default     = true
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names to create"
  type        = list(string)
  default     = [
    "application-storage",
    "backup-storage",
    "logs-storage"
  ]
}

variable "s3_versioning_enabled" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = true
}

variable "s3_lifecycle_enabled" {
  description = "Enable lifecycle management for S3 buckets"
  type        = bool
  default     = true
}

# Kubernetes Configuration Variables
variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "1.28"
  
  validation {
    condition     = can(regex("^1\\.(2[6-9]|[3-9][0-9])$", var.kubernetes_version))
    error_message = "Kubernetes version must be 1.26 or higher."
  }
}

variable "pod_network_cidr" {
  description = "CIDR block for pod network"
  type        = string
  default     = "10.244.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.pod_network_cidr, 0))
    error_message = "Pod network CIDR must be a valid CIDR block."
  }
}

variable "service_network_cidr" {
  description = "CIDR block for service network"
  type        = string
  default     = "10.96.0.0/12"
  
  validation {
    condition     = can(cidrhost(var.service_network_cidr, 0))
    error_message = "Service network CIDR must be a valid CIDR block."
  }
}

# Monitoring and Logging Variables
variable "enable_cloudwatch_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

# Backup Configuration
variable "enable_automated_backups" {
  description = "Enable automated EBS snapshots"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}
