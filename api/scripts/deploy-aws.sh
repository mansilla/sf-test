#!/bin/bash

# AWS ECS Deployment Script for ML API
set -e

# Configuration
PROJECT_NAME="ml-api"
ENVIRONMENT="prod"
AWS_REGION="us-west-2"
IMAGE_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    log_step "Checking dependencies..."
    
    command -v aws >/dev/null 2>&1 || { log_error "AWS CLI is required but not installed."; exit 1; }
    command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed."; exit 1; }
    command -v terraform >/dev/null 2>&1 || { log_error "Terraform is required but not installed."; exit 1; }
    
    log_info "Dependencies check completed."
}

# Get AWS account ID and region
get_aws_info() {
    log_step "Getting AWS information..."
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-${ENVIRONMENT}"
    
    log_info "AWS Account ID: ${ACCOUNT_ID}"
    log_info "AWS Region: ${AWS_REGION}"
    log_info "ECR URI: ${ECR_URI}"
}

# Build and push Docker image
build_and_push_image() {
    log_step "Building and pushing Docker image..."
    
    # Login to ECR
    log_info "Logging in to ECR..."
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}
    
    # Build image
    log_info "Building Docker image..."
    docker build -t ${PROJECT_NAME}:${IMAGE_TAG} -f docker/Dockerfile ..
    
    # Tag for ECR
    docker tag ${PROJECT_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
    
    # Push to ECR
    log_info "Pushing image to ECR..."
    docker push ${ECR_URI}:${IMAGE_TAG}
    
    log_info "Image pushed to ECR: ${ECR_URI}:${IMAGE_TAG}"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_step "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f "terraform.tfvars" ]; then
        log_warn "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        log_warn "Please update terraform.tfvars with your values before continuing."
        exit 1
    fi
    
    # Plan deployment
    log_info "Planning Terraform deployment..."
    terraform plan -var="container_image=${ECR_URI}:${IMAGE_TAG}"
    
    # Apply deployment
    log_info "Applying Terraform deployment..."
    terraform apply -auto-approve -var="container_image=${ECR_URI}:${IMAGE_TAG}"
    
    cd ..
    
    log_info "Infrastructure deployment completed."
}

# Update ECS service
update_ecs_service() {
    log_step "Updating ECS service..."
    
    CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    
    # Force new deployment
    aws ecs update-service \
        --cluster ${CLUSTER_NAME} \
        --service ${SERVICE_NAME} \
        --force-new-deployment \
        --region ${AWS_REGION}
    
    log_info "ECS service update initiated."
}

# Wait for deployment to complete
wait_for_deployment() {
    log_step "Waiting for deployment to complete..."
    
    CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    
    log_info "Waiting for service to stabilize..."
    aws ecs wait services-stable \
        --cluster ${CLUSTER_NAME} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION}
    
    log_info "Deployment completed successfully!"
}

# Get service information
get_service_info() {
    log_step "Getting service information..."
    
    cd terraform
    
    # Get ALB DNS name
    ALB_DNS=$(terraform output -raw alb_dns_name)
    API_URL="http://${ALB_DNS}"
    
    log_info "API URL: ${API_URL}"
    log_info "Health check: ${API_URL}/health"
    log_info "API docs: ${API_URL}/docs"
    
    cd ..
}

# Run health check
health_check() {
    log_step "Running health check..."
    
    cd terraform
    ALB_DNS=$(terraform output -raw alb_dns_name)
    cd ..
    
    API_URL="http://${ALB_DNS}"
    
    # Wait a bit for the service to be ready
    sleep 30
    
    # Check health endpoint
    if curl -f "${API_URL}/health" >/dev/null 2>&1; then
        log_info "✅ Health check passed!"
        log_info "API is ready at: ${API_URL}"
    else
        log_error "❌ Health check failed!"
        log_error "Please check the service logs and try again."
        exit 1
    fi
}

# Clean up old images
cleanup_old_images() {
    log_step "Cleaning up old ECR images..."
    
    # Keep only the last 5 images
    aws ecr list-images \
        --repository-name ${PROJECT_NAME}-${ENVIRONMENT} \
        --region ${AWS_REGION} \
        --query 'imageIds[?imageTag!=`latest`]' \
        --output json | \
    jq '.[] | select(.imageTag != null) | .imageTag' | \
    head -n -5 | \
    xargs -I {} aws ecr batch-delete-image \
        --repository-name ${PROJECT_NAME}-${ENVIRONMENT} \
        --image-ids imageTag={} \
        --region ${AWS_REGION} 2>/dev/null || true
    
    log_info "Old images cleaned up."
}

# Main deployment function
main() {
    case "${1:-deploy}" in
        "deploy")
            log_info "Starting full deployment..."
            check_dependencies
            get_aws_info
            deploy_infrastructure
            build_and_push_image
            wait_for_deployment
            get_service_info
            health_check
            cleanup_old_images
            log_info "🎉 Deployment completed successfully!"
            ;;
        "update")
            log_info "Updating existing deployment..."
            check_dependencies
            get_aws_info
            build_and_push_image
            update_ecs_service
            wait_for_deployment
            get_service_info
            health_check
            log_info "🎉 Update completed successfully!"
            ;;
        "destroy")
            log_warn "Destroying infrastructure..."
            cd terraform
            terraform destroy -auto-approve
            cd ..
            log_info "Infrastructure destroyed."
            ;;
        "status")
            log_info "Checking deployment status..."
            get_service_info
            health_check
            ;;
        *)
            log_error "Invalid option. Use: deploy, update, destroy, or status"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
