# XGBoost Prediction API

A production-ready FastAPI application for predicting using a trained XGBoost model, deployed on AWS ECS with auto-scaling, monitoring, and security features.

The API is runnig here:
```
http://ml-api-prod-429710726.us-west-2.elb.amazonaws.com/docs
```

## 🚀 Features

- ✅ **FastAPI** with automatic API documentation
- ✅ **XGBoost model** integration with feature scaling
- ✅ **AWS ECS deployment** with Fargate
- ✅ **Auto-scaling** (5-20 tasks based on load)
- ✅ **Load balancing** with Application Load Balancer
- ✅ **Monitoring** with CloudWatch metrics
- ✅ **Security** with WAF and rate limiting
- ✅ **Health checks** and error handling
- ✅ **Stress testing** capabilities
- ✅ **Prometheus metrics** collection and alerting
- ✅ **Grafana dashboards** for visualization
- ✅ **Local development** with Docker Compose

## 🏗️ Infrastructure Architecture

### AWS Components
- **ECS Fargate**: Serverless container orchestration
- **Application Load Balancer**: Layer 7 load balancing
- **ECR**: Container image registry
- **VPC**: Isolated network with public/private subnets
- **CloudWatch**: Monitoring and logging
- **WAF**: Web Application Firewall with rate limiting
- **Auto Scaling**: CPU and memory-based scaling

### Performance Specifications
- **CPU**: 1024 units per task
- **Memory**: 2048 MB per task
- **Workers**: 4 uvicorn workers per task
- **Min Tasks**: 5
- **Max Tasks**: 20
- **Target RPS**: 300+ requests/second

### Local Development Stack
- **FastAPI**: Application server with metrics endpoint
- **Nginx**: Load balancer with status monitoring
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notifications
- **Node Exporter**: System metrics collection
- **Nginx Exporter**: Web server metrics

## 📁 Project Structure

```
api/
├── app.py                          # FastAPI application
├── requirements.txt                # Python dependencies
├── docker/
│   ├── Dockerfile                  # Multi-stage Docker build
│   ├── docker-compose.yml          # Local development stack
│   ├── nginx.conf                  # Nginx configuration
│   └── alertmanager.yml            # Alertmanager configuration
├── terraform/
│   ├── main.tf                    # Infrastructure definition
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   └── terraform.tfvars           # Configuration values
├── scripts/
│   ├── deploy-aws.sh              # Deployment automation
│   ├── monitor-aws.sh              # Monitoring and health checks
│   └── api-stress-test.sh          # Performance testing
└── monitoring/
    ├── prometheus.yml              # Prometheus configuration
    └── alert_rules.yml             # Alert rules
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Docker installed
- Terraform installed
- Bash shell

### 1. Deploy Infrastructure
```bash
cd api
./scripts/deploy-aws.sh deploy
```

### 2. Monitor Deployment
```bash
./scripts/monitor-aws.sh report
```

### 3. Test API
```bash
./scripts/api-stress-test.sh single
```

## 🐳 Local Development with Docker

### Prerequisites
- Docker and Docker Compose installed
- No AWS setup required for local development

### 1. Start Local Development Stack
```bash
cd api/docker
docker-compose up -d
```

### 2. Access Services
- **API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Grafana**: http://localhost/grafana (admin/admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

### 3. Test Local API
```bash
# Health check
curl http://localhost:8000/health

# Make prediction
curl -X POST "http://localhost:8000/predict" \
     -H "Content-Type: application/json" \
     -d '{"feat1": 55.0, "feat2": 2.0, "feat3": 6750.0, ...}'
```

### 4. Monitor with Grafana
1. Open http://localhost/grafana
2. Login with admin/admin
3. Add Prometheus data source: http://prometheus:9090
4. Import dashboards or create custom ones

### 5. Stop Local Stack
```bash
docker-compose down
```

## 📋 Deployment Instructions

### Full Deployment
```bash
# Deploy everything (infrastructure + application)
./scripts/deploy-aws.sh deploy
```

### Update Application Only
```bash
# Update just the application code
./scripts/deploy-aws.sh update
```

### Infrastructure Only
```bash
# Deploy just the infrastructure
cd terraform
terraform apply
```

## 🔧 Configuration

### Environment Variables
Create `terraform/terraform.tfvars`:
```hcl
# Project Configuration
project_name = "ml-api"
environment  = "prod"
aws_region   = "us-west-2"

# Auto Scaling Configuration
min_capacity = 5
max_capacity = 20
cpu_target   = 70
memory_target = 80

# ECS Task Configuration
task_cpu    = 1024
task_memory = 2048
```

### Docker Configuration
The application uses a multi-stage Dockerfile for optimization:
- **Base Image**: Python 3.9-slim
- **Architecture**: linux/amd64
- **Security**: Non-root user
- **Workers**: 4 uvicorn workers
- **Health Checks**: Built-in health monitoring

## 📊 Monitoring & Scripts

### Monitoring Script
```bash
# Generate comprehensive report
./scripts/monitor-aws.sh report

# Check health only
./scripts/monitor-aws.sh health

# Get service info
./scripts/monitor-aws.sh service
```

### Stress Testing Script
```bash
# Quick test (10 RPS for 10 seconds)
./scripts/api-stress-test.sh quick

# Single request test
./scripts/api-stress-test.sh single

# Full stress test (300 RPS for 60 seconds)
./scripts/api-stress-test.sh stress

# Health check only
./scripts/api-stress-test.sh health
```

### Deployment Script
```bash
# Full deployment
./scripts/deploy-aws.sh deploy

# Update existing deployment
./scripts/deploy-aws.sh update

# Cleanup resources
./scripts/deploy-aws.sh destroy
```

## 🌐 API Endpoints

### Production URLs
- **API**: `http://ml-api-prod-429710726.us-west-2.elb.amazonaws.com`
- **Health Check**: `http://ml-api-prod-429710726.us-west-2.elb.amazonaws.com/health`
- **API Docs**: `http://ml-api-prod-429710726.us-west-2.elb.amazonaws.com/docs`
- **Grafana**: `http://ml-api-prod-429710726.us-west-2.elb.amazonaws.com/grafana` (admin/admin)

### Available Endpoints

#### 1. Health Check
```http
GET /health
```
Returns the health status of the API and model components.

#### 2. Metrics Endpoint
```http
GET /metrics
```
Returns Prometheus metrics for monitoring and alerting.

#### 3. Prediction Endpoint
```http
POST /predict
```
Predicts with toy model based on input features.

**Input Format:**
```json
{
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
}
```

**Output Format:**
```json
{
  "predicted_class": 3,
  "confidence": 0.85,
  "model_version": "1.0.0",
  "features_used": 36
}
```

## 🧪 Testing

### Local Development
```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
python app.py
```

### Production Testing
```bash
# Test single request
curl -X POST "http://ml-api-prod-429710726.us-west-2.elb.amazonaws.com/predict" \
     -H "Content-Type: application/json" \
     -d '{"feat1": 55.0, "feat2": 2.0, ...}'
```

### Performance Testing
```bash
# Run stress test
./scripts/api-stress-test.sh stress

# Expected results:
# - Target: 300 RPS
# - Success Rate: >90%
# - Response Time: <1s
```

## 📈 Performance Optimization

### Current Optimizations
- **Multi-worker setup**: 4 uvicorn workers per task
- **Thread pool**: CPU-intensive operations in separate threads
- **Auto-scaling**: 5-20 tasks based on load
- **Resource allocation**: 1024 CPU, 2048 MB memory per task
- **Load balancing**: ALB with health checks

### Performance Targets
- **Throughput**: 300+ requests/second
- **Response Time**: <1 second average
- **Success Rate**: >95%
- **Availability**: 99.9%

## 🔒 Security Features

- **WAF Protection**: Rate limiting and DDoS protection
- **VPC Isolation**: Private subnets for containers
- **IAM Roles**: Least privilege access
- **Non-root containers**: Enhanced security
- **HTTPS**: SSL/TLS termination at ALB
- **Security Groups**: Restricted network access

## 🛠️ Troubleshooting

### Common Issues

#### 1. Model Loading Errors
```bash
# Check container logs
./scripts/monitor-aws.sh logs
```

#### 2. Performance Issues
```bash
# Run stress test
./scripts/api-stress-test.sh stress

# Check metrics
./scripts/monitor-aws.sh report
```

#### 3. Deployment Issues
```bash
# Check deployment status
./scripts/deploy-aws.sh status

# View logs
./scripts/monitor-aws.sh logs
```

### Log Locations
- **Application Logs**: CloudWatch Logs `/ecs/ml-api-prod`
- **ALB Logs**: S3 bucket (if enabled)
- **ECS Logs**: CloudWatch Logs

## 💰 Cost Optimization

### Current Configuration
- **Fargate**: Pay-per-use pricing
- **ALB**: Fixed cost + data processing
- **ECR**: Storage costs for images
- **CloudWatch**: Log and metric costs

### Cost Optimization Tips
- **Right-sizing**: Monitor CPU/memory usage
- **Auto-scaling**: Scale down during low usage
- **Log retention**: Set appropriate log retention periods
- **Image cleanup**: Regular ECR image cleanup

## 🔄 Maintenance

### Regular Tasks
```bash
# Update application
./scripts/deploy-aws.sh update

# Monitor performance
./scripts/monitor-aws.sh report

# Clean up old images
./scripts/deploy-aws.sh cleanup
```

### Scaling Operations
```bash
# Scale up manually (if needed)
aws ecs update-service --cluster ml-api-prod --service ml-api-prod --desired-count 10

# Scale down
aws ecs update-service --cluster ml-api-prod --service ml-api-prod --desired-count 5
```
