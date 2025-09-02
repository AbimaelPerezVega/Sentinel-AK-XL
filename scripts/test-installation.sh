#!/bin/bash

# ===================================
# Sentinel AK-XL: Installation Tester
# ===================================
# Comprehensive testing script for verifying installation
# ===================================

# Stop on any error
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0
COMPOSE_CMD=""

# ===================================
# Test Utility Functions
# ===================================

test_start() {
    ((TESTS_TOTAL++))
    echo -e "${BLUE}[TEST $TESTS_TOTAL]${NC} $1"
}

test_pass() {
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✅ PASS:${NC} $1"
}

test_fail() {
    ((TESTS_FAILED++))
    echo -e "  ${RED}❌ FAIL:${NC} $1"
}

test_warn() {
    echo -e "  ${YELLOW}⚠️  WARN:${NC} $1"
}

wait_for_service() {
    local service_name="$1"
    local url="$2"
    local max_wait="${3:-120}"
    local wait_time=0

    echo -n "  Waiting for $service_name to respond..."

    while [[ $wait_time -lt $max_wait ]]; do
        if curl -s --fail "$url" >/dev/null 2>&1; then
            echo " responded in ${wait_time}s."
            return 0
        fi

        sleep 5
        wait_time=$((wait_time + 5))
    done

    echo " timed out after ${max_wait}s."
    return 1
}

header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN} $1 ${NC}"
    echo -e "${CYAN}================================================${NC}"
}

# ===================================
# Pre-flight Tests
# ===================================

test_prerequisites() {
    header "🔍 TESTING PREREQUISITES"

    test_start "Docker installation check"
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        test_pass "Docker $docker_version found"
    else
        test_fail "Docker not installed"
        return 1
    fi

    test_start "Docker daemon status"
    if docker info &> /dev/null; then
        test_pass "Docker daemon is running"
    else
        test_fail "Docker daemon not running"
        return 1
    fi

    test_start "Docker Compose availability (FIXED: Prioritize v2)"
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        test_pass "Docker Compose v2 found and selected"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        test_warn "Docker Compose v1 found. Compatibility issues may arise."
    else
        test_fail "Docker Compose not found"
        return 1
    fi
    export COMPOSE_CMD

    test_start "Required files presence"
    local required_files=(
        "docker-compose.yml"
        "configs/elk/elasticsearch/elasticsearch.yml"
        "configs/elk/kibana/kibana.yml"
    )

    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done

    if [[ ${#missing_files[@]} -eq 0 ]]; then
        test_pass "All required configuration files present"
    else
        test_fail "Missing files: ${missing_files[*]}"
        return 1
    fi
    return 0
}


# ===================================
# Service Tests
# ===================================

test_service_startup() {
    header "🚀 TESTING SERVICE STARTUP"

    test_start "Cleaning previous installation"
    $COMPOSE_CMD down -v --remove-orphans &> /dev/null || true
    test_pass "Previous containers and volumes removed"

    test_start "Starting all services"
    if $COMPOSE_CMD up -d &> /dev/null; then
        test_pass "docker compose up command executed successfully"
    else
        test_fail "docker compose up command failed. See logs:"
        $COMPOSE_CMD logs --tail 20
        return 1
    fi

    test_start "Elasticsearch health check"
    if wait_for_service "Elasticsearch" "http://localhost:9200" 120; then
        local es_health=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
        if [[ "$es_health" == "green" || "$es_health" == "yellow" ]]; then
            test_pass "Elasticsearch cluster status is '$es_health'"
        else
            test_fail "Elasticsearch cluster status is '$es_health'"
        fi
    else
        test_fail "Elasticsearch did not start correctly"
        echo "Elasticsearch logs:"
        $COMPOSE_CMD logs --tail 20 elasticsearch
        return 1
    fi

    test_start "Kibana health check"
    if wait_for_service "Kibana" "http://localhost:5601/api/status" 180; then
        local kibana_status=$(curl -s http://localhost:5601/api/status | grep -o '"overall":{"level":"[^"]*"' | cut -d'"' -f6 2>/dev/null || echo "unknown")
        if [[ "$kibana_status" == "available" ]]; then
             test_pass "Kibana status is '$kibana_status'"
        else
            test_warn "Kibana status is '$kibana_status'. It may still be initializing."
        fi
    else
        test_fail "Kibana did not start correctly"
        echo "Kibana logs:"
        $COMPOSE_CMD logs --tail 20 kibana
        return 1
    fi
}

# ===================================
# Functionality Tests
# ===================================

test_functionality() {
    header "🧪 TESTING FUNCTIONALITY"

    test_start "Creating test index in Elasticsearch"
    local index_response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "localhost:9200/sentinel-test-index")
    if [[ "$index_response" == "200" ]]; then
        test_pass "Test index created successfully (HTTP 200)"
    else
        test_fail "Failed to create test index (HTTP $index_response)"
    fi

    test_start "Indexing a test document"
    local doc_response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "localhost:9200/sentinel-test-index/_doc" -H 'Content-Type: application/json' -d'
    {
      "message": "Sentinel AK-XL functionality test",
      "level": "info"
    }')
    if [[ "$doc_response" == "201" ]]; then
        test_pass "Test document indexed successfully (HTTP 201)"
    else
        test_fail "Failed to index test document (HTTP $doc_response)"
    fi

    test_start "Searching for the test document"
    # Wait for index refresh
    sleep 2
    local search_response=$(curl -s -X GET "localhost:9200/sentinel-test-index/_search?q=functionality")
    if echo "$search_response" | grep -q '"total":{"value":1'; then
        test_pass "Test document found via search API"
    else
        test_fail "Test document not found via search API"
    fi

    # Cleanup
    curl -s -X DELETE "localhost:9200/sentinel-test-index" > /dev/null
}


# ===================================
# Summary
# ===================================

summarize_results() {
    header "📊 TEST SUMMARY"
    echo -e "Total tests run: ${BLUE}$TESTS_TOTAL${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
        echo -e "Your Sentinel ELK Stack installation is working correctly."
        echo ""
        echo -e "${CYAN}Access URLs:${NC}"
        echo -e "• Elasticsearch: ${YELLOW}http://localhost:9200${NC}"
        echo -e "• Kibana:        ${YELLOW}http://localhost:5601${NC}"
    else
        echo -e "${RED}❌ SOME TESTS FAILED.${NC}"
        echo -e "Please review the errors above to diagnose the issue."
        echo "Helpful commands:"
        echo "• View logs for a service: $COMPOSE_CMD logs <service_name>"
        echo "• Check container status: docker ps -a"
        exit 1
    fi
}

# ===================================
# Main Execution
# ===================================
main() {
    # Display banner
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                SENTINEL AK-XL INSTALLATION TESTER               ║"
    echo "║              Comprehensive ELK Stack Validation                 ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if ! test_prerequisites; then
        echo -e "\n${RED}Prerequisite checks failed. Cannot continue testing.${NC}"
        exit 1
    fi

    if ! test_service_startup; then
        echo -e "\n${RED}Service startup failed. Cannot continue with functionality tests.${NC}"
        exit 1
    fi

    test_functionality
    summarize_results
}

# Run main function
main "$@"
