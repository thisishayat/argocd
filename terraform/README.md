# Terraform AWS Infrastructure for Ostad Capstone Project

## 🚀 Overview

This Terraform configuration provisions a production-ready AWS infrastructure for the Ostad Capstone Project, including:

- **3 EC2 instances** (1 master + 2 worker nodes) configured for Kubernetes
- **S3 buckets** for application storage, backups, and logs
- **Security groups** with appropriate networking rules
- **Application Load Balancer** for high availability
- **EFS file system** for shared storage
- **Complete Kubernetes setup** with kubeadm

## 📁 Directory Structure

```
terraform/
├── main.tf              # Provider and core resources
├── variables.tf         # Input variables with validation
├── terraform.tfvars     # Variable values
├── networking.tf        # VPC, security groups, networking
├── compute.tf          # EC2 instances and related resources
├── storage.tf          # S3 buckets and EFS
├── outputs.tf          # Output values
├── scripts/            # Installation scripts
│   ├── kubeadm-install.sh       # Common Kubernetes installation
│   └── kubeadm-master-init.sh   # Master node initialization
└── README.md           # This file
```

## 🛠️ Prerequisites

### Required Tools
```bash
# Install Terraform (version >= 1.5)
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### AWS Configuration
```bash
# Configure AWS credentials
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region name (e.g., us-east-1)
# - Default output format (json)

# Verify configuration
aws sts get-caller-identity
```

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- EC2 (full access)
- S3 (full access)
- IAM (create roles and policies)
- EFS (full access)
- CloudWatch (create log groups)
- VPC (read access to default VPC)

## 🚀 Quick Start

### 1. Clone and Navigate
```bash
git clone <repository-url>
cd terraform/
```

### 2. Review and Modify Configuration
Edit `terraform.tfvars` to customize your deployment:
```hcl
# Basic Configuration
aws_region   = "us-east-1"
project_name = "ostad-capstone"
environment  = "production"

# Instance Configuration
instance_count       = 3
master_instance_type = "t3.large"
worker_instance_type = "t3.medium"

# Security (IMPORTANT: Restrict in production)
allowed_ssh_cidrs = ["YOUR_IP_ADDRESS/32"]  # Replace with your IP
```

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Plan Deployment
```bash
terraform plan
```

### 5. Deploy Infrastructure
```bash
terraform apply
```

### 6. Access Your Cluster
```bash
# Get connection details
terraform output ssh_connection_commands

# Connect to master node
ssh -i keys/ostad-capstone-production-key-*.pem ubuntu@<master-public-ip>

# Copy kubeconfig
terraform output kubeconfig_setup_command
# Run the displayed command to copy kubeconfig
```

## 📋 Post-Deployment Steps

### 1. Verify Cluster Status
```bash
# Connect to master node
ssh -i keys/<key-name>.pem ubuntu@<master-ip>

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check cluster info
cat /tmp/cluster-info.txt
```

### 2. Join Worker Nodes (if needed)
```bash
# Worker nodes should automatically join
# If manual intervention needed:
cat /tmp/kubeadm-join-command.sh

# Run the join command on worker nodes
```

### 3. Access Kubernetes Dashboard
```bash
# Get dashboard token
cat /tmp/dashboard-token.txt

# Port forward dashboard (on master)
kubectl proxy --address='0.0.0.0' --disable-filter=true

# Access at: http://<master-ip>:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### 4. Access ArgoCD
```bash
# Get ArgoCD password
cat /tmp/argocd-password.txt

# Port forward ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address='0.0.0.0'

# Access at: https://<master-ip>:8080
# Username: admin
# Password: (from argocd-password.txt)
```

## 🔧 Configuration Options

### Instance Types
| Purpose | Default | Recommended Production |
|---------|---------|----------------------|
| Master | t3.large | t3.xlarge or m5.large |
| Worker | t3.medium | t3.large or m5.xlarge |

### Storage Configuration
- **Root Volume**: 20GB GP3 (encrypted)
- **Container Storage**: 30GB GP3 (encrypted)
- **S3 Buckets**: Application, backup, logs (versioned)
- **EFS**: Shared storage for pods

### Networking
- **VPC**: Default VPC (modify for production)
- **Security Groups**: Kubernetes-optimized rules
- **Load Balancer**: Application Load Balancer for worker nodes
- **Elastic IP**: Assigned to master node

## 📊 Monitoring and Logging

### CloudWatch Integration
```bash
# Enable detailed monitoring
enable_cloudwatch_monitoring = true

# View logs
aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/ostad-capstone"
```

### Application Monitoring
The cluster includes:
- **Kubernetes Dashboard**: Web UI for cluster management
- **ArgoCD**: GitOps continuous deployment
- **cert-manager**: TLS certificate management
- **AWS Load Balancer Controller**: Ingress management

## 🔐 Security Best Practices

### Network Security
```hcl
# Restrict SSH access (terraform.tfvars)
allowed_ssh_cidrs = ["YOUR_IP/32"]  # Your IP only

# Use specific CIDR blocks for HTTP/HTTPS
allowed_http_cidrs  = ["10.0.0.0/8"]  # Internal only
allowed_https_cidrs = ["0.0.0.0/0"]   # Public HTTPS
```

### Instance Security
- All EBS volumes encrypted
- Non-root containers
- Security groups with minimal required ports
- IAM roles with least privilege

### Storage Security
- S3 buckets with encryption at rest
- Public access blocked
- Lifecycle policies for cost optimization

## 💰 Cost Optimization

### Estimated Monthly Costs (us-east-1)
| Resource | Quantity | Type | Monthly Cost |
|----------|----------|------|--------------|
| EC2 Master | 1 | t3.large | ~$60 |
| EC2 Workers | 2 | t3.medium | ~$60 |
| EBS Volumes | 6 | 20GB each | ~$12 |
| S3 Storage | 3 buckets | Standard | ~$5 |
| Load Balancer | 1 | ALB | ~$20 |
| **Total** | | | **~$157/month** |

### Cost Reduction Tips
- Use Spot Instances for non-production
- Enable S3 lifecycle policies
- Right-size instances based on usage
- Delete unused snapshots

## 🔄 Disaster Recovery

### Backup Strategy
```bash
# Automated EBS snapshots enabled
enable_automated_backups = true
backup_retention_days   = 7

# S3 versioning and lifecycle
s3_versioning_enabled = true
s3_lifecycle_enabled  = true
```

### Restore Procedure
1. Launch instances from latest snapshots
2. Restore kubeconfig and certificates
3. Re-join worker nodes to cluster
4. Restore application data from S3

## 🧪 Testing

### Validate Deployment
```bash
# Test cluster functionality
kubectl run test-pod --image=nginx --rm -it -- /bin/bash

# Test load balancer
curl http://<alb-dns-name>/health

# Test S3 access
aws s3 ls s3://ostad-capstone-production-application-*
```

### Smoke Tests
```bash
# Deploy test application
kubectl create deployment test-app --image=nginx
kubectl expose deployment test-app --port=80 --type=LoadBalancer

# Verify ArgoCD
kubectl get pods -n argocd
```

## 🔧 Troubleshooting

### Common Issues

#### Master Node Not Ready
```bash
# Check kubelet logs
sudo journalctl -u kubelet -f

# Check containerd status
sudo systemctl status containerd

# Reinitialize cluster (if needed)
sudo kubeadm reset
```

#### Worker Nodes Not Joining
```bash
# Generate new join token
kubeadm token create --print-join-command

# Check network connectivity
ping <master-private-ip>
telnet <master-private-ip> 6443
```

#### S3 Access Issues
```bash
# Check IAM role
aws sts get-caller-identity

# Test S3 permissions
aws s3 ls s3://bucket-name
```

### Useful Commands
```bash
# Terraform debugging
export TF_LOG=DEBUG
terraform plan -detailed-exitcode

# AWS resource inspection
aws ec2 describe-instances --filters "Name=tag:Project,Values=ostad-capstone"
aws s3api list-buckets --query 'Buckets[?starts_with(Name, `ostad-capstone`)]'

# Kubernetes debugging
kubectl describe nodes
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 🚮 Cleanup

### Destroy Infrastructure
```bash
# Warning: This will delete all resources!
terraform destroy

# Verify cleanup
aws ec2 describe-instances --filters "Name=tag:Project,Values=ostad-capstone"
```

### Manual Cleanup (if needed)
```bash
# Delete S3 buckets (if versioned)
aws s3api delete-objects --bucket bucket-name --delete "$(aws s3api list-object-versions --bucket bucket-name --output json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

# Delete load balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[?starts_with(LoadBalancerName, `ostad-capstone`)]'
```

## 📞 Support

**Project Owner**: Md Arif Ahammedrez  
**LinkedIn**: [mdarifahammedreza](https://www.linkedin.com/in/mdarifahammedreza/)  
**Repository**: [Ostad-Capstone-project](https://github.com/mdarifahammedreza/Ostad-Capstone-project)

## 🔗 References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubeadm Installation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
