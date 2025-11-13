# Ostad Capstone Project - Production Setup

## 🚀 Project Overview

This project implements a complete CI/CD pipeline with three environments:
- **Dev Branch**: Development environment with Yellow theme
- **Stage Branch**: Testing environment with Blue theme  
- **Main Branch**: Production environment with Green theme

## 📁 Project Structure

```
├── Result/                          # Frontend React application
│   ├── src/
│   │   ├── App.jsx                  # Main application component
│   │   └── ...
│   ├── index.html                   # HTML template
│   └── package.json
├── argocd/                          # ArgoCD configuration
│   └── application.yaml             # ArgoCD application definition
├── k8s/                             # Kubernetes manifests
│   └── production/                  # Production environment configs
│       ├── namespace.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── hpa.yaml
├── scripts/                         # Automation scripts
│   ├── deploy-production.sh         # Production deployment script
│   └── setup-argocd.sh             # ArgoCD setup script
├── .github/workflows/               # GitHub Actions
│   └── production-pipeline.yml     # Production CI/CD pipeline
├── docker-compose.production.yml    # Production Docker Compose
├── docker-compose.sonarqube.yml    # SonarQube Docker Compose
├── Dockerfile.production           # Production Dockerfile
├── nginx.conf                      # Nginx configuration
└── sonar-project.properties        # SonarQube configuration
```

## 🎨 Environment Configuration

### Color Themes by Environment
- **Dev (themes[0])**: Yellow theme for development
- **Stage (themes[1])**: Blue theme for staging  
- **Main (themes[2])**: Green theme for production

### Branch-Specific Changes
- **Dev**: LinkedIn ID only
- **Stage**: LinkedIn ID + Name
- **Main**: LinkedIn ID + Name (Production ready)

## 🔧 Production Setup

### 1. Code Quality & Coverage (SonarQube)

#### Manual SonarQube Setup:
```bash
# Start SonarQube with Docker
docker-compose -f docker-compose.sonarqube.yml up -d

# Access SonarQube UI at http://localhost:9000
# Default credentials: admin/admin
```

#### Configuration:
- **Minimum Coverage**: 80%
- **Quality Gate**: Enforced on all builds
- **Language Support**: JavaScript/JSX
- **Reports**: LCOV format expected

### 2. Docker Configuration

#### Production Image:
```bash
# Build production image
docker build -f Dockerfile.production -t mdarifahammedreza/ostad-capstone:latest .

# Run production container
docker-compose -f docker-compose.production.yml up -d
```

#### Features:
- **Multi-stage build**: Optimized for production
- **Nginx**: Serves static files with compression
- **Health checks**: Built-in monitoring
- **Security**: Non-root user, read-only filesystem

### 3. ArgoCD Pipeline Setup

#### Prerequisites:
- Kubernetes cluster
- kubectl configured
- ArgoCD installed

#### Setup Steps:
```bash
# Run the setup script
./scripts/setup-argocd.sh

# Or manually:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/application.yaml
```

#### Features:
- **Automated sync**: Monitors main branch for changes
- **Self-healing**: Automatically fixes configuration drift
- **Rollback**: Easy rollback to previous versions
- **Multi-environment**: Separate configs for each environment

## 🚀 Deployment Process

### Automated (GitHub Actions)
The production pipeline automatically triggers on pushes to `main`:

1. **Code Quality Check**: SonarQube analysis with coverage threshold
2. **Pull Docker Image**: Gets latest image from stage environment
3. **Deploy**: Uses self-hosted runner for production deployment
4. **Health Check**: Verifies application is running correctly
5. **Security Scan**: Trivy vulnerability scanning

### Manual Deployment
```bash
# Run the production deployment script
./scripts/deploy-production.sh
```

### ArgoCD Deployment
ArgoCD automatically syncs when changes are detected in the main branch:
- Monitors repository for changes
- Applies Kubernetes manifests
- Provides rollback capabilities
- Sends notifications on deployment status

## 🔍 Monitoring & Health Checks

### Application Health
- **Endpoint**: `/health`
- **Port**: 80
- **Response**: "healthy" (200 OK)

### Container Health
```bash
# Check container status
docker-compose -f docker-compose.production.yml ps

# View logs
docker-compose -f docker-compose.production.yml logs -f
```

### Kubernetes Monitoring
```bash
# Check pod status
kubectl get pods -n ostad-production

# Check application logs
kubectl logs -f deployment/ostad-capstone-app -n ostad-production

# Check ArgoCD application status
argocd app get ostad-capstone-production
```

## 🔐 Security Configuration

### Container Security
- Non-root user (UID 101)
- Read-only root filesystem
- Dropped capabilities
- Security headers in Nginx

### Kubernetes Security
- Network policies
- Resource limits
- Security contexts
- TLS termination at ingress

## 📊 Metrics & Scaling

### Horizontal Pod Autoscaler
- **Min replicas**: 3
- **Max replicas**: 10
- **CPU threshold**: 70%
- **Memory threshold**: 80%

### Resource Limits
- **Requests**: 100m CPU, 128Mi memory
- **Limits**: 500m CPU, 512Mi memory

## 🛠️ Development Workflow

### Branch Strategy
1. **Feature development**: Create feature branches from `dev`
2. **Testing**: Merge to `stage` branch for staging tests
3. **Production**: Merge to `main` for production deployment

### Local Development
```bash
# Install dependencies
cd Result
npm install

# Run development server
npm run dev

# Run tests with coverage
npm run test:coverage
```

## 🔧 Troubleshooting

### Common Issues

#### SonarQube Analysis Fails
```bash
# Check SonarQube logs
docker-compose -f docker-compose.sonarqube.yml logs sonarqube

# Restart SonarQube
docker-compose -f docker-compose.sonarqube.yml restart
```

#### Application Not Starting
```bash
# Check container logs
docker-compose -f docker-compose.production.yml logs ostad-app-production

# Rebuild image
docker build -f Dockerfile.production -t mdarifahammedreza/ostad-capstone:latest .
```

#### ArgoCD Sync Issues
```bash
# Manual sync
argocd app sync ostad-capstone-production

# Check application status
argocd app get ostad-capstone-production

# Refresh repository
argocd app refresh ostad-capstone-production
```

## 📞 Support

**Project Owner**: Md Arif Ahammedrez  
**LinkedIn**: [mdarifahammedreza](https://www.linkedin.com/in/mdarifahammedreza/)  
**Repository**: [Ostad-Capstone-project](https://github.com/mdarifahammedreza/Ostad-Capstone-project)

## 🏗️ Infrastructure Requirements

### Minimum System Requirements
- **CPU**: 2 cores
- **Memory**: 4GB RAM
- **Storage**: 20GB
- **Network**: Stable internet connection

### Production Environment
- **Kubernetes cluster**: 1.20+
- **Docker**: 20.10+
- **Node.js**: 18+
- **ArgoCD**: Latest stable version

## 🚀 Quick Start

1. **Clone the repository**
```bash
git clone https://github.com/mdarifahammedreza/Ostad-Capstone-project.git
cd Ostad-Capstone-project
```

2. **Setup SonarQube**
```bash
docker-compose -f docker-compose.sonarqube.yml up -d
```

3. **Deploy to production**
```bash
./scripts/deploy-production.sh
```

4. **Setup ArgoCD (optional)**
```bash
./scripts/setup-argocd.sh
```

5. **Access the application**
- Production: http://localhost:80
- SonarQube: http://localhost:9000
- ArgoCD: https://localhost:8080
