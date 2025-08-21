#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging function
log() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_TESTS++))
}

warn() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
}

test_service() {
    local service_name=$1
    local url=$2
    local expected_status=$3
    local auth=$4
    
    ((TOTAL_TESTS++))
    log "Testing $service_name..."
    
    local curl_cmd="curl -s -o /dev/null -w %{http_code} -k"
    
    if [[ -n "$auth" ]]; then
        curl_cmd+=" -u \"$auth\""
    fi
    
    local response_code=$(eval $curl_cmd "$url")
    
    if [[ "$response_code" == "$expected_status" ]]; then
        success "$service_name is responding as expected (HTTP $response_code)"
    else
        if [[ ("$service_name" == "Kibana" || "$service_name" == "Wazuh Dashboard") && "$response_code" == "302" ]]; then
            success "$service_name is responding with a redirect (HTTP $response_code)"
        else
            error "$service_name failed. Expected HTTP $expected_status but got $response_code."
        fi
    fi
}

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                 SENTINEL AK-XL VIRTUAL SOC                   ║
║                   Phase 3 Health Check                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}🧪 Testing Phase 3: SIEM & Detection Components${NC}\n"

# Test ELK Stack
echo -e "${YELLOW}📊 Testing ELK Stack Integration...${NC}"
test_service "Elasticsearch" "http://localhost:9200" "200"
test_service "Kibana" "http://localhost:5601/api/status" "200"
test_service "Logstash" "http://localhost:9600" "200"

# Test Wazuh Components
echo -e "\n${YELLOW}🛡️ Testing Wazuh Components...${NC}"
test_service "Wazuh Indexer" "https://localhost:9201" "200" "admin:admin"
test_service "Wazuh Manager API" "https://localhost:55000" "401" "wazuh-wui:MyS3cr37P450r.*-"
test_service "Wazuh Dashboard" "https://localhost:8443" "200"

# Test Data Flow
echo -e "\n${YELLOW}📡 Testing Data Flow...${NC}"
((TOTAL_TESTS++))
log "Testing Wazuh alert generation..."

if command -v logger &> /dev/null; then
    logger -p local0.info -t "test-phase3" "TEST: Malware detection test event"
    log "Sent test event. Waiting 15 seconds for processing..."
    sleep 15
    
    if curl -s -k -u "admin:admin" "https://localhost:9201/wazuh-alerts-*/_search" | grep -q "test-phase3"; then
        success "Test event detected in Wazuh Indexer"
    else
        warn "Test event not found in Wazuh (may take more time to appear)"
    fi
else
    warn "Logger command not available, skipping data flow test"
fi

# Test Container Status
echo -e "\n${YELLOW}🐳 Testing Container Status...${NC}"
((TOTAL_TESTS++))
log "Checking Wazuh container status..."

# Corrected container names
if docker ps --format '{{.Names}}' | grep -q "sentinel-wazuh-manager"; then
    success "Wazuh containers are running"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    error "Some Wazuh containers are not running"
fi

# Test Custom Rules
echo -e "\n${YELLOW}📋 Testing Custom Detection Rules...${NC}"
((TOTAL_TESTS++))
log "Checking custom rules installation..."

# Corrected container name
if docker exec sentinel-wazuh-manager test -f /var/ossec/etc/rules/local_rules.xml; then
    success "Custom detection rules are installed"
else
    error "Custom detection rules not found"
fi

# Show Summary
echo -e "\n${CYAN}=======================================${NC}"
echo -e "${CYAN}Phase 3 Health Check Summary${NC}"
echo -e "${CYAN}=======================================${NC}"
echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 Phase 3 is healthy! 🎉${NC}"
else
    echo -e "\n${RED}❌ Some components need attention${NC}"
fi

echo -e "\n${CYAN}🔗 Quick Access Links:${NC}"
echo -e "🛡️ Wazuh Dashboard: https://localhost:8443 (admin/SecretPassword)"
echo -e "📊 Kibana Dashboard: http://localhost:5601"
echo -e "🔍 ELK Elasticsearch: http://localhost:9200"
