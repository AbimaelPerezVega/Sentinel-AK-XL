#!/bin/bash

# ===================================
# Sentinel AK-XL Team Validation Script
# ===================================
# Quick validation script for team members to test installation
# Run this AFTER cloning the repository
# ===================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Sentinel AK-XL Team Validation Script${NC}"
echo "================================================"
echo "This script tests if the project setup works correctly"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

test_step() {
    echo -n "Testing: $1 ... "
}

test_pass() {
    echo -e "${GREEN}✅ PASS${NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}❌ FAIL${NC}"
    if [[ -n "$1" ]]; then
        echo -e "   ${RED}Error: $1${NC}"
    fi
    ((TESTS_FAILED++))
}

test_warn() {
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    if [[ -n "$1" ]]; then
        echo -e "   ${YELLOW}Warning: $1${NC}"
    fi
}

# ===================================
# Basic Environment Tests
# ===================================

echo -e "\n${BLUE}📋 TESTING BASIC ENVIRONMENT${NC}"

# Test 1: Docker availability
test_step "Docker availability"
if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    test_pass
else
    test_fail "Docker not installed or not running"
fi

# Test 2: Docker Compose availability  
test_step "Docker Compose availability"
if docker compose version >/dev/null 2>&1; then
    test_pass
elif command -v docker-compose >/dev/null; then
    test_warn "Using legacy docker-compose (works but outdated)"
    ((TESTS_PASSED++))
else
    test_fail "Docker Compose not available"
fi

# Test 3: System resources
test_step "System memory (8GB+ recommended)"
if command -v free >/dev/null; then
    mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $mem_gb -ge 8 ]]; then
        test_pass
    elif [[ $mem_gb -ge 4 ]]; then
        test_warn "Only ${mem_gb}GB available (minimum, may need tuning)"
        ((TESTS_PASSED++))
    else
        test_fail "Only ${mem_gb}GB available (insufficient)"
    fi
else
    test_warn "Cannot check memory (assuming adequate)"
    ((TESTS_PASSED++))
fi

# Test 4: Disk space
test_step "Disk space (20GB+ required)"
available_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
if [[ $available_gb -ge 20 ]]; then
    test_pass
else
    test_fail "Only ${available_gb}GB available"
fi

# ===================================
# Project Structure Tests
# ===================================

echo -e "\n${BLUE}📁 TESTING PROJECT STRUCTURE${NC}"

# Test 5: Essential files
test_step "Core project files"
missing_files=()
required_files=("docker-compose.yml" "README.md" "configs/elk/elasticsearch/elasticsearch.yml" "configs/elk/kibana/kibana.yml")

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -eq 0 ]]; then
    test_pass
else
    test_fail "Missing files: ${missing_files[*]}"
fi

# Check if Wazuh is integrated in main compose file
test_step "Wazuh integration check"
if [[ -f "docker-compose-wazuh.yml" ]]; then
    test_pass
    echo "   Using separate Wazuh compose file"
elif grep -q "wazuh" "docker-compose.yml" 2>/dev/null; then
    test_pass  
    echo "   Wazuh integrated in main compose file"
else
    test_warn "No Wazuh configuration found"
    ((TESTS_PASSED++))
fi

# Test 6: Configuration directories
test_step "Configuration directories"
missing_dirs=()
required_dirs=("configs/elk/elasticsearch" "configs/elk/kibana" "configs/elk/logstash")

for dir in "${required_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
        missing_dirs+=("$dir")
    fi
done

if [[ ${#missing_dirs[@]} -eq 0 ]]; then
    test_pass
else
    test_fail "Missing directories: ${missing_dirs[*]}"
fi

# ===================================
# Configuration Validation Tests
# ===================================

echo -e "\n${BLUE}⚙️ TESTING CONFIGURATION FILES${NC}"

# Test 7: Docker Compose syntax
test_step "Docker Compose syntax validation"
if docker compose config >/dev/null 2>&1; then
    test_pass
else
    test_fail "Invalid docker-compose.yml syntax"
fi

# Test Wazuh compose file if it exists separately
if [[ -f "docker-compose-wazuh.yml" ]]; then
    test_step "Wazuh Docker Compose syntax"
    if docker compose -f docker-compose-wazuh.yml config >/dev/null 2>&1; then
        test_pass
    else
        test_fail "Invalid docker-compose-wazuh.yml syntax"
    fi
fi

# Test 8: Elasticsearch configuration
test_step "Elasticsearch configuration"
es_config="configs/elk/elasticsearch/elasticsearch.yml"
if [[ -f "$es_config" ]]; then
    if grep -q "cluster.routing.allocation.disk.threshold.enabled" "$es_config"; then
        test_fail "Found problematic setting (should use underscore not dots)"
    elif grep -q "cluster.name\|node.name" "$es_config"; then
        test_pass
    else
        test_warn "Basic settings found but configuration may be incomplete"
        ((TESTS_PASSED++))
    fi
else
    test_fail "Elasticsearch configuration file missing"
fi

# Test 9: Kibana configuration
test_step "Kibana configuration"
kibana_config="configs/elk/kibana/kibana.yml"
if [[ -f "$kibana_config" ]]; then
    if grep -q "elasticsearch.hosts" "$kibana_config"; then
        test_pass
    else
        test_warn "Elasticsearch hosts not configured in Kibana"
        ((TESTS_PASSED++))
    fi
else
    test_fail "Kibana configuration file missing"
fi

# ===================================
# Port Availability Tests
# ===================================

echo -e "\n${BLUE}🔌 TESTING PORT AVAILABILITY${NC}"

# Test 10: Port conflicts
test_step "Port availability (9200, 5601, 55000)"
required_ports=(9200 5601 55000)
conflicting_ports=()

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
    test_pass
else
    test_warn "Ports in use: ${conflicting_ports[*]} (services may fail to start)"
    ((TESTS_PASSED++))
fi

# ===================================
# Functional Tests
# ===================================

echo -e "\n${BLUE}🧪 TESTING FUNCTIONALITY${NC}"

# Test 11: Container images availability
test_step "Docker image availability"
if docker compose pull >/dev/null 2>&1; then
    test_pass
else
    test_warn "Some images may need to be downloaded on first run"
    ((TESTS_PASSED++))
fi

# Test 12: Quick startup test (dry run)
test_step "Container startup validation"
if docker compose up --dry-run >/dev/null 2>&1; then
    test_pass
else
    test_fail "Container configuration has issues"
fi

# ===================================
# Optional Integration Test
# ===================================

echo -e "\n${BLUE}🚀 OPTIONAL: QUICK INTEGRATION TEST${NC}"
echo "This will start Elasticsearch briefly to test connectivity..."
read -p "Run integration test? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting Elasticsearch for integration test..."
    
    # Start only Elasticsearch
    docker compose up -d elasticsearch >/dev/null 2>&1
    
    # Wait and test
    echo -n "Waiting for Elasticsearch to start"
    for i in {1..12}; do
        echo -n "."
        sleep 5
        if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
            echo ""
            test_step "Elasticsearch connectivity"
            test_pass
            break
        fi
    done
    
    if [[ $i -eq 12 ]]; then
        echo ""
        test_step "Elasticsearch connectivity"
        test_fail "Elasticsearch failed to start within 60 seconds"
    fi
    
    # Cleanup
    echo "Cleaning up test containers..."
    docker compose down >/dev/null 2>&1
else
    echo "Skipping integration test"
fi

# ===================================
# Results Summary
# ===================================

echo -e "\n${BLUE}📊 VALIDATION RESULTS${NC}"
echo "================================================"

total_tests=$((TESTS_PASSED + TESTS_FAILED))
echo "Total tests: $total_tests"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}The project setup should work correctly.${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Start the full stack: docker compose up -d"
    if [[ -f "docker-compose-wazuh.yml" ]]; then
        echo "2. Start Wazuh: docker compose -f docker-compose-wazuh.yml up -d"
        echo "3. Access Kibana: http://localhost:5601"
        echo "4. Access Elasticsearch: http://localhost:9200"
        echo "5. Access Wazuh: http://localhost:55000"
    else
        echo "2. Access Kibana: http://localhost:5601"
        echo "3. Access Elasticsearch: http://localhost:9200"
        echo "4. Access Wazuh: http://localhost:55000 (if integrated)"
    fi
    exit 0
else
    echo ""
    echo -e "${RED}❌ VALIDATION FAILED${NC}"
    echo -e "${RED}Found $TESTS_FAILED issues that need to be resolved.${NC}"
    echo ""
    echo -e "${YELLOW}Common solutions:${NC}"
    echo "• Install Docker and Docker Compose"
    echo "• Free up system resources"
    echo "• Check project file structure"
    echo "• Review configuration files"
    echo "• Stop conflicting services"
    echo ""
    echo -e "${BLUE}For detailed troubleshooting:${NC}"
    echo "• Check README.md for requirements"
    echo "• Run: docker compose config (to check syntax)"
    echo "• Run: docker compose logs (to see error details)"
    exit 1
fi
