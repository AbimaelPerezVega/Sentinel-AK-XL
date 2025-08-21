#!/bin/bash

# ===================================
# Sentinel AK-XL Configuration Verification Script
# ===================================
# Ensures local configuration matches project requirements
# Prevents misconfiguration issues for team members
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Global variables
VERIFICATION_LOG="verification_report_$(date +%Y%m%d_%H%M%S).log"
ERRORS_FOUND=0
WARNINGS_FOUND=0
FIXES_APPLIED=0

# Logging functions
log() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$VERIFICATION_LOG"
}

warn() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "$VERIFICATION_LOG"
    ((WARNINGS_FOUND++))
}

error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "$VERIFICATION_LOG"
    ((ERRORS_FOUND++))
}

info() {
    echo -e "${BLUE}[i]${NC} $1" | tee -a "$VERIFICATION_LOG"
}

header() {
    echo -e "\n${CYAN}${BOLD}$1${NC}" | tee -a "$VERIFICATION_LOG"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}" | tee -a "$VERIFICATION_LOG"
}

# ===================================
# File Structure Verification
# ===================================

verify_project_structure() {
    header "📁 VERIFYING PROJECT STRUCTURE"
    
    # Required directories
    local required_dirs=(
        "configs"
        "configs/elk"
        "configs/elk/elasticsearch"
        "configs/elk/kibana"
        "configs/elk/logstash"
        "configs/elk/logstash/conf.d"
        "configs/wazuh"
        "data"
        "logs"
        "scenarios"
        "scripts"
    )
    
    # Required files
    local required_files=(
        "docker-compose.yml"
        ".env"
        ".gitignore"
        "README.md"
        "configs/elk/elasticsearch/elasticsearch.yml"
        "configs/elk/kibana/kibana.yml"
        "configs/elk/logstash/logstash.yml"
        "configs/elk/logstash/pipelines.yml"
        "configs/elk/logstash/conf.d/input.conf"
        "configs/elk/logstash/conf.d/filter.conf"
        "configs/elk/logstash/conf.d/output.conf"
    )
    
    # Optional files (nice to have but not required)
    local optional_files=(
        "docker-compose-wazuh.yml"
    )
    
    # Check directories
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Directory exists: $dir"
        else
            error "Missing directory: $dir"
            info "Creating directory: $dir"
            mkdir -p "$dir"
            ((FIXES_APPLIED++))
        fi
    done
    
    # Check files
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "File exists: $file"
        else
            error "Missing file: $file"
        fi
    done
    
    # Check optional files
    for file in "${optional_files[@]}"; do
        if [[ -f "$file" ]]; then
            log "Optional file exists: $file"
        else
            info "Optional file not found: $file (OK if integrated in main docker-compose.yml)"
        fi
    done
}

# ===================================
# Configuration File Validation
# ===================================

validate_elasticsearch_config() {
    header "🔍 VALIDATING ELASTICSEARCH CONFIGURATION"
    
    local config_file="configs/elk/elasticsearch/elasticsearch.yml"
    
    if [[ ! -f "$config_file" ]]; then
        error "Elasticsearch config not found: $config_file"
        return 1
    fi
    
    # Check for critical settings
    local required_settings=(
        "cluster.name"
        "node.name" 
        "discovery.type"
        "network.host"
        "http.port"
    )
    
    for setting in "${required_settings[@]}"; do
        if grep -q "^${setting}:" "$config_file"; then
            log "Found setting: $setting"
        else
            warn "Missing or commented setting: $setting"
        fi
    done
    
    # Check for problematic settings
    if grep -q "cluster.routing.allocation.disk.threshold.enabled" "$config_file"; then
        error "Found problematic setting with dots: cluster.routing.allocation.disk.threshold.enabled"
        error "Should use underscore: cluster.routing.allocation.disk.threshold_enabled"
    fi
    
    # Verify memory lock setting
    if grep -q "bootstrap.memory_lock: true" "$config_file"; then
        warn "bootstrap.memory_lock is set to true - may cause issues in containers"
        info "Consider setting to false for Docker environments"
    fi
}

validate_kibana_config() {
    header "🔍 VALIDATING KIBANA CONFIGURATION"
    
    local config_file="configs/elk/kibana/kibana.yml"
    
    if [[ ! -f "$config_file" ]]; then
        error "Kibana config not found: $config_file"
        return 1
    fi
    
    # Check for Elasticsearch connection
    if grep -q "elasticsearch.hosts" "$config_file"; then
        log "Found Elasticsearch hosts configuration"
    else
        error "Missing elasticsearch.hosts configuration"
    fi
    
    # Check for problematic v9.1.2 settings
    if grep -q "xpack.security.enabled" "$config_file"; then
        warn "Found xpack.security.enabled in Kibana config"
        warn "This setting can cause issues in Kibana 9.1.2"
        info "Consider removing or commenting this line"
    fi
    
    # Check authentication settings
    if grep -q "elasticsearch.username.*elastic" "$config_file"; then
        warn "Found hardcoded elastic user in Kibana config"
        warn "This can cause authentication issues in v9.1.2"
    fi
}

validate_docker_compose() {
    header "🐳 VALIDATING DOCKER COMPOSE CONFIGURATION"
    
    # Check main docker-compose.yml
    if [[ ! -f "docker-compose.yml" ]]; then
        error "Main docker-compose.yml not found"
        return 1
    fi
    
    # Validate syntax
    if command -v docker >/dev/null && docker compose config >/dev/null 2>&1; then
        log "Docker Compose syntax is valid"
    else
        error "Docker Compose syntax validation failed"
        info "Run 'docker compose config' to see detailed errors"
    fi
    
    # Check for memory settings
    if grep -q "ES_JAVA_OPTS.*-Xms.*-Xmx" "docker-compose.yml"; then
        log "Found Elasticsearch memory configuration"
        local mem_setting=$(grep "ES_JAVA_OPTS" docker-compose.yml | grep -o "Xmx[0-9]*[gG]" | head -1)
        info "Elasticsearch memory limit: $mem_setting"
    else
        warn "No explicit Elasticsearch memory configuration found"
    fi
    
    # Check network configuration
    if grep -q "networks:" "docker-compose.yml"; then
        log "Found network configuration"
    else
        warn "No custom network configuration found"
    fi
    
    # Check volumes
    if grep -q "volumes:" "docker-compose.yml"; then
        log "Found volume configuration"
    else
        warn "No volume configuration found - data will not persist"
    fi
}

# ===================================
# Environment and Dependencies Check
# ===================================

check_system_requirements() {
    header "🖥️ CHECKING SYSTEM REQUIREMENTS"
    
    # Check Docker
    if command -v docker >/dev/null; then
        local docker_version=$(docker --version | grep -o "[0-9]*\.[0-9]*\.[0-9]*" | head -1)
        log "Docker version: $docker_version"
        
        # Check if Docker is running
        if docker info >/dev/null 2>&1; then
            log "Docker daemon is running"
        else
            error "Docker daemon is not running"
            info "Start Docker with: sudo systemctl start docker"
        fi
    else
        error "Docker is not installed"
    fi
    
    # Check Docker Compose
    if docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version --short)
        log "Docker Compose version: $compose_version"
    elif command -v docker-compose >/dev/null; then
        local compose_version=$(docker-compose --version | grep -o "[0-9]*\.[0-9]*\.[0-9]*")
        warn "Using legacy docker-compose: $compose_version"
        info "Consider upgrading to Docker Compose V2"
    else
        error "Docker Compose is not available"
    fi
    
    # Check available memory
    if command -v free >/dev/null; then
        local total_mem_gb=$(free -g | awk '/^Mem:/{print $2}')
        if [[ $total_mem_gb -ge 8 ]]; then
            log "System memory: ${total_mem_gb}GB (adequate)"
        elif [[ $total_mem_gb -ge 4 ]]; then
            warn "System memory: ${total_mem_gb}GB (minimum, may need tuning)"
        else
            error "System memory: ${total_mem_gb}GB (insufficient for full stack)"
        fi
    fi
    
    # Check available disk space
    local available_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
    if [[ $available_gb -ge 50 ]]; then
        log "Available disk space: ${available_gb}GB (adequate)"
    elif [[ $available_gb -ge 20 ]]; then
        warn "Available disk space: ${available_gb}GB (minimum)"
    else
        error "Available disk space: ${available_gb}GB (insufficient)"
    fi
}

check_port_conflicts() {
    header "🔌 CHECKING PORT CONFLICTS"
    
    local required_ports=(9200 5601 5044 55000 9201 1514 1515)
    local conflicting_ports=()
    
    for port in "${required_ports[@]}"; do
        if command -v netstat >/dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                conflicting_ports+=($port)
            fi
        elif command -v ss >/dev/null; then
            if ss -tuln 2>/dev/null | grep -q ":$port "; then
                conflicting_ports+=($port)
            fi
        fi
    done
    
    if [[ ${#conflicting_ports[@]} -eq 0 ]]; then
        log "No port conflicts detected"
    else
        warn "Port conflicts detected: ${conflicting_ports[*]}"
        info "Consider stopping conflicting services or changing ports"
    fi
}

# ===================================
# Configuration Consistency Check
# ===================================

check_configuration_consistency() {
    header "🔄 CHECKING CONFIGURATION CONSISTENCY"
    
    # Check if Elasticsearch host in Kibana matches docker-compose
    local kibana_es_host=""
    if [[ -f "configs/elk/kibana/kibana.yml" ]]; then
        kibana_es_host=$(grep "elasticsearch.hosts" configs/elk/kibana/kibana.yml | sed 's/.*\[\"\(.*\)\"\].*/\1/' || echo "")
    fi
    
    if [[ -n "$kibana_es_host" ]]; then
        log "Kibana Elasticsearch host: $kibana_es_host"
        
        # Check if it matches docker-compose service name
        if grep -q "elasticsearch:" docker-compose.yml; then
            if [[ "$kibana_es_host" == *"elasticsearch"* ]]; then
                log "Elasticsearch host configuration is consistent"
            else
                warn "Elasticsearch host in Kibana config may not match Docker service name"
            fi
        fi
    fi
    
    # Check memory consistency between .env and docker-compose
    if [[ -f ".env" ]]; then
        local env_es_mem=$(grep "ES_MEM=" .env | cut -d'=' -f2 || echo "")
        if [[ -n "$env_es_mem" ]]; then
            if grep -q "ES_JAVA_OPTS.*$env_es_mem" docker-compose.yml; then
                log "Memory configuration is consistent between .env and docker-compose"
            else
                warn "Memory configuration mismatch between .env and docker-compose"
            fi
        fi
    fi
}

# ===================================
# Security Configuration Check
# ===================================

check_security_configuration() {
    header "🔒 CHECKING SECURITY CONFIGURATION"
    
    # Check for default passwords
    local config_files=("configs/elk/elasticsearch/elasticsearch.yml" "configs/elk/kibana/kibana.yml" ".env")
    local found_defaults=()
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            if grep -qi "changeme\|password.*admin\|password.*elastic" "$file"; then
                found_defaults+=("$file")
            fi
        fi
    done
    
    if [[ ${#found_defaults[@]} -gt 0 ]]; then
        warn "Default passwords found in: ${found_defaults[*]}"
        info "Consider changing default passwords for production use"
    else
        log "No obvious default passwords found"
    fi
    
    # Check SSL configuration
    if grep -q "xpack.security.http.ssl.enabled: true" configs/elk/elasticsearch/elasticsearch.yml 2>/dev/null; then
        log "SSL is enabled for Elasticsearch"
    else
        info "SSL is disabled (OK for development)"
    fi
}

# ===================================
# Generate Configuration Report
# ===================================

generate_configuration_report() {
    header "📋 GENERATING CONFIGURATION REPORT"
    
    local report_file="config_verification_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Sentinel AK-XL Configuration Verification Report

Generated: $(date)
System: $(uname -a)

## Summary
- ✅ Checks passed: $(($(grep -c "\[✓\]" "$VERIFICATION_LOG"))
- ⚠️  Warnings: $WARNINGS_FOUND  
- ❌ Errors: $ERRORS_FOUND
- 🔧 Fixes applied: $FIXES_APPLIED

## System Information
$(docker --version 2>/dev/null || echo "Docker: Not installed")
$(docker compose version 2>/dev/null || echo "Docker Compose: Not available")
Memory: $(free -h | grep Mem | awk '{print $2}' 2>/dev/null || echo "Unknown")
Disk Space: $(df -h . | tail -1 | awk '{print $4}' 2>/dev/null || echo "Unknown")

## Configuration Files Status
EOF

    # Add file status to report
    local config_files=(
        "docker-compose.yml"
        "docker-compose-wazuh.yml" 
        ".env"
        "configs/elk/elasticsearch/elasticsearch.yml"
        "configs/elk/kibana/kibana.yml"
        "configs/elk/logstash/logstash.yml"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "- ✅ $file" >> "$report_file"
        else
            echo "- ❌ $file (missing)" >> "$report_file"
        fi
    done
    
    echo "" >> "$report_file"
    echo "## Detailed Log" >> "$report_file"
    echo '```' >> "$report_file"
    cat "$VERIFICATION_LOG" >> "$report_file"
    echo '```' >> "$report_file"
    
    log "Configuration report saved: $report_file"
}

# ===================================
# Fix Common Issues
# ===================================

fix_common_issues() {
    header "🔧 FIXING COMMON ISSUES"
    
    # Fix Elasticsearch config if needed
    if [[ -f "configs/elk/elasticsearch/elasticsearch.yml" ]]; then
        if grep -q "cluster.routing.allocation.disk.threshold.enabled" configs/elk/elasticsearch/elasticsearch.yml; then
            warn "Fixing problematic Elasticsearch setting..."
            sed -i 's/cluster.routing.allocation.disk.threshold.enabled/cluster.routing.allocation.disk.threshold_enabled/' configs/elk/elasticsearch/elasticsearch.yml
            log "Fixed: cluster.routing.allocation.disk.threshold_enabled"
            ((FIXES_APPLIED++))
        fi
    fi
    
    # Create missing directories
    local required_dirs=("data" "logs" "data/elasticsearch" "data/kibana" "logs/elasticsearch" "logs/kibana")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "Created directory: $dir"
            ((FIXES_APPLIED++))
        fi
    done
    
    # Create basic .env if missing
    if [[ ! -f ".env" ]]; then
        cat > .env << 'EOF'
# Sentinel AK-XL Environment Configuration
COMPOSE_PROJECT_NAME=sentinel-ak-xl
ES_MEM=2g
KIBANA_MEM=1g
LOGSTASH_MEM=1g
WAZUH_MEM=1g
ELASTIC_PASSWORD=changeme123!
WAZUH_INDEXER_PASSWORD=SecretPassword
EOF
        log "Created basic .env file"
        ((FIXES_APPLIED++))
    fi
}

# ===================================
# Quick Test Function
# ===================================

quick_functional_test() {
    header "🧪 RUNNING QUICK FUNCTIONAL TEST"
    
    info "Testing Docker Compose configuration..."
    if docker compose config >/dev/null 2>&1; then
        log "Docker Compose configuration is valid"
    else
        error "Docker Compose configuration has errors"
        info "Run 'docker compose config' for details"
        return 1
    fi
    
    info "Testing container startup (dry run)..."
    if docker compose up --dry-run >/dev/null 2>&1; then
        log "Container startup test passed"
    else
        warn "Container startup test had issues"
        info "This might be due to missing images - normal on first run"
    fi
    
    return 0
}

# ===================================
# Main Execution
# ===================================

main() {
    echo -e "${CYAN}${BOLD}"
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│         Sentinel AK-XL Configuration Verification      │"
    echo "│                                                         │"
    echo "│  Ensuring your setup works for all team members        │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    
    # Initialize log
    echo "Configuration Verification started at $(date)" > "$VERIFICATION_LOG"
    
    # Run all checks
    verify_project_structure
    check_system_requirements
    check_port_conflicts
    validate_elasticsearch_config
    validate_kibana_config
    validate_docker_compose
    check_configuration_consistency
    check_security_configuration
    
    # Apply fixes
    fix_common_issues
    
    # Run quick test
    quick_functional_test
    
    # Generate report
    generate_configuration_report
    
    # Final summary
    header "📊 VERIFICATION COMPLETE"
    
    if [[ $ERRORS_FOUND -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ VERIFICATION PASSED${NC}"
        echo -e "${GREEN}Your configuration should work for all team members!${NC}"
    else
        echo -e "${RED}${BOLD}❌ VERIFICATION FAILED${NC}"
        echo -e "${RED}Found $ERRORS_FOUND errors that need attention${NC}"
    fi
    
    if [[ $WARNINGS_FOUND -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Found $WARNINGS_FOUND warnings (non-critical)${NC}"
    fi
    
    if [[ $FIXES_APPLIED -gt 0 ]]; then
        echo -e "${BLUE}🔧 Applied $FIXES_APPLIED automatic fixes${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}📋 Next Steps:${NC}"
    echo "1. Review the detailed report: $report_file"
    echo "2. Address any critical errors found"
    echo "3. Test with: docker compose up -d"
    echo "4. Share verification report with team"
    
    if [[ $ERRORS_FOUND -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
