# networking.tf - VPC, subnets, and security groups configuration
# Ostad Capstone Project - Networking Infrastructure

# Data source to get default VPC subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Data source to get subnet details
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

# Security Group for Kubernetes Master Node
resource "aws_security_group" "k8s_master" {
  name        = "${var.project_name}-${var.environment}-k8s-master-${random_id.suffix.hex}"
  description = "Security group for Kubernetes master node"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Kubernetes API server
  ingress {
    description = "Kubernetes API"
    from_port   = var.kubernetes_api_port
    to_port     = var.kubernetes_api_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidrs
  }

  # etcd server client API
  ingress {
    description     = "etcd server client API"
    from_port       = 2379
    to_port         = 2380
    protocol        = "tcp"
    security_groups = [aws_security_group.k8s_worker.id]
    self            = true
  }

  # Kubelet API
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
  }

  # kube-scheduler
  ingress {
    description = "kube-scheduler"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    self        = true
  }

  # kube-controller-manager
  ingress {
    description = "kube-controller-manager"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    self        = true
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-k8s-master-sg"
    Type = "kubernetes-master"
  }
}

# Security Group for Kubernetes Worker Nodes
resource "aws_security_group" "k8s_worker" {
  name        = "${var.project_name}-${var.environment}-k8s-worker-${random_id.suffix.hex}"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # HTTP access for applications
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # HTTPS access for applications
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidrs
  }

  # Kubelet API
  ingress {
    description     = "Kubelet API"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.k8s_master.id]
    self            = true
  }

  # NodePort Services
  ingress {
    description = "NodePort Services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # Flannel VXLAN (if using Flannel CNI)
  ingress {
    description = "Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    self        = true
  }

  # Calico BGP (if using Calico CNI)
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    self        = true
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-k8s-worker-sg"
    Type = "kubernetes-worker"
  }
}

# Security Group for Application Load Balancer (if needed)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-${random_id.suffix.hex}"
  description = "Security group for Application Load Balancer"
  vpc_id      = data.aws_vpc.default.id

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_https_cidrs
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Type = "load-balancer"
  }
}

# Internet Gateway (already exists for default VPC)
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Route Table (using default route table)
data "aws_route_table" "default" {
  vpc_id = data.aws_vpc.default.id
  
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# VPC Flow Logs (optional)
resource "aws_flow_log" "vpc_flow_log" {
  count                = var.enable_vpc_flow_logs ? 1 : 0
  iam_role_arn         = aws_iam_role.flow_log[0].arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_log[0].arn
  traffic_type         = "ALL"
  vpc_id               = data.aws_vpc.default.id
  log_destination_type = "cloud-watch-logs"

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-log"
  }
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_log" {
  count             = var.enable_vpc_flow_logs ? 1 : 0
  name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-log-group"
  }
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-flow-log-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-flow-log-role"
  }
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_vpc_flow_logs ? 1 : 0
  name  = "${var.project_name}-${var.environment}-flow-log-policy"
  role  = aws_iam_role.flow_log[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
