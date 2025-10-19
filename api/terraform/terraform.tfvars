# Copy this file to terraform.tfvars and update the values

# AWS Configuration
aws_region = "us-west-2"

# Project Configuration
project_name = "ml-api"
environment  = "prod"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# Auto Scaling Configuration
min_capacity = 5
max_capacity = 20
cpu_target   = 70
memory_target = 80

# ECS Task Configuration
task_cpu    = 1024
task_memory = 2048

# Container Image (leave empty to use ECR repository)
container_image = ""

# Domain Configuration (optional)
domain_name     = ""
certificate_arn = ""
