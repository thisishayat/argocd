# main.tf - Provider and core resources configuration
# Ostad Capstone Project - AWS Infrastructure

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Optional: Configure backend for state storage
  # backend "s3" {
  #   bucket         = "ostad-terraform-state-bucket"
  #   key            = "production/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Owner       = var.owner
      CreatedBy   = "Terraform"
      LinkedIn    = "https://www.linkedin.com/in/mdarifahammedreza/"
    }
  }
}

# Data source to get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Data source to get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-lts-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Create key pair for EC2 instances
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.project_name}-${var.environment}-key-${random_id.suffix.hex}"
  public_key = tls_private_key.ec2_key.public_key_openssh

  tags = {
    Name = "${var.project_name}-${var.environment}-key-pair"
  }
}

# Save private key to local file
resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "${path.module}/keys/${aws_key_pair.ec2_key_pair.key_name}.pem"
  
  provisioner "local-exec" {
    command = "chmod 600 ${path.module}/keys/${aws_key_pair.ec2_key_pair.key_name}.pem"
  }
}
