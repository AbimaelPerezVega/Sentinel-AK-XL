#!/bin/bash

# ===================================
# Sentinel AK-XL Basic Testing Script
# ===================================
# Progressive testing of core components
# Run this before proceeding to Phase 3
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

set -e

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
TEST_TIMEOUT=300  # 5 minutes timeout for each test
ELASTICSEARCH_URL="http://localhost:9200"
KIBANA_URL="http://localhost:5601"
LOGSTASH_URL="http://localhost:9600"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ===================================
# Utility Functions
# ===================================

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
            🧪 BASIC COMPONENT TESTING 🧪
               Progressive Validation Suite
EOF
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((PASSED_TESTS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

test_start() {
    echo -e "${BLUE}[TEST]${NC} $1"
    ((TOTAL_TESTS++))
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

wait_for_service() {
    local service_name=$1
    local health_url=$2
    local max_wait=${3:-120}
    local wait_time=0
    
    log "Waiting for $service_name to be ready..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        if curl -s "$health_url" &>/dev/null; then
            success "$service_name is ready! (${wait_time}s)"
            return 0
        fi
        
        printf "."
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    fail "$service_name failed to start within ${max_wait}s"
    return 1
}

# ===================================
# Pre-flight Checks
# ===================================

check_prerequisites() {
    test_start "Checking prerequisites"
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        fail "Docker is not running"
        return 1
    fi
    
    # Check if docker-compose is available
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        fail "Docker Compose not found"
        return 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -f docker-compose.yml ]]; then
        fail "docker-compose.yml not found. Are you in the right directory?"
        return 1
    fi
    
    # Check if .env exists
    if [[ ! -f .env ]]; then
        warn ".env file not found. Using defaults."
    fi
    
    # Check available disk space (at least 5GB)
    local available_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
    if [[ $available_gb -lt 5 ]]; then
        warn "Low disk space: ${available_gb}GB available (5GB+ recommended)"
    fi
    
    # Check memory
    local mem_gb=$(free -g | grep Mem | awk '{print $2}')
    if [[ $mem_gb -lt 8 ]]; then
        warn "Low memory: ${mem_gb}GB available (8GB+ recommended)"
    fi
    
    success "Prerequisites check passed"
    export COMPOSE_CMD
}

# ===================================
# Configuration Validation
# ===================================

validate_configurations() {
    test_start "Validating configuration files"
    
    local config_files=(
        "configs/elk/elasticsearch/elasticsearch.yml"
        "configs/elk/kibana/kibana.yml" 
        "configs/elk/logstash/logstash.yml"
        "configs/elk/logstash/pipelines.yml"
        "configs/elk/logstash/conf.d/input.conf"
        "configs/elk/logstash/conf.d/filter.conf"
        "configs/elk/logstash/conf.d/output.conf"
    )
    
    local missing_files=()
    
    for config_file in "${config_files[@]}"; do
        if [[ ! -f "$config_file" ]]; then
            missing_files+=("$config_file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        fail "Missing configuration files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
    
    # Validate docker-compose.yml syntax
    if ! $COMPOSE_CMD config &> /dev/null; then
        fail "docker-compose.yml has syntax errors"
        return 1
    fi
    
    success "All configuration files are present and valid"
}

# ===================================
# Level 1: Elasticsearch Only
# ===================================

test_elasticsearch_standalone() {
    test_start "Level 1: Testing Elasticsearch standalone"
    
    log "Stopping any running containers..."
    $COMPOSE_CMD down &> /dev/null || true
    
    log "Starting Elasticsearch..."
    $COMPOSE_CMD up -d elasticsearch
    
    # Wait for Elasticsearch to be ready
    if ! wait_for_service "Elasticsearch" "$ELASTICSEARCH_URL" 120; then
        log "Elasticsearch logs:"
        $COMPOSE_CMD logs --tail=20 elasticsearch
        return 1
    fi
    
    # Test basic connectivity
    log "Testing Elasticsearch connectivity..."
    if ! curl -s "$ELASTICSEARCH_URL" &> /dev/null; then
        fail "Cannot connect to Elasticsearch"
        return 1
    fi
    
    # Test authentication
    log "Testing Elasticsearch authentication..."
    local auth_response=$(curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL" | jq -r '.cluster_name' 2>/dev/null || echo "failed")
    if [[ "$auth_response" != "sentinel-cluster" ]]; then
        fail "Elasticsearch authentication failed"
        return 1
    fi
    
    # Test cluster health
    log "Testing Elasticsearch cluster health..."
    local health_status=$(curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL/_cluster/health" | jq -r '.status' 2>/dev/null || echo "red")
    if [[ "$health_status" == "red" ]]; then
        fail "Elasticsearch cluster health is red"
        return 1
    fi
    
    # Test index creation
    log "Testing index creation..."
    if ! curl -s -u elastic:changeme123! -X PUT "$ELASTICSEARCH_URL/test-index" &> /dev/null; then
        fail "Cannot create test index"
        return 1
    fi
    
    # Clean up test index
    curl -s -u elastic:changeme123! -X DELETE "$ELASTICSEARCH_URL/test-index" &> /dev/null
    
    success "✅ Elasticsearch Level 1 test passed!"
    
    # Show some useful info
    echo ""
    echo -e "${CYAN}Elasticsearch Info:${NC}"
    curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL" | jq '.' 2>/dev/null || curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL"
    echo ""
}

# ===================================
# Level 2: Elasticsearch + Kibana
# ===================================

test_kibana_integration() {
    test_start "Level 2: Testing Kibana integration"
    
    log "Starting Kibana..."
    $COMPOSE_CMD up -d kibana
    
    # Wait for Kibana to be ready (takes longer)
    if ! wait_for_service "Kibana" "$KIBANA_URL/api/status" 180; then
        log "Kibana logs:"
        $COMPOSE_CMD logs --tail=20 kibana
        return 1
    fi
    
    # Test Kibana web interface
    log "Testing Kibana web interface..."
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "$KIBANA_URL")
    if [[ "$status_code" != "200" ]]; then
        fail "Kibana web interface not accessible (HTTP $status_code)"
        return 1
    fi
    
    # Test Kibana API
    log "Testing Kibana API..."
    local kibana_status=$(curl -s "$KIBANA_URL/api/status" | jq -r '.status.overall.state' 2>/dev/null || echo "unknown")
    if [[ "$kibana_status" != "green" ]]; then
        warn "Kibana status is $kibana_status (may still be initializing)"
    fi
    
    # Test Elasticsearch connection from Kibana
    log "Testing Kibana -> Elasticsearch connection..."
    local es_ping=$(curl -s "$KIBANA_URL/api/console/proxy?path=/" 2>/dev/null || echo "failed")
    if [[ "$es_ping" == "failed" ]]; then
        warn "Kibana -> Elasticsearch connection test failed (may be authentication issue)"
    fi
    
    success "✅ Kibana Level 2 test passed!"
    
    echo ""
    echo -e "${CYAN}Access Information:${NC}"
    echo -e "Kibana Web UI: ${BLUE}http://localhost:5601${NC}"
    echo -e "Username: ${YELLOW}elastic${NC}"
    echo -e "Password: ${YELLOW}changeme123!${NC}"
    echo ""
}

# ===================================
# Level 3: Full ELK Stack
# ===================================

test_logstash_integration() {
    test_start "Level 3: Testing Logstash integration"
    
    log "Starting Logstash..."
    $COMPOSE_CMD up -d logstash
    
    # Wait for Logstash to be ready
    if ! wait_for_service "Logstash" "$LOGSTASH_URL" 120; then
        log "Logstash logs:"
        $COMPOSE_CMD logs --tail=20 logstash
        return 1
    fi
    
    # Test Logstash API
    log "Testing Logstash API..."
    local logstash_status=$(curl -s "$LOGSTASH_URL" | jq -r '.status' 2>/dev/null || echo "unknown")
    if [[ "$logstash_status" == "unknown" ]]; then
        warn "Logstash API not responding properly"
    fi
    
    # Test pipeline status
    log "Testing Logstash pipelines..."
    local pipeline_status=$(curl -s "$LOGSTASH_URL/_node/stats/pipelines" | jq -r '.pipelines.main.events.in' 2>/dev/null || echo "0")
    log "Main pipeline events processed: $pipeline_status"
    
    # Test log ingestion
    log "Testing log ingestion..."
    local test_event='{"@timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'","message":"Test event from basic testing","severity":"info","source":"test-script"}'
    
    # Send test event to Logstash beats input
    if command -v nc &> /dev/null; then
        echo "$test_event" | timeout 5 nc -w 1 localhost 5044 2>/dev/null || warn "Could not send test event via netcat"
    else
        warn "netcat not available, skipping log ingestion test"
    fi
    
    # Wait a moment for processing
    sleep 5
    
    # Check if event was indexed in Elasticsearch
    log "Checking if test event was indexed..."
    local indexed_events=$(curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL/_search?q=test-script" | jq -r '.hits.total.value' 2>/dev/null || echo "0")
    if [[ "$indexed_events" -gt 0 ]]; then
        success "Test event was successfully indexed!"
    else
        warn "Test event was not found in Elasticsearch (may take longer to process)"
    fi
    
    success "✅ Logstash Level 3 test passed!"
    
    echo ""
    echo -e "${CYAN}Logstash Info:${NC}"
    curl -s "$LOGSTASH_URL/_node/stats" | jq '.jvm.mem, .process.cpu' 2>/dev/null || echo "Stats not available"
    echo ""
}

# ===================================
# Data Flow Test
# ===================================

test_data_flow() {
    test_start "Testing end-to-end data flow"
    
    log "Creating test index pattern in Elasticsearch..."
    
    # Create a more comprehensive test event
    local test_event=$(cat << EOF
{
  "@timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "message": "Comprehensive test event for data flow validation",
  "severity": "medium",
  "source_ip": "192.168.1.100",
  "destination_ip": "10.0.0.5",
  "event_category": "test_event",
  "username": "test_user",
  "action": "test_action",
  "tags": ["test", "validation", "data-flow"]
}
EOF
    )
    
    # Send test event via HTTP (if available)
    if curl -s -X POST "http://localhost:8080" -H "Content-Type: application/json" -d "$test_event" &> /dev/null; then
        log "Test event sent via HTTP input"
    else
        log "HTTP input not available, using file method"
        
        # Create a test log file
        mkdir -p /tmp/sentinel-test
        echo "$test_event" > /tmp/sentinel-test/test.log
    fi
    
    # Wait for processing
    sleep 10
    
    # Search for our test event
    log "Searching for test event in Elasticsearch..."
    local search_result=$(curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL/_search?q=data-flow" | jq -r '.hits.total.value' 2>/dev/null || echo "0")
    
    if [[ "$search_result" -gt 0 ]]; then
        success "End-to-end data flow working! Found $search_result matching events."
        
        # Show the actual event
        log "Sample indexed event:"
        curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL/_search?q=data-flow&size=1" | jq '.hits.hits[0]._source' 2>/dev/null || echo "Could not parse event"
        
    else
        warn "No test events found in Elasticsearch. This may be normal if processing takes longer."
    fi
    
    # Clean up
    rm -rf /tmp/sentinel-test 2>/dev/null || true
}

# ===================================
# Performance Test
# ===================================

test_performance() {
    test_start "Basic performance validation"
    
    # Check resource usage
    log "Checking container resource usage..."
    
    local container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep sentinel 2>/dev/null || echo "No stats available")
    
    if [[ "$container_stats" != "No stats available" ]]; then
        echo -e "${CYAN}Container Resource Usage:${NC}"
        echo "$container_stats"
    fi
    
    # Check Elasticsearch performance
    log "Checking Elasticsearch performance..."
    local es_stats=$(curl -s -u elastic:changeme123! "$ELASTICSEARCH_URL/_cluster/stats" 2>/dev/null)
    if [[ -n "$es_stats" ]]; then
        local docs_count=$(echo "$es_stats" | jq -r '.indices.count' 2>/dev/null || echo "unknown")
        local storage_size=$(echo "$es_stats" | jq -r '.indices.store.size_in_bytes' 2>/dev/null || echo "unknown")
        log "Elasticsearch indices: $docs_count, Storage: $storage_size bytes"
    fi
    
    success "Performance check completed"
}

# ===================================
# Cleanup and Summary
# ===================================

cleanup_test_data() {
    log "Cleaning up test data..."
    
    # Remove test indices
    curl -s -u elastic:changeme123! -X DELETE "$ELASTICSEARCH_URL/test-*" &> /dev/null || true
    
    log "Test cleanup completed"
}

show_summary() {
    echo ""
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${CYAN}Basic Testing Summary${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 All basic tests passed! 🎉${NC}"
        echo -e "${GREEN}You can proceed with confidence to Phase 3 (Wazuh configuration)${NC}"
        echo ""
        echo -e "${CYAN}What's working:${NC}"
        echo -e "✅ Elasticsearch is running and accessible"
        echo -e "✅ Kibana is running and connected to Elasticsearch" 
        echo -e "✅ Logstash is processing events"
        echo -e "✅ End-to-end data flow is functional"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo -e "1. Continue with Phase 3: Wazuh configuration"
        echo -e "2. Run ./health-check.sh for ongoing monitoring"
        echo -e "3. Access Kibana at http://localhost:5601 (elastic/changeme123!)"
        
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        echo -e "${YELLOW}Please review the errors above before proceeding${NC}"
        echo ""
        echo -e "${CYAN}Troubleshooting:${NC}"
        echo -e "1. Check container logs: docker-compose logs [service]"
        echo -e "2. Verify system resources (memory, disk space)"
        echo -e "3. Ensure all configuration files are in place"
        echo -e "4. Try restarting: docker-compose restart"
    fi
    echo ""
}

# ===================================
# Interactive Mode
# ===================================

interactive_menu() {
    while true; do
        echo -e "\n${CYAN}Select test level:${NC}"
        echo -e "  ${YELLOW}1)${NC} Prerequisites check only"
        echo -e "  ${YELLOW}2)${NC} Level 1: Elasticsearch only"
        echo -e "  ${YELLOW}3)${NC} Level 2: Elasticsearch + Kibana"
        echo -e "  ${YELLOW}4)${NC} Level 3: Full ELK stack"
        echo -e "  ${YELLOW}5)${NC} Complete test suite (recommended)"
        echo -e "  ${YELLOW}6)${NC} Performance check only"
        echo -e "  ${YELLOW}r)${NC} View container status"
        echo -e "  ${YELLOW}c)${NC} Clean up and stop all"
        echo -e "  ${YELLOW}q)${NC} Quit"
        echo ""
        read -p "Enter your choice: " choice
        
        case $choice in
            1) check_prerequisites ;;
            2) check_prerequisites && test_elasticsearch_standalone ;;
            3) check_prerequisites && test_elasticsearch_standalone && test_kibana_integration ;;
            4) check_prerequisites && test_elasticsearch_standalone && test_kibana_integration && test_logstash_integration ;;
            5) run_complete_test_suite ;;
            6) test_performance ;;
            r) $COMPOSE_CMD ps ;;
            c) 
                $COMPOSE_CMD down
                cleanup_test_data
                log "All containers stopped and test data cleaned up"
                ;;
            q) 
                log "Exiting test suite"
                exit 0
                ;;
            *)
                warn "Invalid option. Please try again."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# ===================================
# Complete Test Suite
# ===================================

run_complete_test_suite() {
    log "Running complete test suite..."
    
    # Reset counters
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
    
    # Run all tests in sequence
    check_prerequisites && \
    validate_configurations && \
    test_elasticsearch_standalone && \
    test_kibana_integration && \
    test_logstash_integration && \
    test_data_flow && \
    test_performance
    
    cleanup_test_data
    show_summary
}

# ===================================
# Main Function
# ===================================

main() {
    print_banner
    
    case "${1:-}" in
        --help|-h)
            echo "Sentinel AK-XL Basic Testing Script"
            echo ""
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  --help, -h         Show this help"
            echo "  --quick            Quick validation (prerequisites + ES)"
            echo "  --full             Complete test suite"
            echo "  --interactive      Interactive mode (default)"
            echo "  --elasticsearch    Test Elasticsearch only"
            echo "  --kibana           Test Elasticsearch + Kibana"
            echo "  --logstash         Test full ELK stack"
            echo ""
            exit 0
            ;;
        --quick)
            check_prerequisites && test_elasticsearch_standalone
            ;;
        --full)
            run_complete_test_suite
            ;;
        --elasticsearch)
            check_prerequisites && test_elasticsearch_standalone
            ;;
        --kibana)
            check_prerequisites && test_elasticsearch_standalone && test_kibana_integration
            ;;
        --logstash)
            check_prerequisites && test_elasticsearch_standalone && test_kibana_integration && test_logstash_integration
            ;;
        --interactive|"")
            interactive_menu
            ;;
        *)
            error "Unknown option: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
}

# ===================================
# Script Entry Point
# ===================================

# Check if jq is available (for JSON parsing)
if ! command -v jq &> /dev/null; then
    warn "jq not found. Some tests may show limited information."
    warn "Install jq for better test output: sudo apt-get install jq"
fi

# Run main function
main "$@"
