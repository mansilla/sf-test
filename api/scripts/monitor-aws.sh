#!/bin/bash

# AWS ECS Monitoring Script for ML API
set -e

# Configuration
PROJECT_NAME="ml-api"
ENVIRONMENT="prod"
AWS_REGION="us-west-2"

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

log_metric() {
    echo -e "${BLUE}[METRIC]${NC} $1"
}

# Get service information
get_service_info() {
    log_info "Getting service information..."
    
    cd terraform
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    API_URL="http://${ALB_DNS}"
    cd ..
    
    if [ -n "$ALB_DNS" ]; then
        log_info "API URL: ${API_URL}"
        log_info "Health check: ${API_URL}/health"
        log_info "API docs: ${API_URL}/docs"
    else
        log_warn "Could not get ALB DNS name. Make sure Terraform has been applied."
    fi
}

# Check API health
check_api_health() {
    log_info "Checking API health..."
    
    cd terraform
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$ALB_DNS" ]; then
        log_error "Could not get ALB DNS name. Make sure infrastructure is deployed."
        return 1
    fi
    
    API_URL="http://${ALB_DNS}"
    
    if curl -f "${API_URL}/health" >/dev/null 2>&1; then
        log_info "✅ API is healthy"
        return 0
    else
        log_error "❌ API health check failed"
        return 1
    fi
}

# Get ECS service metrics
get_ecs_metrics() {
    log_info "Fetching ECS service metrics..."
    
    CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    
    # Get running task count
    RUNNING_TASKS=$(aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION} \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "N/A")
    
    # Get desired task count
    DESIRED_TASKS=$(aws ecs describe-services \
        --cluster ${CLUSTER_NAME} \
        --services ${SERVICE_NAME} \
        --region ${AWS_REGION} \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null || echo "N/A")
    
    log_metric "Running tasks: ${RUNNING_TASKS}"
    log_metric "Desired tasks: ${DESIRED_TASKS}"
    
    # Get CPU and Memory utilization
    START_TIME=$(date -u -v-5M +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)
    END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    CPU_UTIL=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name CPUUtilization \
        --dimensions Name=ServiceName,Value=${SERVICE_NAME} Name=ClusterName,Value=${CLUSTER_NAME} \
        --statistics Average \
        --start-time ${START_TIME} \
        --end-time ${END_TIME} \
        --period 300 \
        --region ${AWS_REGION} \
        --query 'Datapoints[0].Average' \
        --output text 2>/dev/null || echo "N/A")
    
    MEMORY_UTIL=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name MemoryUtilization \
        --dimensions Name=ServiceName,Value=${SERVICE_NAME} Name=ClusterName,Value=${CLUSTER_NAME} \
        --statistics Average \
        --start-time ${START_TIME} \
        --end-time ${END_TIME} \
        --period 300 \
        --region ${AWS_REGION} \
        --query 'Datapoints[0].Average' \
        --output text 2>/dev/null || echo "N/A")
    
    log_metric "CPU utilization: ${CPU_UTIL}%"
    log_metric "Memory utilization: ${MEMORY_UTIL}%"
}

# Get ALB metrics
get_alb_metrics() {
    log_info "Fetching ALB metrics..."
    
    cd terraform
    ALB_ARN=$(terraform output -raw alb_arn 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$ALB_ARN" ]; then
        log_warn "Could not get ALB ARN. Make sure Terraform has been applied."
        return
    fi
    
    # Get request count
    START_TIME=$(date -u -v-5M +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)
    END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
    
    REQUEST_COUNT=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name RequestCount \
        --dimensions Name=LoadBalancer,Value=${ALB_ARN} \
        --statistics Sum \
        --start-time ${START_TIME} \
        --end-time ${END_TIME} \
        --period 300 \
        --region ${AWS_REGION} \
        --query 'Datapoints[0].Sum' \
        --output text 2>/dev/null || echo "0")
    
    # Get response time
    RESPONSE_TIME=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/ApplicationELB \
        --metric-name TargetResponseTime \
        --dimensions Name=LoadBalancer,Value=${ALB_ARN} \
        --statistics Average \
        --start-time ${START_TIME} \
        --end-time ${END_TIME} \
        --period 300 \
        --region ${AWS_REGION} \
        --query 'Datapoints[0].Average' \
        --output text 2>/dev/null || echo "N/A")
    
    log_metric "Request count (last 5 min): ${REQUEST_COUNT}"
    log_metric "Average response time: ${RESPONSE_TIME}s"
}

# Test prediction endpoint
test_prediction() {
    log_info "Testing prediction endpoint..."
    
    cd terraform
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$ALB_DNS" ]; then
        log_error "Could not get ALB DNS name. Make sure infrastructure is deployed."
        return 1
    fi
    
    API_URL="http://${ALB_DNS}"
    
    # Sample prediction data
    PREDICTION_DATA='{
        "feat1": 55.0,
        "feat2": 2.0,
        "feat3": 6750.0,
        "feat4": 33.0,
        "feat5": 32.0,
        "feat6": 22.0,
        "feat7": 2.0,
        "feat8": 0.0,
        "feat9": 14.0,
        "feat10": 66.0,
        "feat11": 0.0,
        "feat12": 0.0,
        "feat13": 0.0,
        "feat14": 0.0,
        "feat15": 0.0,
        "feat16": 0.0,
        "feat17": 0.0,
        "feat18": 0.0,
        "feat19": 0.0,
        "feat20": 0.0,
        "feat21": 0.0,
        "feat22": 0.0,
        "feat23": 0.0,
        "feat24": 0.0,
        "feat25": 0.0,
        "feat26": 0.0,
        "feat27": 0.0,
        "feat28": 1.0,
        "feat29": 0.0,
        "feat30": 0.0,
        "feat31": 1.0,
        "feat32": 0.0,
        "feat33": 0.0,
        "feat34": 1.0,
        "feat35": 0.0,
        "feat36": 0.0
    }'
    
    # Test prediction
    RESPONSE=$(curl -s -X POST "${API_URL}/predict" \
        -H "Content-Type: application/json" \
        -d "${PREDICTION_DATA}")
    
    if echo "$RESPONSE" | grep -q "predicted_class"; then
        log_info "✅ Prediction test successful"
        echo "Response: $RESPONSE"
    else
        log_error "❌ Prediction test failed"
        echo "Response: $RESPONSE"
    fi
}

# Generate monitoring report
generate_report() {
    log_info "Generating monitoring report..."
    
    echo "=========================================="
    echo "ML API Monitoring Report"
    echo "=========================================="
    echo "Timestamp: $(date)"
    echo "Region: ${AWS_REGION}"
    echo "Project: ${PROJECT_NAME}-${ENVIRONMENT}"
    echo "=========================================="
    
    # Service info
    get_service_info
    echo "=========================================="
    
    # Health check
    if check_api_health; then
        echo "Status: ✅ HEALTHY"
    else
        echo "Status: ❌ UNHEALTHY"
    fi
    
    echo "=========================================="
    
    # Metrics
    get_ecs_metrics
    get_alb_metrics
    
    echo "=========================================="
}

# Main monitoring function
main() {
    case "${1:-report}" in
        "health")
            check_api_health
            ;;
        "test")
            test_prediction
            ;;
        "metrics")
            get_ecs_metrics
            get_alb_metrics
            ;;
        "report")
            generate_report
            ;;
        "info")
            get_service_info
            ;;
        *)
            log_error "Invalid option. Use: health, test, metrics, report, or info"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
