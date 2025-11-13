# Ostad Capstone Project - DevOps Pipeline Complete

## Project Overview
This repository contains a comprehensive DevOps pipeline implementation for the **Ostad Capstone Project**, featuring complete infrastructure automation, container orchestration, and monitoring solutions.

---

## 1️⃣ Frontend Instructions

**Folder:** `frontend` (React + Tailwind)

1. Install dependencies:

```bash
npm install
```

2. Start development server:

```bash
npm run dev
```

- Runs on port `5173` by default.
- Ensure environment variable is set:

```env
VITE_API_BASE_URL=http://localhost:5050
```

3. Build production version:

```bash
npm run build
```

---

## 2️⃣ Backend Instructions

**Folder:** `server`

1. Environment variables `.env`:

```env
PORT=5050
MONGO_URL=mongodb://ostad:ostad@localhost:27017
REDIS_URL=redis://localhost:6379
DB_NAME=Ostad-DB
CACHE_TTL=600
```

2. Run server with PM2:

```bash
pm2 start server.js --name "ostad-backend"
```

3. Stop / restart server with PM2:

```bash
pm2 stop ostad-backend
pm2 restart ostad-backend
pm2 logs ostad-backend
```

---

## 3️⃣ Database & Caching Services

You need to **set up MongoDB, Redis, and Mongo Express**. Recommended using Docker Compose:

```yaml

      MONGO_INITDB_ROOT_USERNAME: ostad
      MONGO_INITDB_ROOT_PASSWORD: ostad
      MONGO_INITDB_DATABASE: Ostad-DB
    ports:
      - "27017:27017"
  mongo-express:
    environment:
      ME_CONFIG_MONGODB_ADMINUSERNAME: ostad
      ME_CONFIG_MONGODB_ADMINPASSWORD: ostad
      ME_CONFIG_MONGODB_SERVER: mongo
      ME_CONFIG_BASICAUTH_USERNAME: admin
      ME_CONFIG_BASICAUTH_PASSWORD: admin
    ports:
      - "8081:8081"

  redis:
    image: redis:7.0
    ports:
      - "6379:6379"
```

- **Mongo Express Web UI:** [http://localhost:8081](http://localhost:8081)

  - Web login: `admin / admin`
  - Mongo login: `ostad / ostad`

- **Redis:** `localhost:6379`

---

## 4️⃣ Seeding Data

To populate **students and results**:

```bash
node seed.js
```

- Seeds **20,000 students** and **results** in batches.
- Make sure MongoDB is running before seeding.
- After seeding, verify in **Mongo Express**.

---

## 5️⃣ Useful Backend Endpoints

### 🚦 Getting Started & Deployment

#### Prerequisites
- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- Ansible >= 2.15
- kubectl >= 1.28
- Docker >= 24.0

#### Step-by-Step Deployment

**Step 1: Infrastructure Provisioning**
```bash
cd terraform/
terraform init
terraform plan -var-file="production.tfvars"
terraform apply -auto-approve
```

**Step 2: System Configuration**
```bash
cd ansible/
# Health check all nodes
ansible-playbook -i inventories/production.yml playbooks/healthcheck.yml

# Deploy Kubernetes cluster
ansible-playbook -i inventories/production.yml playbooks/kubernetes.yml

# Setup monitoring stack
ansible-playbook -i inventories/production.yml playbooks/monitoring.yml
```

**Step 3: Container & Application Setup**
```bash
# Build application images
cd Result/
docker build -t ostad-capstone:dev-latest --build-arg THEME_INDEX=0 .
docker build -t ostad-capstone:stage-latest --build-arg THEME_INDEX=1 .
docker build -t ostad-capstone:prod-latest --build-arg THEME_INDEX=2 .
```

**Step 4: Kubernetes & ArgoCD Deployment**
```bash
# Create namespaces
kubectl apply -f k8s/namespaces/namespaces.yaml

# Install NGINX Ingress Controller
kubectl apply -f k8s/ingress/nginx-ingress.yaml

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f k8s/argocd/argocd-config.yaml

# Deploy applications via ArgoCD
kubectl apply -f k8s/argocd/applications.yaml

# Configure ingress rules
kubectl apply -f k8s/ingress/ingress.yaml
```

**Step 5: Access & Verification**
```bash
# ArgoCD UI access
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Test applications
curl -H "Host: ostad-capstone-dev.local" http://<INGRESS-IP>/     # Yellow theme
curl -H "Host: ostad-capstone-stage.local" http://<INGRESS-IP>/   # Blue theme
curl -H "Host: ostad-capstone-prod.com" http://<INGRESS-IP>/      # Green theme
```

#### **📖 Comprehensive Deployment Guide**
**For detailed Step 4 implementation with ArgoCD and upgrade strategies, see:**
**[KUBERNETES-DEPLOYMENT-GUIDE.md](./KUBERNETES-DEPLOYMENT-GUIDE.md)**

### 🔄 Kubernetes Upgrade Techniques Implemented

1. **Rolling Updates**: Zero-downtime gradual pod replacement
2. **Blue-Green Deployment**: Complete environment switching with instant rollback
3. **Canary Deployment**: Traffic-based gradual rollout (20% → 100%)

### 🎯 Multi-Environment Configuration

| Environment | Theme  | Replicas | Domain                     | Git Branch |
|-------------|--------|----------|----------------------------|------------|
| Development | Yellow | 3        | ostad-capstone-dev.local   | dev        |
| Staging     | Blue   | 3        | ostad-capstone-stage.local | stage      |
| Production  | Green  | 5 + HPA  | ostad-capstone-prod.com    | main       |

---

This README is **ready for DevOps students** to practice: **environment configuration, Docker setup, seeding, PM2 process management, and running the full stack**.
