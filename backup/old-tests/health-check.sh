#!/bin/bash

# ===================================
# Sentinel AK-XL Virtual SOC Health Check Script
# ===================================
# This script monitors the health of all Virtual SOC services
# Use this to verify system status and troubleshoot issues
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="sentinel-ak-xl"
LOG_FILE="data/logs/health.log"
TIMEOUT=10
MAX_RETRIES=3

# Health check results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# ===================================
# Utility Functions
# ===================================

print_banner() {
    echo -e "${GREEN}"
    cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
            🏥 HEALTH CHECK MONITOR 🏥
              Virtual SOC System Status
EOF
    echo -e "${NC}"
}

log() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $message" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $message" >> "$LOG_FILE" 2>/dev/null || true
    ((WARNING_CHECKS++))
}

error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >> "$LOG_FILE" 2>/dev/null || true
    ((FAILED_CHECKS++))
}

success() {
    local message="$1"
    echo -e "${GREEN}[OK]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK: $message" >> "$LOG_FILE" 2>/dev/null || true
    ((PASSED_CHECKS++))
}

step() {
    echo -e "${BLUE}[CHECK]${NC} $1"
    ((TOTAL_CHECKS++))
}

# ===================================
# Docker Environment Checks
# ===================================

check_docker() {
    step "Checking Docker daemon..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        return 1
    fi
    
    local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    success "Docker is running (version $docker_version)"
}

check_docker_compose() {
    step "Checking Docker Compose..."
    
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        local compose_version=$(docker compose version --short 2>/dev/null || echo "unknown")
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    else
        error "Docker Compose is not available"
        return 1
    fi
    
    success "Docker Compose is available (version $compose_version)"
    export COMPOSE_CMD
}

check_compose_file() {
    step "Checking docker-compose.yml..."
    
    if [[ ! -f docker-compose.yml ]]; then
        error "docker-compose.yml not found"
        return 1
    fi
    
    if ! $COMPOSE_CMD config &> /dev/null; then
        error "docker-compose.yml has syntax errors"
        return 1
    fi
    
    success "docker-compose.yml is valid"
}

# ===================================
# Container Health Checks
# ===================================

check_containers() {
    step "Checking container status..."
    
    local containers=(
        "sentinel-elasticsearch:Elasticsearch"
        "sentinel-kibana:Kibana"
        "sentinel-logstash:Logstash"
        "sentinel-wazuh-manager:Wazuh Manager"
        "sentinel-wazuh-dashboard:Wazuh Dashboard"
        "sentinel-thehive:TheHive"
        "sentinel-thehive-db:TheHive Database"
        "sentinel-cortex:Cortex"
        "sentinel-shuffle-backend:Shuffle Backend"
        "sentinel-shuffle-frontend:Shuffle Frontend"
        "sentinel-linux-agent:Linux Agent"
        "sentinel-windows-agent:Windows Agent"
        "sentinel-network-simulator:Network Simulator"
    )
    
    local running_containers=$(docker ps --format "{{.Names}}" 2>/dev/null || true)
    
    for container_info in "${containers[@]}"; do
        IFS=':' read -r container_name display_name <<< "$container_info"
        
        if echo "$running_containers" | grep -q "^$container_name$"; then
            local status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
            local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null | xargs -I {} date -d {} +%s 2>/dev/null || echo "0")
            local current_time=$(date +%s)
            local uptime_minutes=$(( (current_time - uptime) / 60 ))
            
            case "$status" in
                "healthy")
                    success "$display_name is healthy (up ${uptime_minutes}m)"
                    ;;
                "unhealthy")
                    error "$display_name is unhealthy (up ${uptime_minutes}m)"
                    ;;
                "starting")
                    warn "$display_name is starting (up ${uptime_minutes}m)"
                    ;;
                "no-healthcheck")
                    if [[ $uptime_minutes -gt 2 ]]; then
                        success "$display_name is running (up ${uptime_minutes}m)"
                    else
                        warn "$display_name is starting (up ${uptime_minutes}m)"
                    fi
                    ;;
                *)
                    warn "$display_name status unknown"
                    ;;
            esac
        else
            error "$display_name is not running"
        fi
    done
}

# ===================================
# Service Endpoint Health Checks
# ===================================

check_http_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local auth="${4:-}"
    
    local curl_opts="-s -w %{http_code} -o /dev/null --connect-timeout $TIMEOUT"
    
    if [[ -n "$auth" ]]; then
        curl_opts="$curl_opts -u $auth"
    fi
    
    local http_status
    http_status=$(curl $curl_opts "$url" 2>/dev/null || echo "000")
    
    if [[ "$http_status" == "$expected_status" ]]; then
        success "$name endpoint is responding ($url)"
        return 0
    else
        error "$name endpoint failed (HTTP $http_status) ($url)"
        return 1
    fi
}

check_service_endpoints() {
    step "Checking service endpoints..."
    
    # Load environment variables
    if [[ -f .env ]]; then
        source .env
    fi
    
    local elastic_auth="elastic:${ELASTIC_PASSWORD:-changeme123!}"
    
    # Elasticsearch
    check_http_endpoint "Elasticsearch" "http://localhost:${ELASTICSEARCH_PORT:-9200}/_cluster/health" "200" "$elastic_auth"
    
    # Kibana
    check_http_endpoint "Kibana" "http://localhost:${KIBANA_PORT:-5601}/api/status" "200"
    
    # TheHive
    check_http_endpoint "TheHive" "http://localhost:${THEHIVE_PORT:-9000}/api/v1/status" "200"
    
    # Cortex
    check_http_endpoint "Cortex" "http://localhost:${CORTEX_PORT:-9001}/api/analyzer" "200"
    
    # Shuffle
    check_http_endpoint "Shuffle" "http://localhost:${SHUFFLE_PORT:-3001}/api/v1/workflows" "200"
    
    # Wazuh Manager API
    check_http_endpoint "Wazuh API" "https://localhost:${WAZUH_API_PORT:-55000}" "401"  # 401 expected without auth
    
    # Wazuh Dashboard
    check_http_endpoint "Wazuh Dashboard" "https://localhost:443" "200"
}

# ===================================
# Resource Usage Checks
# ===================================

check_system_resources() {
    step "Checking system resources..."
    
    # Memory usage
    if command -v free &> /dev/null; then
        local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        if (( $(echo "$mem_usage > 80" | bc -l) )); then
            warn "High memory usage: ${mem_usage}%"
        else
            success "Memory usage: ${mem_usage}%"
        fi
    fi
    
    # Disk usage
    local disk_usage=$(df . | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 80 ]]; then
        warn "High disk usage: ${disk_usage}%"
    else
        success "Disk usage: ${disk_usage}%"
    fi
    
    # Load average (Linux/macOS)
    if command -v uptime &> /dev/null; then
        local load_avg=$(uptime | awk '{print $(NF-2)}' | sed 's/,//')
        success "System load: $load_avg"
    fi
}

check_docker_resources() {
    step "Checking Docker resource usage..."
    
    # Docker system info
    local docker_info=$(docker system df --format "table {{.Type}}\t{{.TotalCount}}\t{{.Size}}" 2>/dev/null || true)
    
    if [[ -n "$docker_info" ]]; then
        echo -e "${CYAN}Docker Resource Usage:${NC}"
        echo "$docker_info"
    fi
    
    # Container resource usage
    local container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -10 || true)
    
    if [[ -n "$container_stats" ]]; then
        echo -e "${CYAN}Top Container Resource Usage:${NC}"
        echo "$container_stats"
    fi
    
    success "Docker resources checked"
}

# ===================================
# Data Integrity Checks
# ===================================

check_data_directories() {
    step "Checking data directory integrity..."
    
    local critical_dirs=(
        "data/elasticsearch"
        "data/wazuh"
        "data/thehive"
        "data/logs"
    )
    
    for dir in "${critical_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
            success "$dir exists (size: $size)"
        else
            warn "$dir does not exist"
        fi
    done
    
    # Check log file rotation
    if [[ -d "data/logs" ]]; then
        local log_count=$(find data/logs -name "*.log" -type f | wc -l)
        if [[ $log_count -gt 100 ]]; then
            warn "Many log files found ($log_count) - consider rotation"
        else
            success "Log files: $log_count"
        fi
    fi
}

check_elasticsearch_indices() {
    step "Checking Elasticsearch indices..."
    
    if [[ -f .env ]]; then
        source .env
    fi
    
    local elastic_auth="elastic:${ELASTIC_PASSWORD:-changeme123!}"
    local es_url="http://localhost:${ELASTICSEARCH_PORT:-9200}"
    
    # Check cluster health
    local cluster_health=$(curl -s -u "$elastic_auth" "$es_url/_cluster/health" 2>/dev/null || echo '{"status":"red"}')
    local status=$(echo "$cluster_health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    case "$status" in
        "green")
            success "Elasticsearch cluster is healthy"
            ;;
        "yellow")
            warn "Elasticsearch cluster status is yellow"
            ;;
        "red")
            error "Elasticsearch cluster status is red"
            ;;
        *)
            error "Cannot determine Elasticsearch cluster status"
            ;;
    esac
    
    # Check indices
    local indices=$(curl -s -u "$elastic_auth" "$es_url/_cat/indices?h=index,status,health,docs.count" 2>/dev/null || true)
    if [[ -n "$indices" ]]; then
        echo -e "${CYAN}Elasticsearch Indices:${NC}"
        echo "Index                    Status  Health  Docs"
        echo "$indices"
    fi
}

# ===================================
# Network Connectivity Checks
# ===================================

check_network_connectivity() {
    step "Checking network connectivity..."
    
    # Check if containers can communicate
    local test_containers=(
        "sentinel-elasticsearch"
        "sentinel-kibana"
        "sentinel-thehive"
    )
    
    for container in "${test_containers[@]}"; do
        if docker exec "$container" ping -c 1 sentinel-elasticsearch &>/dev/null; then
            success "$container can reach Elasticsearch"
        else
            warn "$container cannot reach Elasticsearch"
        fi
    done
    
    # Check external connectivity (for updates)
    if curl -s --connect-timeout 5 https://docker.io &>/dev/null; then
        success "External connectivity available"
    else
        warn "External connectivity issues detected"
    fi
}

check_port_availability() {
    step "Checking port availability..."
    
    local ports=(
        "5601:Kibana"
        "9200:Elasticsearch"
        "9000:TheHive"
        "9001:Cortex"
        "3001:Shuffle"
        "55000:Wazuh API"
        "443:Wazuh Dashboard"
    )
    
    for port_info in "${ports[@]}"; do
        IFS=':' read -r port service <<< "$port_info"
        
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            success "$service port $port is listening"
        else
            error "$service port $port is not listening"
        fi
    done
}

# ===================================
# Configuration Validation
# ===================================

check_configuration_files() {
    step "Checking configuration files..."
    
    local config_files=(
        ".env:Environment configuration"
        "docker-compose.yml:Docker Compose configuration"
        "configs/elk/elasticsearch/elasticsearch.yml:Elasticsearch config"
        "configs/elk/kibana/kibana.yml:Kibana config"
        "configs/elk/logstash/logstash.yml:Logstash config"
        "configs/wazuh/ossec.conf:Wazuh config"
        "configs/thehive/application.conf:TheHive config"
        "configs/cortex/application.conf:Cortex config"
    )
    
    for file_info in "${config_files[@]}"; do
        IFS=':' read -r file_path description <<< "$file_info"
        
        if [[ -f "$file_path" ]]; then
            local size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
            if [[ $size -gt 0 ]]; then
                success "$description exists (${size} bytes)"
            else
                warn "$description is empty"
            fi
        else
            error "$description is missing ($file_path)"
        fi
    done
}

check_environment_variables() {
    step "Checking environment variables..."
    
    if [[ -f .env ]]; then
        source .env
        
        local required_vars=(
            "ELASTIC_PASSWORD"
            "THEHIVE_SECRET"
            "CORTEX_SECRET"
        )
        
        for var in "${required_vars[@]}"; do
            if [[ -n "${!var}" ]]; then
                if [[ "${!var}" == "changeme"* ]]; then
                    warn "$var is using default value (security risk)"
                else
                    success "$var is configured"
                fi
            else
                error "$var is not set"
            fi
        done
    else
        error ".env file not found"
    fi
}

# ===================================
# Security Checks
# ===================================

check_security_configuration() {
    step "Checking security configuration..."
    
    # Check for default passwords
    if [[ -f .env ]]; then
        source .env
        
        if [[ "${ELASTIC_PASSWORD:-}" == "changeme123!" ]]; then
            warn "Elasticsearch is using default password"
        fi
        
        if [[ "${THEHIVE_SECRET:-}" == "changeme-secret-key-here" ]]; then
            warn "TheHive is using default secret key"
        fi
    fi
    
    # Check file permissions
    local sensitive_files=(".env" "configs/")
    
    for file in "${sensitive_files[@]}"; do
        if [[ -e "$file" ]]; then
            local perms=$(stat -f%A "$file" 2>/dev/null || stat -c%a "$file" 2>/dev/null || echo "unknown")
            if [[ "$perms" == "600" ]] || [[ "$perms" == "644" ]] || [[ "$perms" == "755" ]]; then
                success "$file has appropriate permissions ($perms)"
            else
                warn "$file has unusual permissions ($perms)"
            fi
        fi
    done
}

# ===================================
# Performance Checks
# ===================================

check_performance_metrics() {
    step "Checking performance metrics..."
    
    # Elasticsearch performance
    if [[ -f .env ]]; then
        source .env
        local elastic_auth="elastic:${ELASTIC_PASSWORD:-changeme123!}"
        local es_url="http://localhost:${ELASTICSEARCH_PORT:-9200}"
        
        # Check response time
        local start_time=$(date +%s%N)
        curl -s -u "$elastic_auth" "$es_url/_cluster/health" &>/dev/null
        local end_time=$(date +%s%N)
        local response_time=$(((end_time - start_time) / 1000000))
        
        if [[ $response_time -lt 1000 ]]; then
            success "Elasticsearch response time: ${response_time}ms"
        elif [[ $response_time -lt 5000 ]]; then
            warn "Elasticsearch response time: ${response_time}ms (slow)"
        else
            error "Elasticsearch response time: ${response_time}ms (very slow)"
        fi
    fi
    
    # Check for stuck processes
    local stuck_containers=$(docker ps --filter "status=restarting" --format "{{.Names}}" 2>/dev/null || true)
    if [[ -n "$stuck_containers" ]]; then
        error "Containers stuck restarting: $stuck_containers"
    else
        success "No containers stuck restarting"
    fi
}

# ===================================
# Scenario and Training Checks
# ===================================

check_training_environment() {
    step "Checking training environment..."
    
    # Check scenario directories
    local scenario_dirs=("scenarios/basic" "scenarios/intermediate" "scenarios/advanced")
    
    for dir in "${scenario_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local scenario_count=$(find "$dir" -name "*.json" -type f | wc -l)
            success "$dir has $scenario_count scenarios"
        else
            warn "$dir does not exist"
        fi
    done
    
    # Check agent containers
    local agents=("sentinel-linux-agent" "sentinel-windows-agent" "sentinel-network-simulator")
    
    for agent in "${agents[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^$agent$"; then
            success "$agent is running"
        else
            warn "$agent is not running"
        fi
    done
}

# ===================================
# Report Generation
# ===================================

generate_health_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="data/logs/health_report_$(date +%Y%m%d_%H%M%S).txt"
    
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "Sentinel AK-XL Virtual SOC Health Report"
        echo "Generated: $timestamp"
        echo "======================================="
        echo ""
        echo "Summary:"
        echo "  Total Checks: $TOTAL_CHECKS"
        echo "  Passed: $PASSED_CHECKS"
        echo "  Warnings: $WARNING_CHECKS"
        echo "  Failed: $FAILED_CHECKS"
        echo ""
        echo "Overall Status: $(get_overall_status)"
        echo ""
        echo "Detailed Results:"
        echo "=================="
        tail -50 "$LOG_FILE" 2>/dev/null || echo "No detailed logs available"
    } > "$report_file"
    
    log "Health report saved to: $report_file"
}

get_overall_status() {
    local failure_rate=$((FAILED_CHECKS * 100 / TOTAL_CHECKS))
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        if [[ $WARNING_CHECKS -eq 0 ]]; then
            echo "HEALTHY"
        else
            echo "HEALTHY (with warnings)"
        fi
    elif [[ $failure_rate -lt 20 ]]; then
        echo "DEGRADED"
    else
        echo "UNHEALTHY"
    fi
}

show_summary() {
    echo ""
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${CYAN}Health Check Summary${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo -e "Total Checks: ${BLUE}$TOTAL_CHECKS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
    echo ""
    
    local overall_status=$(get_overall_status)
    case "$overall_status" in
        "HEALTHY")
            echo -e "Overall Status: ${GREEN}$overall_status${NC} ✅"
            ;;
        "HEALTHY (with warnings)")
            echo -e "Overall Status: ${YELLOW}$overall_status${NC} ⚠️"
            ;;
        "DEGRADED")
            echo -e "Overall Status: ${YELLOW}$overall_status${NC} ⚠️"
            ;;
        "UNHEALTHY")
            echo -e "Overall Status: ${RED}$overall_status${NC} ❌"
            ;;
    esac
    echo ""
}

# ===================================
# Main Health Check Function
# ===================================

run_all_checks() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    log "Starting comprehensive health check..."
    
    # System and Docker checks
    check_docker
    check_docker_compose
    check_compose_file
    
    # Container and service checks
    check_containers
    check_service_endpoints
    
    # Resource checks
    check_system_resources
    check_docker_resources
    
    # Data and configuration checks
    check_data_directories
    check_elasticsearch_indices
    check_configuration_files
    check_environment_variables
    
    # Network checks
    check_network_connectivity
    check_port_availability
    
    # Security checks
    check_security_configuration
    
    # Performance checks
    check_performance_metrics
    
    # Training environment checks
    check_training_environment
    
    log "Health check completed"
}

# ===================================
# Monitoring Mode
# ===================================

monitoring_mode() {
    local interval=${1:-30}
    
    log "Starting continuous monitoring (interval: ${interval}s)"
    log "Press Ctrl+C to stop"
    
    while true; do
        clear
        print_banner
        echo -e "${BLUE}Continuous Monitoring Mode - $(date)${NC}"
        echo -e "${BLUE}Press Ctrl+C to exit${NC}\n"
        
        run_all_checks
        show_summary
        
        sleep "$interval"
    done
}

# ===================================
# Quick Check Mode
# ===================================

quick_check() {
    log "Running quick health check..."
    
    check_docker
    check_containers
    check_service_endpoints
    check_port_availability
    
    show_summary
}

# ===================================
# Main Function
# ===================================

main() {
    # Handle command line arguments
    case "${1:-}" in
        --help|-h)
            echo "Sentinel AK-XL Health Check Script"
            echo ""
            echo "Usage: $0 [mode] [options]"
            echo ""
            echo "Modes:"
            echo "  full              Full comprehensive health check (default)"
            echo "  quick             Quick essential checks only"
            echo "  monitor [interval] Continuous monitoring mode"
            echo "  report            Generate and save health report"
            echo ""
            echo "Options:"
            echo "  --help, -h        Show this help"
            echo "  --verbose         Verbose output"
            echo "  --silent          Minimal output"
            echo ""
            echo "Examples:"
            echo "  $0                Run full health check"
            echo "  $0 quick          Run quick check"
            echo "  $0 monitor 60     Monitor every 60 seconds"
            echo "  $0 report         Generate health report"
            echo ""
            exit 0
            ;;
        quick)
            print_banner
            quick_check
            ;;
        monitor)
            print_banner
            monitoring_mode "${2:-30}"
            ;;
        report)
            print_banner
            run_all_checks
            generate_health_report
            show_summary
            ;;
        full|"")
            print_banner
            run_all_checks
            show_summary
            ;;
        *)
            error "Unknown mode: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
    
    # Exit with appropriate code
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        exit 1
    elif [[ $WARNING_CHECKS -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# ===================================
# Script Entry Point
# ===================================

# Initialize variables
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Check if we're in the right directory
if [[ ! -f docker-compose.yml ]]; then
    error "This script must be run from the Sentinel AK-XL directory"
    exit 1
fi

# Run main function
main "$@"
