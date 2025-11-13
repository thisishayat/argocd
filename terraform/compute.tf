# compute.tf - EC2 instances configuration
# Ostad Capstone Project - Compute Infrastructure

# Create directory for SSH keys
resource "null_resource" "create_keys_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/keys"
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  }
}

# IAM Policy for EC2 instances (for Kubernetes)
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.project_name}-${var.environment}-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyVolume",
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteVolume",
          "ec2:DetachVolume",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DescribeVpcs",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:AttachLoadBalancerToSubnets",
          "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateLoadBalancerPolicy",
          "elasticloadbalancing:CreateLoadBalancerListeners",
          "elasticloadbalancing:ConfigureHealthCheck",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancerListeners",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DetachLoadBalancerFromSubnets",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancerPolicies",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:SetLoadBalancerPoliciesOfListener"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-*/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-profile"
  }
}

# User data script for Kubernetes installation
locals {
  user_data_common = base64encode(templatefile("${path.module}/scripts/kubeadm-install.sh", {
    kubernetes_version = var.kubernetes_version
    project_name      = var.project_name
    environment       = var.environment
  }))
  
  user_data_master = base64encode(templatefile("${path.module}/scripts/kubeadm-master-init.sh", {
    kubernetes_version    = var.kubernetes_version
    pod_network_cidr     = var.pod_network_cidr
    service_network_cidr = var.service_network_cidr
    project_name         = var.project_name
    environment          = var.environment
  }))
}

# Kubernetes Master Node (Control Plane)
resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.master_instance_type
  key_name              = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.k8s_master.id]
  subnet_id             = element(tolist(data.aws_subnets.default.ids), 0)
  iam_instance_profile  = aws_iam_instance_profile.ec2_profile.name
  
  user_data                   = local.user_data_master
  associate_public_ip_address = true
  
  monitoring = var.enable_cloudwatch_monitoring

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "${var.project_name}-${var.environment}-master-root-volume"
    }
  }

  # Additional volume for container storage
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.additional_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "${var.project_name}-${var.environment}-master-container-volume"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-k8s-master"
    Type = "kubernetes-master"
    Role = "control-plane"
  }

  depends_on = [null_resource.create_keys_dir]
}

# Kubernetes Worker Nodes
resource "aws_instance" "k8s_workers" {
  count                  = var.instance_count - 1 # Subtract 1 for master node
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  key_name              = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.k8s_worker.id]
  subnet_id             = element(tolist(data.aws_subnets.default.ids), count.index % length(data.aws_subnets.default.ids))
  iam_instance_profile  = aws_iam_instance_profile.ec2_profile.name
  
  user_data                   = local.user_data_common
  associate_public_ip_address = true
  
  monitoring = var.enable_cloudwatch_monitoring

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "${var.project_name}-${var.environment}-worker-${count.index + 1}-root-volume"
    }
  }

  # Additional volume for container storage
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.additional_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "${var.project_name}-${var.environment}-worker-${count.index + 1}-container-volume"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-k8s-worker-${count.index + 1}"
    Type = "kubernetes-worker"
    Role = "worker-node"
  }

  depends_on = [aws_instance.k8s_master]
}

# Elastic IP for Master Node (optional)
resource "aws_eip" "k8s_master_eip" {
  instance = aws_instance.k8s_master.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-master-eip"
  }

  depends_on = [aws_instance.k8s_master]
}

# Application Load Balancer for worker nodes (optional)
resource "aws_lb" "k8s_alb" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = data.aws_subnets.default.ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "k8s_tg" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-target-group"
  }
}

# ALB Listener
resource "aws_lb_listener" "k8s_listener" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_tg.arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-listener"
  }
}

# Attach worker nodes to target group
resource "aws_lb_target_group_attachment" "k8s_tg_attachment" {
  count            = length(aws_instance.k8s_workers)
  target_group_arn = aws_lb_target_group.k8s_tg.arn
  target_id        = aws_instance.k8s_workers[count.index].id
  port             = 80
}

# CloudWatch Log Groups for instances
resource "aws_cloudwatch_log_group" "k8s_logs" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-logs"
  }
}

# EBS Snapshots for backup (if enabled)
resource "aws_ebs_snapshot" "k8s_backup" {
  count       = var.enable_automated_backups ? var.instance_count : 0
  volume_id   = count.index == 0 ? aws_instance.k8s_master.root_block_device[0].volume_id : aws_instance.k8s_workers[count.index - 1].root_block_device[0].volume_id
  description = "Backup snapshot for ${var.project_name}-${var.environment} instance ${count.index == 0 ? "master" : "worker-${count.index}"}"

  tags = {
    Name = "${var.project_name}-${var.environment}-backup-${count.index == 0 ? "master" : "worker-${count.index}"}"
  }
}
