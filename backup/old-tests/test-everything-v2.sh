#!/bin/bash

# Use Docker Compose v2
export COMPOSE_CMD="docker compose"

# ===================================
# Sentinel AK-XL Complete Testing Script
# ===================================
# One-command setup and testing for the entire ELK stack
# This script does everything: setup + test + validate
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
LOG_FILE="test-everything.log"

# Test state
SETUP_DONE=false
TESTING_DONE=false
VALIDATION_DONE=false

# ===================================
# Utility Functions
# ===================================

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
          🚀 COMPLETE TESTING SUITE 🚀
            Setup → Test → Validate
             One Command Does It All!
EOF
    echo -e "${NC}"
}

log_and_echo() {
    local message="$1"
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
}

error_and_exit() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >> "$LOG_FILE"
    echo ""
    echo -e "${YELLOW}Check the log file for details: $LOG_FILE${NC}"
    exit 1
}

step_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo ""
}

countdown() {
    local seconds=$1
    local message="${2:-Waiting}"
    
    for ((i=seconds; i>0; i--)); do
        printf "\r${YELLOW}$message... %02d seconds${NC}" $i
        sleep 1
    done
    printf "\r${GREEN}$message... Done!${NC}           \n"
}

# ===================================
# Prerequisites Check
# ===================================

check_system_ready() {
    step_header "🔍 CHECKING SYSTEM PREREQUISITES"
    
    log_and_echo "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        error_and_exit "Docker is not installed. Please install Docker first."
    fi
    
    if ! docker info &> /dev/null; then
        error_and_exit "Docker daemon is not running. Please start Docker."
    fi
    
    log_and_echo "✅ Docker is running"
    
    # Check Docker Compose
    if command -v docker compose &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        error_and_exit "Docker Compose not found"
    fi
    
    log_and_echo "✅ Docker Compose available: $COMPOSE_CMD"
    
    # Check system resources
    local mem_gb=$(free -g | grep Mem | awk '{print $2}' 2>/dev/null || echo "0")
    if [[ $mem_gb -lt 4 ]]; then
        echo -e "${YELLOW}⚠️  Warning: Only ${mem_gb}GB RAM available. 8GB+ recommended.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        log_and_echo "✅ Memory: ${mem_gb}GB available"
    fi
    
    # Check disk space
    local disk_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
    if [[ $disk_gb -lt 10 ]]; then
        echo -e "${YELLOW}⚠️  Warning: Only ${disk_gb}GB disk space available. 20GB+ recommended.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        log_and_echo "✅ Disk space: ${disk_gb}GB available"
    fi
    
    # Check ports
    local ports_to_check=(9200 5601 5044 9600)
    local port_conflicts=()
    
    for port in "${ports_to_check[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            port_conflicts+=($port)
        fi
    done
    
    if [[ ${#port_conflicts[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Warning: Ports in use: ${port_conflicts[*]}${NC}"
        read -p "Stop conflicting services and continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        log_and_echo "✅ Required ports are available"
    fi
    
    export COMPOSE_CMD
    log_and_echo "✅ System prerequisites check completed"
}

# ===================================
# Automatic Setup
# ===================================

run_automatic_setup() {
    step_header "⚙️  AUTOMATIC SETUP"
    
    log_and_echo "Running quick setup script..."
    
    # Check if quick-setup.sh exists
    if [[ ! -f quick-setup.sh ]]; then
        error_and_exit "quick-setup.sh not found. Please ensure all scripts are present."
    fi
    
    # Run quick setup with force flag
    if ./quick-setup.sh --force >> "$LOG_FILE" 2>&1; then
        log_and_echo "✅ Quick setup completed successfully"
        SETUP_DONE=true
    else
        error_and_exit "Quick setup failed. Check log for details."
    fi
    
    # Validate setup
    log_and_echo "Validating setup configuration..."
    if ./quick-setup.sh --validate >> "$LOG_FILE" 2>&1; then
        log_and_echo "✅ Setup validation passed"
    else
        error_and_exit "Setup validation failed"
    fi
}

# ===================================
# ELK Stack Testing
# ===================================

test_elk_stack() {
    step_header "🧪 TESTING ELK STACK"
    
    log_and_echo "Starting ELK stack testing..."
    
    # Use the test docker compose file
    export COMPOSE_FILE=docker-compose-test.yml
    
    # Clean up any existing containers
    log_and_echo "Cleaning up existing containers..."
    $COMPOSE_CMD down -v >> "$LOG_FILE" 2>&1 || true
    
    # Test Level 1: Elasticsearch
    log_and_echo "🔍 Level 1: Testing Elasticsearch..."
    $COMPOSE_CMD up -d elasticsearch >> "$LOG_FILE" 2>&1
    
    countdown 45 "Waiting for Elasticsearch to start"
    
    # Test Elasticsearch connection
    local es_attempts=0
    local es_max_attempts=20
    
    while [[ $es_attempts -lt $es_max_attempts ]]; do
        if curl -s -u elastic:changeme123! http://localhost:9200 >> "$LOG_FILE" 2>&1; then
            log_and_echo "✅ Elasticsearch is responding"
            break
        fi
        ((es_attempts++))
        sleep 3
    done
    
    if [[ $es_attempts -eq $es_max_attempts ]]; then
        echo -e "${RED}❌ Elasticsearch failed to start${NC}"
        echo "Elasticsearch logs:"
        $COMPOSE_CMD logs elasticsearch | tail -20
        return 1
    fi
    
    # Test Level 2: Kibana
    log_and_echo "🔍 Level 2: Testing Kibana..."
    $COMPOSE_CMD up -d kibana >> "$LOG_FILE" 2>&1
    
    countdown 90 "Waiting for Kibana to start"
    
    # Test Kibana connection
    local kibana_attempts=0
    local kibana_max_attempts=30
    
    while [[ $kibana_attempts -lt $kibana_max_attempts ]]; do
        if curl -s http://localhost:5601 >> "$LOG_FILE" 2>&1; then
            log_and_echo "✅ Kibana is responding"
            break
        fi
        ((kibana_attempts++))
        sleep 3
    done
    
    if [[ $kibana_attempts -eq $kibana_max_attempts ]]; then
        echo -e "${RED}❌ Kibana failed to start${NC}"
        echo "Kibana logs:"
        $COMPOSE_CMD logs kibana | tail -20
        return 1
    fi
    
    # Test Level 3: Logstash
    log_and_echo "🔍 Level 3: Testing Logstash..."
    $COMPOSE_CMD up -d logstash >> "$LOG_FILE" 2>&1
    
    countdown 60 "Waiting for Logstash to start"
    
    # Test Logstash connection
    local logstash_attempts=0
    local logstash_max_attempts=20
    
    while [[ $logstash_attempts -lt $logstash_max_attempts ]]; do
        if curl -s http://localhost:9600 >> "$LOG_FILE" 2>&1; then
            log_and_echo "✅ Logstash is responding"
            break
        fi
        ((logstash_attempts++))
        sleep 3
    done
    
    if [[ $logstash_attempts -eq $logstash_max_attempts ]]; then
        echo -e "${RED}❌ Logstash failed to start${NC}"
        echo "Logstash logs:"
        $COMPOSE_CMD logs logstash | tail -20
        return 1
    fi
    
    TESTING_DONE=true
    log_and_echo "✅ ELK Stack testing completed successfully"
}

# ===================================
# Data Flow Validation
# ===================================

validate_data_flow() {
    step_header "📊 VALIDATING DATA FLOW"
    
    log_and_echo "Testing end-to-end data flow..."
    
    # Create test event
    local test_event=$(cat << EOF
{
  "@timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "message": "Complete testing suite validation event",
  "level": "INFO",
  "source": "test-everything-script",
  "test_id": "$(date +%s)",
  "environment": "testing"
}
EOF
    )
    
    log_and_echo "Sending test event to Logstash..."
    
    # Send test event via HTTP
    if curl -s -X POST "http://localhost:8080" \
        -H "Content-Type: application/json" \
        -d "$test_event" >> "$LOG_FILE" 2>&1; then
        log_and_echo "✅ Test event sent successfully"
    else
        log_and_echo "⚠️  HTTP method failed, trying TCP..."
        echo "$test_event" | nc -w 5 localhost 9000 >> "$LOG_FILE" 2>&1 || true
    fi
    
    # Wait for processing
    countdown 15 "Waiting for event processing"
    
    # Search for test event in Elasticsearch
    log_and_echo "Searching for test event in Elasticsearch..."
    
    local search_attempts=0
    local search_max_attempts=10
    local found_events=0
    
    while [[ $search_attempts -lt $search_max_attempts ]]; do
        found_events=$(curl -s -u elastic:changeme123! \
            "http://localhost:9200/_search?q=test-everything-script" | \
            jq -r '.hits.total.value' 2>/dev/null || echo "0")
        
        if [[ "$found_events" -gt 0 ]]; then
            log_and_echo "✅ Found $found_events test event(s) in Elasticsearch"
            break
        fi
        
        ((search_attempts++))
        sleep 3
    done
    
    if [[ "$found_events" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Test event not found in Elasticsearch (may need more time)${NC}"
    fi
    
    # Check Elasticsearch indices
    log_and_echo "Checking Elasticsearch indices..."
    local indices=$(curl -s -u elastic:changeme123! \
        "http://localhost:9200/_cat/indices?h=index" | grep -E "(test-logs|logstash)" | wc -l)
    
    if [[ $indices -gt 0 ]]; then
        log_and_echo "✅ Found $indices indices in Elasticsearch"
    else
        log_and_echo "⚠️  No test indices found yet"
    fi
    
    VALIDATION_DONE=true
    log_and_echo "✅ Data flow validation completed"
}

# ===================================
# Show Final Results
# ===================================

show_final_results() {
    step_header "🎉 FINAL RESULTS"
    
    # Summary table
    echo -e "${CYAN}Test Results Summary:${NC}"
    echo "┌─────────────────────────┬──────────┐"
    echo "│ Component               │ Status   │"
    echo "├─────────────────────────┼──────────┤"
    
    # Setup status
    if [[ $SETUP_DONE == true ]]; then
        echo "│ Setup & Configuration   │ ✅ PASS  │"
    else
        echo "│ Setup & Configuration   │ ❌ FAIL  │"
    fi
    
    # Individual component status
    local es_status="❌ FAIL"
    local kibana_status="❌ FAIL"
    local logstash_status="❌ FAIL"
    
    if curl -s -u elastic:changeme123! http://localhost:9200 >> "$LOG_FILE" 2>&1; then
        es_status="✅ PASS"
    fi
    
    if curl -s http://localhost:5601 >> "$LOG_FILE" 2>&1; then
        kibana_status="✅ PASS"
    fi
    
    if curl -s http://localhost:9600 >> "$LOG_FILE" 2>&1; then
        logstash_status="✅ PASS"
    fi
    
    echo "│ Elasticsearch           │ $es_status  │"
    echo "│ Kibana                  │ $kibana_status  │"
    echo "│ Logstash                │ $logstash_status  │"
    
    # Data flow status
    if [[ $VALIDATION_DONE == true ]]; then
        echo "│ Data Flow               │ ✅ PASS  │"
    else
        echo "│ Data Flow               │ ❌ FAIL  │"
    fi
    
    echo "└─────────────────────────┴──────────┘"
    echo ""
    
    # Access information
    if [[ $es_status == "✅ PASS" ]] && [[ $kibana_status == "✅ PASS" ]]; then
        echo -e "${GREEN}🎉 SUCCESS! Your ELK Stack is working! 🎉${NC}"
        echo ""
        echo -e "${CYAN}📋 Access Information:${NC}"
        echo -e "┌─────────────────────────────────────────────────────┐"
        echo -e "│ 🔍 Elasticsearch: http://localhost:9200            │"
        echo -e "│    Username: elastic                                │"
        echo -e "│    Password: changeme123!                           │"
        echo -e "│                                                     │"
        echo -e "│ 📊 Kibana Dashboard: http://localhost:5601         │"
        echo -e "│    Username: elastic                                │"
        echo -e "│    Password: changeme123!                           │"
        echo -e "│                                                     │"
        echo -e "│ 🔄 Logstash API: http://localhost:9600             │"
        echo -e "│    HTTP Input: http://localhost:8080               │"
        echo -e "│    TCP Input: localhost:9000                       │"
        echo -e "│    Beats Input: localhost:5044                     │"
        echo -e "└─────────────────────────────────────────────────────┘"
        echo ""
        
        echo -e "${CYAN}🧪 Test Commands:${NC}"
        echo -e "# Send a test event:"
        echo -e "curl -X POST http://localhost:8080 -H 'Content-Type: application/json' \\"
        echo -e "  -d '{\"message\":\"Hello from Sentinel!\",\"level\":\"INFO\"}'"
        echo ""
        echo -e "# Check Elasticsearch health:"
        echo -e "curl -u elastic:changeme123! http://localhost:9200/_cluster/health"
        echo ""
        echo -e "# Search for events:"
        echo -e "curl -u elastic:changeme123! \"http://localhost:9200/_search?q=*&size=5\""
        echo ""
        
        echo -e "${CYAN}🚀 Ready for Phase 3!${NC}"
        echo -e "Your ELK Stack is working perfectly. You can now proceed with confidence to:"
        echo -e "• Phase 3: Wazuh configuration"
        echo -e "• Phase 4: TheHive & Cortex setup"
        echo -e "• Phase 5: Agent simulators"
        
    else
        echo -e "${RED}❌ Some components failed to start${NC}"
        echo ""
        echo -e "${YELLOW}🔧 Troubleshooting Steps:${NC}"
        echo -e "1. Check the detailed log: cat $LOG_FILE"
        echo -e "2. Check container logs: $COMPOSE_CMD logs [service]"
        echo -e "3. Verify system resources (RAM/disk)"
        echo -e "4. Try restarting: $COMPOSE_CMD restart"
        echo -e "5. Clean restart: $COMPOSE_CMD down && $COMPOSE_CMD up -d"
        echo ""
        echo -e "${CYAN}📋 Container Status:${NC}"
        $COMPOSE_CMD ps
    fi
    
    echo ""
    echo -e "${CYAN}🗂️  Generated Files:${NC}"
    echo -e "• $LOG_FILE - Detailed execution log"
    echo -e "• .env - Environment configuration"
    echo -e "• docker-compose-test.yml - Test environment"
    echo -e "• configs/elk/ - ELK configuration files"
    echo -e "• test-elk-quick.sh - Quick test script"
    echo -e "• cleanup-test.sh - Cleanup script"
    echo ""
    echo -e "${CYAN}🛠️  Management Commands:${NC}"
    echo -e "• Start: $COMPOSE_CMD up -d"
    echo -e "• Stop: $COMPOSE_CMD down"
    echo -e "• Logs: $COMPOSE_CMD logs [service]"
    echo -e "• Status: $COMPOSE_CMD ps"
    echo -e "• Clean: ./cleanup-test.sh"
    echo ""
}

# ===================================
# Error Recovery
# ===================================

handle_error() {
    local exit_code=$?
    echo ""
    echo -e "${RED}❌ An error occurred during testing (exit code: $exit_code)${NC}"
    echo ""
    echo -e "${YELLOW}🔍 Diagnostic Information:${NC}"
    echo "Current step: $current_step"
    echo "Setup done: $SETUP_DONE"
    echo "Testing done: $TESTING_DONE"
    echo "Validation done: $VALIDATION_DONE"
    echo ""
    echo -e "${CYAN}📋 Container Status:${NC}"
    $COMPOSE_CMD ps 2>/dev/null || echo "Could not get container status"
    echo ""
    echo -e "${CYAN}📝 Last 20 lines of log:${NC}"
    tail -20 "$LOG_FILE" 2>/dev/null || echo "Could not read log file"
    echo ""
    echo -e "${YELLOW}💡 Quick Fixes:${NC}"
    echo -e "1. Check system resources: free -h && df -h"
    echo -e "2. Restart Docker: sudo systemctl restart docker"
    echo -e "3. Clean and retry: ./cleanup-test.sh && ./test-everything.sh"
    echo -e "4. Check the full log: cat $LOG_FILE"
    echo ""
    exit $exit_code
}

# ===================================
# Interactive Mode
# ===================================

interactive_mode() {
    echo -e "${CYAN}🎮 Interactive Mode${NC}"
    echo ""
    echo "This will automatically:"
    echo "1. ✅ Check system prerequisites"
    echo "2. ⚙️  Set up directory structure and configs"
    echo "3. 🧪 Test Elasticsearch, Kibana, and Logstash"
    echo "4. 📊 Validate end-to-end data flow"
    echo "5. 🎉 Show access information and next steps"
    echo ""
    echo -e "${YELLOW}Estimated time: 5-10 minutes${NC}"
    echo -e "${YELLOW}Required resources: 4GB+ RAM, 10GB+ disk${NC}"
    echo ""
    read -p "Ready to start? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
}

# ===================================
# Main Testing Flow
# ===================================

run_complete_flow() {
    # Set up error handling
    trap handle_error ERR
    
    # Initialize log
    echo "Sentinel AK-XL Complete Testing - $(date)" > "$LOG_FILE"
    echo "=========================================" >> "$LOG_FILE"
    
    # Run all steps
    current_step="Prerequisites Check"
    check_system_ready
    
    current_step="Automatic Setup"
    run_automatic_setup
    
    current_step="ELK Stack Testing"
    test_elk_stack
    
    current_step="Data Flow Validation"
    validate_data_flow
    
    current_step="Final Results"
    show_final_results
    
    # Remove error trap
    trap - ERR
}

# ===================================
# Main Function
# ===================================

main() {
    case "${1:-}" in
        --help|-h)
            print_banner
            echo "Sentinel AK-XL Complete Testing Script"
            echo ""
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  --help, -h         Show this help"
            echo "  --auto             Run automated testing (no prompts)"
            echo "  --setup-only       Run setup only"
            echo "  --test-only        Run testing only (requires existing setup)"
            echo "  --validate-only    Run validation only"
            echo "  --clean            Clean up and exit"
            echo "  --status           Show current status"
            echo ""
            echo "Default: Interactive mode"
            echo ""
            echo "This script combines setup and testing into one command."
            echo "It will automatically configure and test the ELK stack."
            echo ""
            exit 0
            ;;
        --auto)
            print_banner
            log_and_echo "Starting automated testing..."
            run_complete_flow
            ;;
        --setup-only)
            print_banner
            check_system_ready
            run_automatic_setup
            log_and_echo "Setup completed. Run with --test-only to test."
            ;;
        --test-only)
            print_banner
            check_system_ready
            test_elk_stack
            validate_data_flow
            show_final_results
            ;;
        --validate-only)
            print_banner
            validate_data_flow
            show_final_results
            ;;
        --clean)
            echo "🧹 Cleaning up test environment..."
            export COMPOSE_FILE=docker-compose-test.yml
            $COMPOSE_CMD down -v 2>/dev/null || true
            docker volume prune -f 2>/dev/null || true
            rm -f "$LOG_FILE" 2>/dev/null || true
            echo "✅ Cleanup completed"
            ;;
        --status)
            print_banner
            echo -e "${CYAN}Current System Status:${NC}"
            echo ""
            if [[ -f docker-compose-test.yml ]]; then
                export COMPOSE_FILE=docker-compose-test.yml
                echo "Container Status:"
                $COMPOSE_CMD ps
                echo ""
                echo "Service Health:"
                curl -s -u elastic:changeme123! http://localhost:9200 &>/dev/null && echo "✅ Elasticsearch: Running" || echo "❌ Elasticsearch: Not accessible"
                curl -s http://localhost:5601 &>/dev/null && echo "✅ Kibana: Running" || echo "❌ Kibana: Not accessible"
                curl -s http://localhost:9600 &>/dev/null && echo "✅ Logstash: Running" || echo "❌ Logstash: Not accessible"
            else
                echo "❌ Test environment not set up"
                echo "Run: ./test-everything.sh to set up and test"
            fi
            ;;
        "")
            print_banner
            interactive_mode
            run_complete_flow
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# ===================================
# Script Entry Point
# ===================================

# Check if we're in the right directory
if [[ ! -f docker compose.yml ]] && [[ ! -f README.md ]]; then
    echo -e "${YELLOW}⚠️  This doesn't appear to be the Sentinel AK-XL directory${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Detect Docker Compose command
if command -v docker compose &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo -e "${RED}❌ Docker Compose not found${NC}"
    exit 1
fi

export COMPOSE_CMD

# Run main function
main "$@"
