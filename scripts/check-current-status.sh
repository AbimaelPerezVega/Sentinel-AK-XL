#!/bin/bash
# ==============================================================================
# Current Status Check Script
# Verify the exact state of Wazuh-Elasticsearch integration
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${GREEN}========================================"
echo -e "Sentinel AK-XL Status Check"
echo -e "Current Wazuh-Elasticsearch Pipeline"
echo -e "========================================${NC}"

# ==============================================================================
# Check 1: Container Status
# ==============================================================================

echo -e "\n${BLUE}📦 CONTAINER STATUS${NC}"

containers=("sentinel-wazuh-manager" "sentinel-elasticsearch" "sentinel-kibana" "sentinel-logstash" "windows-endpoint-sim-01")

for container in "${containers[@]}"; do
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container"; then
        status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container" | awk '{print $2, $3, $4}')
        log_success "$container: $status"
    else
        log_error "$container: NOT RUNNING"
    fi
done

# ==============================================================================
# Check 2: Current Wazuh Configuration
# ==============================================================================

echo -e "\n${BLUE}⚙️ WAZUH CONFIGURATION${NC}"

log_info "Checking current ossec.conf for Elasticsearch integration..."
if docker exec sentinel-wazuh-manager grep -A 10 -B 2 "integration" /var/ossec/etc/ossec.conf 2>/dev/null; then
    log_success "Integration section found in ossec.conf"
else
    log_warning "NO INTEGRATION SECTION FOUND - This is the problem!"
fi

log_info "Checking Wazuh agent registration..."
agent_count=$(docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -l | grep -c "ID:" || echo "0")
log_info "Registered agents: $agent_count"

if [ "$agent_count" -gt 0 ]; then
    docker exec sentinel-wazuh-manager /var/ossec/bin/manage_agents -l
fi

# ==============================================================================
# Check 3: Elasticsearch Status
# ==============================================================================

echo -e "\n${BLUE}🔍 ELASTICSEARCH STATUS${NC}"

log_info "Checking Elasticsearch cluster health..."
if curl -s "localhost:9200/_cluster/health" | jq -r '.status' 2>/dev/null; then
    log_success "Elasticsearch is responding"
else
    log_error "Elasticsearch is not responding"
fi

log_info "Checking current indices..."
indices=$(curl -s "localhost:9200/_cat/indices?v" | grep -v "^health")
echo "$indices"

wazuh_indices=$(echo "$indices" | grep -i wazuh | wc -l)
if [ "$wazuh_indices" -gt 0 ]; then
    log_success "Found $wazuh_indices Wazuh indices"
else
    log_warning "NO WAZUH INDICES FOUND"
fi

# ==============================================================================
# Check 4: Log Analysis
# ==============================================================================

echo -e "\n${BLUE}📝 LOG ANALYSIS${NC}"

log_info "Checking Wazuh manager logs for errors..."
if docker exec sentinel-wazuh-manager tail -20 /var/ossec/logs/ossec.log | grep -i error; then
    log_warning "Errors found in Wazuh logs"
else
    log_success "No recent errors in Wazuh logs"
fi

log_info "Checking for Sysmon events in simulator..."
if docker exec windows-endpoint-sim-01 tail -5 /var/log/sysmon-simulator.log 2>/dev/null; then
    log_success "Sysmon events are being generated"
else
    log_warning "No Sysmon events found"
fi

log_info "Checking Wazuh alerts..."
if docker exec sentinel-wazuh-manager tail -10 /var/ossec/logs/alerts/alerts.log 2>/dev/null; then
    log_success "Wazuh alerts are being generated"
else
    log_warning "No Wazuh alerts found"
fi

# ==============================================================================
# Check 5: Network Connectivity
# ==============================================================================

echo -e "\n${BLUE}🌐 NETWORK CONNECTIVITY${NC}"

log_info "Testing Wazuh → Elasticsearch connectivity..."
if docker exec sentinel-wazuh-manager curl -s "http://172.20.0.10:9200" > /dev/null 2>&1; then
    log_success "Wazuh can reach Elasticsearch"
else
    log_error "Wazuh CANNOT reach Elasticsearch"
fi

log_info "Testing Logstash connectivity..."
if docker exec sentinel-wazuh-manager nc -zv 172.20.0.12 5044 2>/dev/null; then
    log_success "Wazuh can reach Logstash"
else
    log_warning "Wazuh cannot reach Logstash"
fi

# ==============================================================================
# Check 6: Data Pipeline Test
# ==============================================================================

echo -e "\n${BLUE}🚰 DATA PIPELINE TEST${NC}"

log_info "Searching for recent data in Elasticsearch..."

# Check for any data
total_docs=$(curl -s "localhost:9200/_all/_count" | jq -r '.count' 2>/dev/null || echo "0")
log_info "Total documents in Elasticsearch: $total_docs"

# Check for Wazuh-specific data
wazuh_docs=$(curl -s "localhost:9200/wazuh-*/_count" 2>/dev/null | jq -r '.count' 2>/dev/null || echo "0")
log_info "Wazuh documents: $wazuh_docs"

# Check for today's indices
today=$(date +%Y.%m.%d)
today_indices=$(curl -s "localhost:9200/_cat/indices?v" | grep "$today" | wc -l)
log_info "Indices created today: $today_indices"

# ==============================================================================
# Summary and Recommendations
# ==============================================================================

echo -e "\n${GREEN}📊 DIAGNOSIS SUMMARY${NC}"

if docker exec sentinel-wazuh-manager grep -q "integration" /var/ossec/etc/ossec.conf 2>/dev/null; then
    log_success "Integration configuration: PRESENT"
else
    log_error "Integration configuration: MISSING ← ROOT CAUSE"
fi

if [ "$wazuh_docs" -gt 0 ]; then
    log_success "Data pipeline: WORKING ($wazuh_docs documents)"
else
    log_error "Data pipeline: BROKEN (0 documents)"
fi

echo -e "\n${BLUE}🛠️ RECOMMENDED ACTIONS${NC}"

if ! docker exec sentinel-wazuh-manager grep -q "integration" /var/ossec/etc/ossec.conf 2>/dev/null; then
    echo -e "${YELLOW}1. Run the fix script: ./fix-wazuh-elasticsearch-integration.sh${NC}"
    echo -e "${YELLOW}2. This will add the missing Elasticsearch integration to ossec.conf${NC}"
    echo -e "${YELLOW}3. The integration should start working within 1-2 minutes${NC}"
else
    echo -e "${GREEN}1. Integration is configured - check logs for connection issues${NC}"
    echo -e "${GREEN}2. Verify Elasticsearch is accepting connections${NC}"
    echo -e "${GREEN}3. Check firewall rules if still not working${NC}"
fi

echo -e "\n${GREEN}✅ Status check completed${NC}"
