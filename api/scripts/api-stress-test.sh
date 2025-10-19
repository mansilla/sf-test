#!/bin/bash

# ML API Stress Testing Script
set -e

# Configuration
PROJECT_NAME="ml-api"
ENVIRONMENT="prod"
AWS_REGION="us-west-2"
REQUESTS_PER_SECOND=300
DURATION_SECONDS=60
CONCURRENT_USERS=12

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

# Get API URL
get_api_url() {
    log_info "Getting API URL..."
    
    cd terraform
    API_URL=$(terraform output -raw api_url 2>/dev/null || echo "")
    cd ..
    
    if [ -z "$API_URL" ]; then
        log_error "Could not get API URL. Make sure Terraform has been applied."
        exit 1
    fi
    
    log_info "API URL: ${API_URL}"
}

# Check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."
    
    command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed."; exit 1; }
    command -v jq >/dev/null 2>&1 || { log_warn "jq not found. JSON parsing will be limited."; }
    command -v bc >/dev/null 2>&1 || { log_error "bc is required for calculations."; exit 1; }
    
    log_info "Dependencies check completed."
}

# Generate sample prediction data
generate_test_data() {
    cat << 'EOF'
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
EOF
}

# Run single request and measure response time
make_request() {
    local url="$1"
    local data="$2"
    local output_file="$3"
    
    local start_time=$(date +%s.%N)
    local response=$(curl -s -w "%{http_code}" -X POST "${url}/predict" \
        -H "Content-Type: application/json" \
        -d "${data}" \
        -o "${output_file}" 2>/dev/null)
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "${duration},${response}"
}

# Run stress test
run_stress_test() {
    log_info "Starting stress test..."
    log_info "Target: ${REQUESTS_PER_SECOND} requests/second for ${DURATION_SECONDS} seconds"
    log_info "Concurrent users: ${CONCURRENT_USERS}"
    
    local api_url="$1"
    local test_data=$(generate_test_data)
    local results_file="/tmp/stress_test_results_$(date +%s).txt"
    local temp_dir="/tmp/stress_test_$(date +%s)"
    
    mkdir -p "$temp_dir"
    
    log_info "Running stress test..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION_SECONDS))
    local request_count=0
    local success_count=0
    local error_count=0
    local total_response_time=0
    
    # Create background processes for concurrent requests
    for ((i=1; i<=CONCURRENT_USERS; i++)); do
        (
            while [ $(date +%s) -lt $end_time ]; do
                local result=$(make_request "$api_url" "$test_data" "${temp_dir}/response_${i}_$(date +%s).json")
                echo "$result" >> "$results_file"
                
                # Rate limiting: sleep to achieve target RPS
                sleep $(echo "scale=6; 1 / $REQUESTS_PER_SECOND * $CONCURRENT_USERS" | bc)
            done
        ) &
    done
    
    # Wait for all background processes
    wait
    
    # Process results
    log_info "Processing results..."
    
    if [ -f "$results_file" ]; then
        while IFS=',' read -r duration status_code; do
            request_count=$((request_count + 1))
            
            if [ "$status_code" = "200" ]; then
                success_count=$((success_count + 1))
            else
                error_count=$((error_count + 1))
            fi
            
            total_response_time=$(echo "$total_response_time + $duration" | bc)
        done < "$results_file"
    fi
    
    # Calculate metrics
    local avg_response_time=0
    local success_rate=0
    local actual_rps=0
    
    if [ $request_count -gt 0 ]; then
        avg_response_time=$(echo "scale=4; $total_response_time / $request_count" | bc)
        success_rate=$(echo "scale=2; $success_count * 100 / $request_count" | bc)
        actual_rps=$(echo "scale=2; $request_count / $DURATION_SECONDS" | bc)
    fi
    
    # Display results
    echo "=========================================="
    echo "STRESS TEST RESULTS"
    echo "=========================================="
    echo "Test Duration: ${DURATION_SECONDS} seconds"
    echo "Target RPS: ${REQUESTS_PER_SECOND}"
    echo "Actual RPS: ${actual_rps}"
    echo "Total Requests: ${request_count}"
    echo "Successful Requests: ${success_count}"
    echo "Failed Requests: ${error_count}"
    echo "Success Rate: ${success_rate}%"
    echo "Average Response Time: ${avg_response_time}s"
    echo "=========================================="
    
    # Performance analysis
    if (( $(echo "$avg_response_time < 1.0" | bc -l) )); then
        log_info "✅ Excellent response time (< 1s)"
    elif (( $(echo "$avg_response_time < 2.0" | bc -l) )); then
        log_info "✅ Good response time (< 2s)"
    elif (( $(echo "$avg_response_time < 5.0" | bc -l) )); then
        log_warn "⚠️  Acceptable response time (< 5s)"
    else
        log_error "❌ Poor response time (> 5s)"
    fi
    
    if (( $(echo "$success_rate >= 95" | bc -l) )); then
        log_info "✅ Excellent success rate (>= 95%)"
    elif (( $(echo "$success_rate >= 90" | bc -l) )); then
        log_warn "⚠️  Good success rate (>= 90%)"
    else
        log_error "❌ Poor success rate (< 90%)"
    fi
    
    # Cleanup
    rm -f "$results_file"
    rm -rf "$temp_dir"
}

# Run quick health check
health_check() {
    log_info "Running health check..."
    
    local api_url="$1"
    local response=$(curl -s -w "%{http_code}" -o /dev/null "${api_url}/health")
    
    if [ "$response" = "200" ]; then
        log_info "✅ API is healthy"
        return 0
    else
        log_error "❌ API health check failed (HTTP $response)"
        return 1
    fi
}

# Run single request test
single_request_test() {
    log_info "Running single request test..."
    
    local api_url="$1"
    local test_data=$(generate_test_data)
    local temp_file="/tmp/single_test_$(date +%s).json"
    
    local result=$(make_request "$api_url" "$test_data" "$temp_file")
    local duration=$(echo "$result" | cut -d',' -f1)
    local status_code=$(echo "$result" | cut -d',' -f2)
    
    log_metric "Response time: ${duration}s"
    log_metric "Status code: ${status_code}"
    
    if [ "$status_code" = "200" ]; then
        log_info "✅ Single request successful"
        if [ -f "$temp_file" ] && command -v jq >/dev/null 2>&1; then
            local predicted_class=$(jq -r '.predicted_class' "$temp_file" 2>/dev/null || echo "N/A")
            local confidence=$(jq -r '.confidence' "$temp_file" 2>/dev/null || echo "N/A")
            log_metric "Predicted class: ${predicted_class}"
            log_metric "Confidence: ${confidence}"
        fi
    else
        log_error "❌ Single request failed"
    fi
    
    rm -f "$temp_file"
}

# Main function
main() {
    case "${1:-stress}" in
        "health")
            get_api_url
            health_check "$API_URL"
            ;;
        "single")
            get_api_url
            health_check "$API_URL" && single_request_test "$API_URL"
            ;;
        "stress")
            get_api_url
            health_check "$API_URL" && run_stress_test "$API_URL"
            ;;
        "quick")
            # Quick test with lower load
            REQUESTS_PER_SECOND=10
            DURATION_SECONDS=10
            CONCURRENT_USERS=5
            get_api_url
            health_check "$API_URL" && run_stress_test "$API_URL"
            ;;
        *)
            log_error "Invalid option. Use: health, single, stress, or quick"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
