#!/bin/bash
# Production Deployment Script for Ostad Capstone Project

set -e

# Configuration
DOCKER_USERNAME="mdarifahammedreza"
IMAGE_NAME="ostad-capstone"
STAGE_TAG="stage-latest"
PROD_TAG="latest"

echo "🚀 Starting Production Deployment Process..."

# Step 1: Run SonarQube Analysis
echo "📊 Step 1: Running SonarQube Code Quality Analysis..."
if command -v sonar-scanner &> /dev/null; then
    cd Result
    npm install
    npm run test:coverage 2>/dev/null || npm test -- --coverage --watchAll=false
    cd ..
    sonar-scanner
    echo "✅ SonarQube analysis completed"
else
    echo "⚠️  SonarQube scanner not found. Please install sonar-scanner CLI"
    echo "   You can run SonarQube using Docker: docker-compose -f docker-compose.sonarqube.yml up -d"
fi

# Step 2: Pull Docker Image from Stage
echo "🐳 Step 2: Pulling Docker image from stage environment..."
docker pull ${DOCKER_USERNAME}/${IMAGE_NAME}:${STAGE_TAG}

# Step 3: Tag for production
echo "🏷️  Step 3: Tagging image for production..."
docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${STAGE_TAG} ${DOCKER_USERNAME}/${IMAGE_NAME}:${PROD_TAG}
docker tag ${DOCKER_USERNAME}/${IMAGE_NAME}:${STAGE_TAG} ${DOCKER_USERNAME}/${IMAGE_NAME}:prod-$(date +%Y%m%d-%H%M%S)

# Step 4: Push to DockerHub (optional - uncomment if needed)
# echo "📤 Step 4: Pushing production image to DockerHub..."
# docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:${PROD_TAG}
# docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:prod-$(date +%Y%m%d-%H%M%S)

# Step 5: Deploy to production
echo "🚀 Step 5: Deploying to production environment..."
docker-compose -f docker-compose.production.yml down 2>/dev/null || true
docker-compose -f docker-compose.production.yml up -d

# Step 6: Health check
echo "🏥 Step 6: Running health checks..."
sleep 10

for i in {1..6}; do
    if curl -f http://localhost:80/health 2>/dev/null; then
        echo "✅ Production deployment successful! Application is healthy."
        break
    else
        echo "⏳ Health check attempt $i/6 failed, retrying in 10 seconds..."
        sleep 10
    fi
    
    if [ $i -eq 6 ]; then
        echo "❌ Health check failed. Please check the application logs:"
        docker-compose -f docker-compose.production.yml logs --tail=50
        exit 1
    fi
done

echo "🎉 Production deployment completed successfully!"
echo "📱 Application is running at: http://localhost:80"
echo "🔍 Monitor logs with: docker-compose -f docker-compose.production.yml logs -f"
