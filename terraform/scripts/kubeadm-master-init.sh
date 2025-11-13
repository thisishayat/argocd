#!/bin/bash
# kubeadm-master-init.sh - Kubernetes master node initialization script
# Ostad Capstone Project - Master Node Setup

set -e

# Variables
KUBERNETES_VERSION="${kubernetes_version}"
POD_NETWORK_CIDR="${pod_network_cidr}"
SERVICE_NETWORK_CIDR="${service_network_cidr}"
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/kubeadm-master-init.log
}

log "Starting Kubernetes master node initialization for $PROJECT_NAME-$ENVIRONMENT"

# First run the common installation script
source /var/lib/cloud/instance/scripts/part-001

# Wait for the common script to complete
sleep 30

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

log "Master node IPs - Private: $PRIVATE_IP, Public: $PUBLIC_IP"

# Create kubeadm config
log "Creating kubeadm configuration..."
cat <<EOF | tee /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  kubeletExtraArgs:
    cloud-provider: aws
    provider-id: aws:///\$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/\$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
localAPIEndpoint:
  advertiseAddress: $PRIVATE_IP
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v$KUBERNETES_VERSION.0
clusterName: $PROJECT_NAME-$ENVIRONMENT
controlPlaneEndpoint: $PUBLIC_IP:6443
networking:
  serviceSubnet: $SERVICE_NETWORK_CIDR
  podSubnet: $POD_NETWORK_CIDR
apiServer:
  certSANs:
  - $PRIVATE_IP
  - $PUBLIC_IP
  - localhost
  - 127.0.0.1
  extraArgs:
    cloud-provider: aws
controllerManager:
  extraArgs:
    cloud-provider: aws
    configure-cloud-routes: "false"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
cloudProvider: aws
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
EOF

# Initialize the cluster
log "Initializing Kubernetes cluster..."
kubeadm init --config=/tmp/kubeadm-config.yaml --upload-certs --v=5 | tee /var/log/kubeadm-init.log

# Setup kubectl for ubuntu user
log "Setting up kubectl for ubuntu user..."
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Setup kubectl for root user
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# Install Flannel CNI
log "Installing Flannel CNI plugin..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Install AWS Load Balancer Controller prerequisites
log "Installing AWS Load Balancer Controller prerequisites..."
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

# Create the IAM policy (if not already exists)
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json \
    --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region) || true

# Install cert-manager
log "Installing cert-manager..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
log "Waiting for cert-manager to be ready..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf wait --for=condition=ready pod -l app=cert-manager -n cert-manager --timeout=300s
kubectl --kubeconfig=/etc/kubernetes/admin.conf wait --for=condition=ready pod -l app=cainjector -n cert-manager --timeout=300s
kubectl --kubeconfig=/etc/kubernetes/admin.conf wait --for=condition=ready pod -l app=webhook -n cert-manager --timeout=300s

# Install AWS Load Balancer Controller
log "Installing AWS Load Balancer Controller..."
curl -o v2_7_2_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.7.2/v2_7_2_full.yaml

# Modify the controller deployment
sed -i.bak -e "s/your-cluster-name/$PROJECT_NAME-$ENVIRONMENT/g" v2_7_2_full.yaml
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f v2_7_2_full.yaml

# Install Kubernetes Dashboard
log "Installing Kubernetes Dashboard..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create dashboard admin user
log "Creating dashboard admin user..."
cat <<EOF | kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Generate join command for worker nodes
log "Generating join command for worker nodes..."
kubeadm token create --print-join-command | tee /tmp/kubeadm-join-command.sh
chmod +x /tmp/kubeadm-join-command.sh

# Copy join command to S3 for worker nodes (optional)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
aws s3 cp /tmp/kubeadm-join-command.sh s3://$PROJECT_NAME-$ENVIRONMENT-application-*/join-command.sh --region $REGION || log "Failed to upload join command to S3"

# Get dashboard token
log "Getting dashboard admin token..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf -n kubernetes-dashboard create token admin-user | tee /tmp/dashboard-token.txt

# Create cluster info
log "Creating cluster information file..."
cat <<EOF | tee /tmp/cluster-info.txt
Cluster Name: $PROJECT_NAME-$ENVIRONMENT
Kubernetes Version: v$KUBERNETES_VERSION.0
Master Node Private IP: $PRIVATE_IP
Master Node Public IP: $PUBLIC_IP
Pod Network CIDR: $POD_NETWORK_CIDR
Service Network CIDR: $SERVICE_NETWORK_CIDR

Dashboard URL: https://$PUBLIC_IP:8443
Dashboard Token: $(cat /tmp/dashboard-token.txt)

Join Command: $(cat /tmp/kubeadm-join-command.sh)

Kubeconfig location: /home/ubuntu/.kube/config

To access the cluster:
1. Copy kubeconfig: scp ubuntu@$PUBLIC_IP:~/.kube/config ~/.kube/config
2. Access dashboard: kubectl proxy --address='0.0.0.0' --disable-filter=true
3. Dashboard URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
EOF

# Install ArgoCD
log "Installing ArgoCD..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf create namespace argocd || true
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
log "Waiting for ArgoCD to be ready..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=600s

# Get ArgoCD admin password
log "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl --kubeconfig=/etc/kubernetes/admin.conf -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD" | tee /tmp/argocd-password.txt

# Expose ArgoCD server
log "Exposing ArgoCD server..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Create a status file
log "Creating master status file..."
cat <<EOF | tee /tmp/kubeadm-master-status
Master initialization completed at: $(date)
Kubernetes version: v$KUBERNETES_VERSION.0
Project: $PROJECT_NAME
Environment: $ENVIRONMENT
Node role: Master (Control Plane)
Cluster status: Initialized
CNI: Flannel
Dashboard: Installed
ArgoCD: Installed
Load Balancer Controller: Installed
EOF

# Setup log rotation for master logs
cat <<EOF | tee /etc/logrotate.d/kubeadm-master
/var/log/kubeadm-master-init.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

log "Kubernetes master node initialization completed successfully!"
log "Cluster info saved to /tmp/cluster-info.txt"
log "Join command saved to /tmp/kubeadm-join-command.sh"
log "Dashboard token saved to /tmp/dashboard-token.txt"
log "ArgoCD password saved to /tmp/argocd-password.txt"

# Final cluster status check
log "Final cluster status check..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide | tee -a /var/log/kubeadm-master-init.log
kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods --all-namespaces | tee -a /var/log/kubeadm-master-init.log

log "Master node setup completed. Ready for worker nodes to join!"
