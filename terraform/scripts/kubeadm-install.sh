#!/bin/bash
# kubeadm-install.sh - Common installation script for all Kubernetes nodes
# Ostad Capstone Project - Kubeadm Installation

set -e

# Variables
KUBERNETES_VERSION="${kubernetes_version}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/kubeadm-install.log
}

log "Starting Kubernetes node setup for $PROJECT_NAME-$ENVIRONMENT"

# Update system
log "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
log "Installing required packages..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    wget \
    htop \
    vim \
    git \
    jq

# Disable swap
log "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules
log "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set sysctl parameters
log "Setting sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
log "Installing containerd..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io

# Configure containerd
log "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# Add Kubernetes repository
log "Adding Kubernetes repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes components
log "Installing Kubernetes components..."
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl enable kubelet

# Configure kubelet
log "Configuring kubelet..."
cat <<EOF | tee /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
ExecStart=/usr/bin/kubelet --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock --pod-infra-container-image=registry.k8s.io/pause:3.9
Restart=always
EOF

systemctl daemon-reload

# Format and mount additional volume for container storage
log "Setting up additional storage..."
if [ -e /dev/nvme1n1 ] || [ -e /dev/xvdf ]; then
    DEVICE=$(lsblk -n -o NAME,TYPE | grep disk | grep -E "(nvme1n1|xvdf)" | head -1 | awk '{print "/dev/"$1}')
    if [ ! -z "$DEVICE" ]; then
        log "Found additional device: $DEVICE"
        mkfs.ext4 -F $DEVICE
        mkdir -p /var/lib/containerd-storage
        echo "$DEVICE /var/lib/containerd-storage ext4 defaults 0 2" >> /etc/fstab
        mount -a
    fi
fi

# Install AWS CLI
log "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# Install kubectl completion
log "Setting up kubectl completion..."
echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
echo 'alias k=kubectl' >> /home/ubuntu/.bashrc
echo 'complete -o default -F __start_kubectl k' >> /home/ubuntu/.bashrc

# Create kubernetes config directory
mkdir -p /home/ubuntu/.kube
chown ubuntu:ubuntu /home/ubuntu/.kube

# Install Helm
log "Installing Helm..."
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update
apt-get install -y helm

# Configure log rotation
log "Configuring log rotation..."
cat <<EOF | tee /etc/logrotate.d/kubeadm-install
/var/log/kubeadm-install.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Create a status file
log "Creating status file..."
cat <<EOF | tee /tmp/kubeadm-install-status
Installation completed at: $(date)
Kubernetes version: $KUBERNETES_VERSION
Project: $PROJECT_NAME
Environment: $ENVIRONMENT
Node role: Common setup completed
EOF

log "Common Kubernetes node setup completed successfully!"

# Set hostname based on instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Set hostname
hostnamectl set-hostname $INSTANCE_ID

# Update hosts file
cat <<EOF >> /etc/hosts
$PRIVATE_IP $INSTANCE_ID
EOF

log "Node setup completed. Instance ID: $INSTANCE_ID, Private IP: $PRIVATE_IP"
