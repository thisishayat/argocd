# storage.tf - S3 buckets and storage configuration
# Ostad Capstone Project - Storage Infrastructure

# Random suffix for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Buckets for different purposes
resource "aws_s3_bucket" "storage_buckets" {
  for_each = var.create_s3_buckets ? toset(var.s3_bucket_names) : toset([])
  
  bucket = "${var.project_name}-${var.environment}-${each.value}-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.value}"
    Purpose     = each.value
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "storage_versioning" {
  for_each = var.create_s3_buckets && var.s3_versioning_enabled ? aws_s3_bucket.storage_buckets : {}
  
  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "storage_encryption" {
  for_each = var.create_s3_buckets ? aws_s3_bucket.storage_buckets : {}
  
  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "storage_pab" {
  for_each = var.create_s3_buckets ? aws_s3_bucket.storage_buckets : {}
  
  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "storage_lifecycle" {
  for_each = var.create_s3_buckets && var.s3_lifecycle_enabled ? aws_s3_bucket.storage_buckets : {}
  
  bucket = each.value.id

  rule {
    id     = "transition_to_ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# S3 Bucket Logging (for application-storage bucket)
resource "aws_s3_bucket" "access_logs" {
  count  = var.create_s3_buckets ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-access-logs-${random_string.bucket_suffix.result}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-access-logs"
    Purpose     = "access-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_logging" "storage_logging" {
  for_each = var.create_s3_buckets ? {
    for k, v in aws_s3_bucket.storage_buckets : k => v if k == "application-storage"
  } : {}
  
  bucket = each.value.id

  target_bucket = aws_s3_bucket.access_logs[0].id
  target_prefix = "log/${each.key}/"
}

# S3 Bucket Policy for application storage (example)
resource "aws_s3_bucket_policy" "application_storage_policy" {
  count  = var.create_s3_buckets ? 1 : 0
  bucket = aws_s3_bucket.storage_buckets["application-storage"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "ApplicationStoragePolicy"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.storage_buckets["application-storage"].arn,
          "${aws_s3_bucket.storage_buckets["application-storage"].arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowEC2Access"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.storage_buckets["application-storage"].arn,
          "${aws_s3_bucket.storage_buckets["application-storage"].arn}/*",
        ]
      }
    ]
  })
}

# EBS Volumes for additional storage (if needed)
resource "aws_ebs_volume" "additional_storage" {
  count             = var.instance_count
  availability_zone = count.index == 0 ? aws_instance.k8s_master.availability_zone : aws_instance.k8s_workers[count.index - 1].availability_zone
  size              = 50
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "${var.project_name}-${var.environment}-additional-storage-${count.index == 0 ? "master" : "worker-${count.index}"}"
    Type = "additional-storage"
  }
}

# Attach additional EBS volumes
resource "aws_volume_attachment" "additional_storage_attachment" {
  count       = var.instance_count
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.additional_storage[count.index].id
  instance_id = count.index == 0 ? aws_instance.k8s_master.id : aws_instance.k8s_workers[count.index - 1].id
}

# S3 VPC Endpoint for private access
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [data.aws_route_table.default.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-s3-endpoint"
  }
}

# CloudWatch Log Group for S3 access logs
resource "aws_cloudwatch_log_group" "s3_access_logs" {
  count             = var.create_s3_buckets ? 1 : 0
  name              = "/aws/s3/${var.project_name}-${var.environment}-access-logs"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-s3-access-logs"
  }
}

# S3 Bucket Notification (example for backup bucket)
resource "aws_s3_bucket_notification" "backup_notification" {
  count  = var.create_s3_buckets ? 1 : 0
  bucket = aws_s3_bucket.storage_buckets["backup-storage"].id

  cloudwatch_configuration {
    events = ["s3:ObjectCreated:*"]
    filter_prefix = "backups/"
    filter_suffix = ".tar.gz"
  }
}

# EFS File System for shared storage (optional)
resource "aws_efs_file_system" "shared_storage" {
  creation_token   = "${var.project_name}-${var.environment}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100

  encrypted = true

  tags = {
    Name = "${var.project_name}-${var.environment}-efs"
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "shared_storage_mt" {
  for_each = toset(data.aws_subnets.default.ids)
  
  file_system_id  = aws_efs_file_system.shared_storage.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name        = "${var.project_name}-${var.environment}-efs-${random_id.suffix.hex}"
  description = "Security group for EFS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "NFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.k8s_master.id, aws_security_group.k8s_worker.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-efs-sg"
  }
}
