# Step 4: Kubernetes Deployment with ArgoCD - Implementation Guide

## Overview
This guide implements a comprehensive Kubernetes deployment strategy using ArgoCD for GitOps, with multi-environment support and advanced deployment strategies.

## 🎯 Objectives Achieved

### 1. Multi-Environment Setup
- **Development (dev)**: Yellow theme, 3 replicas, development configuration
- **Staging (stage)**: Blue theme, 3 replicas, staging configuration  
- **Production (prod)**: Green theme, 5 replicas with HPA, production-ready setup

### 2. ArgoCD GitOps Implementation
- **Automated Deployments**: Continuous sync with Git repositories
- **Environment Separation**: Different branches for different environments
- **Self-Healing**: Automatic drift detection and correction
- **Rollback Capabilities**: Easy reversion to previous versions

### 3. Advanced Deployment Strategies
- **Rolling Updates**: Zero-downtime gradual updates
- **Blue-Green Deployments**: Complete environment switching
- **Canary Deployments**: Gradual traffic shifting for risk mitigation

### 4. NGINX Ingress Controller
- **External Access**: Centralized ingress management
- **SSL/TLS Termination**: Automatic certificate management
- **Rate Limiting**: Traffic control and protection
- **Path-based Routing**: Multiple applications on single domain

### 5. Monitoring & Observability Integration
- **Prometheus Integration**: Metrics collection from all environments
- **Grafana Dashboards**: Visual monitoring and alerting
- **Loki Log Aggregation**: Centralized logging solution
- **Health Checks**: Application and infrastructure monitoring

## 📁 Directory Structure

```
k8s/
├── namespaces/
│   └── namespaces.yaml              # Dev, Stage, Prod, ArgoCD, Monitoring namespaces
├── applications/
│   ├── dev/
│   │   └── deployment.yaml          # 3 replicas, yellow theme
│   ├── stage/
│   │   └── deployment.yaml          # 3 replicas, blue theme
│   └── prod/
│       └── deployment.yaml          # 5 replicas + HPA, green theme
├── ingress/
│   ├── ingress.yaml                 # Multi-environment ingress rules
│   └── nginx-ingress.yaml           # NGINX controller installation
├── argocd/
│   ├── applications.yaml            # ArgoCD application definitions
│   └── argocd-config.yaml           # ArgoCD configuration and RBAC
└── upgrade-strategies/
    ├── rolling-update.yaml          # Rolling deployment strategy
    ├── blue-green.yaml              # Blue-green deployment strategy
    └── canary.yaml                  # Canary deployment strategy
```

## 🚀 Deployment Instructions

### Prerequisites
```bash
# Ensure Kubernetes cluster is running
kubectl cluster-info

# Verify nodes are ready
kubectl get nodes

# Check available resources
kubectl describe nodes
```

### Step 1: Create Namespaces
```bash
kubectl apply -f k8s/namespaces/namespaces.yaml
kubectl get namespaces
```

### Step 2: Install NGINX Ingress Controller
```bash
kubectl apply -f k8s/ingress/nginx-ingress.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

### Step 3: Install ArgoCD
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply custom ArgoCD configuration
kubectl apply -f k8s/argocd/argocd-config.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Step 4: Access ArgoCD UI
```bash
# Port forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI at: https://localhost:8080
# Username: admin
# Password: (from above command)
```

### Step 5: Deploy Applications via ArgoCD
```bash
# Deploy ArgoCD applications
kubectl apply -f k8s/argocd/applications.yaml

# Check application status
kubectl get applications -n argocd
```

### Step 6: Configure Ingress Rules
```bash
# Apply ingress configurations
kubectl apply -f k8s/ingress/ingress.yaml

# Check ingress status
kubectl get ingress --all-namespaces
```

## 🔄 Kubernetes Upgrade Techniques

### 1. Rolling Update (Default Strategy)
**Use Case**: Standard updates with minimal risk
**Configuration**: `k8s/upgrade-strategies/rolling-update.yaml`

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 2              # Allow 2 extra pods during update
    maxUnavailable: 1        # Allow 1 pod to be unavailable
```

**Deployment**:
```bash
kubectl apply -f k8s/upgrade-strategies/rolling-update.yaml
kubectl rollout status deployment/ostad-capstone-rolling -n prod
```

### 2. Blue-Green Deployment
**Use Case**: Zero-downtime deployments with instant rollback
**Configuration**: `k8s/upgrade-strategies/blue-green.yaml`

```bash
# Deploy new version (green)
kubectl apply -f k8s/upgrade-strategies/blue-green.yaml

# Test green environment
kubectl get pods -l environment=green -n prod

# Switch traffic to green
kubectl patch service ostad-capstone-bluegreen-service -n prod -p '{"spec":{"selector":{"environment":"green"}}}'

# Rollback if needed
kubectl patch service ostad-capstone-bluegreen-service -n prod -p '{"spec":{"selector":{"environment":"blue"}}}'
```

### 3. Canary Deployment
**Use Case**: Gradual rollout with risk mitigation
**Configuration**: `k8s/upgrade-strategies/canary.yaml`

```bash
# Deploy canary version (20% traffic)
kubectl apply -f k8s/upgrade-strategies/canary.yaml

# Monitor canary metrics
kubectl get pods -l track=canary -n prod

# Increase canary traffic (modify ingress annotation)
kubectl annotate ingress ostad-capstone-canary-ingress -n prod \
  nginx.ingress.kubernetes.io/canary-weight=50

# Complete deployment by scaling up canary and scaling down stable
kubectl scale deployment ostad-capstone-canary --replicas=5 -n prod
kubectl scale deployment ostad-capstone-stable --replicas=0 -n prod
```

## 📊 Monitoring & Observability

### Prometheus Integration
```yaml
# ServiceMonitor for metrics collection
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ostad-capstone-metrics
  namespace: prod
spec:
  selector:
    matchLabels:
      app: ostad-capstone
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
```

### Grafana Dashboards
- **Application Performance**: Response times, error rates, throughput
- **Infrastructure Metrics**: CPU, memory, disk usage
- **Deployment Metrics**: Rollout success rates, deployment frequency
- **Business Metrics**: User engagement, feature adoption

### Loki Log Aggregation
```yaml
# Fluent Bit configuration for log shipping
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: monitoring
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        
    [INPUT]
        Name              tail
        Path              /var/log/containers/*ostad-capstone*.log
        Parser            docker
        Tag               kube.*
        
    [OUTPUT]
        Name              loki
        Match             *
        Host              loki.monitoring.svc.cluster.local
        Port              3100
        Labels            job=fluent-bit
```

## 🔧 ArgoCD Configuration

### Repository Management
```yaml
repositories:
  - type: git
    url: https://github.com/mdarifahammedreza/Ostad-Capstone-project.git
    name: ostad-capstone-repo
```

### Application Sync Policies
- **Automated Sync**: Continuous deployment from Git
- **Self-Healing**: Automatic drift correction
- **Pruning**: Removal of obsolete resources
- **Retry Logic**: Automatic retry on failures

### RBAC Configuration
- **Admin Role**: Full access to all applications
- **Developer Role**: Environment-specific access
- **ReadOnly Role**: View-only access for stakeholders

## 🛡️ Security Best Practices

### Pod Security
- **Non-root containers**: All containers run as non-root users
- **Resource limits**: CPU and memory constraints
- **Read-only root filesystem**: Immutable container filesystems
- **Security contexts**: Dropped capabilities and privilege escalation prevention

### Network Security
- **Network policies**: Restricted pod-to-pod communication
- **Ingress TLS**: Encrypted external communications
- **Service mesh**: mTLS for internal communications (future enhancement)

### Secrets Management
- **Kubernetes secrets**: Encrypted at rest
- **External secret operators**: Integration with HashiCorp Vault (future)
- **RBAC**: Granular access control

## 📈 Scaling and Performance

### Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ostad-capstone-prod-hpa
spec:
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Resource Optimization
- **Requests vs Limits**: Proper resource allocation
- **Quality of Service**: Guaranteed QoS for critical workloads
- **Node Affinity**: Optimal pod placement

## 🚨 Troubleshooting Guide

### Common Issues and Solutions

#### ArgoCD Application Not Syncing
```bash
# Check application status
kubectl get app ostad-capstone-prod -n argocd -o yaml

# Force sync
kubectl patch app ostad-capstone-prod -n argocd --type merge -p='{"operation":{"sync":{"revision":"HEAD"}}}'
```

#### Ingress Not Accessible
```bash
# Check ingress controller status
kubectl get pods -n ingress-nginx

# Verify ingress rules
kubectl describe ingress ostad-capstone-ingress -n prod

# Check service endpoints
kubectl get endpoints -n prod
```

#### Pod Startup Issues
```bash
# Check pod events
kubectl describe pod <pod-name> -n prod

# View pod logs
kubectl logs <pod-name> -n prod -f

# Check resource constraints
kubectl top pods -n prod
```

## 📚 Additional Resources

### ArgoCD Documentation
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)

### Kubernetes Deployment Strategies
- [Rolling Updates](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)
- [Blue-Green Deployments](https://argoproj.github.io/argo-rollouts/features/bluegreen/)
- [Canary Deployments](https://argoproj.github.io/argo-rollouts/features/canary/)

### Monitoring and Observability
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)

---

## ✅ Validation Checklist

- [ ] All namespaces created successfully
- [ ] NGINX Ingress Controller deployed and running
- [ ] ArgoCD installed and accessible
- [ ] Applications deployed in all environments (dev/stage/prod)
- [ ] Ingress rules configured and accessible
- [ ] Monitoring stack integrated (Prometheus/Grafana/Loki)
- [ ] All three deployment strategies tested
- [ ] Security policies applied
- [ ] Documentation updated

**🎉 Kubernetes deployment with ArgoCD is now complete and production-ready!**
