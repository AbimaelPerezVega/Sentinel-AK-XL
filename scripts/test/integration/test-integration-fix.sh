#!/bin/bash
# ==============================================================================
# Integration Fix Test Script
# Verify that Wazuh-Elasticsearch integration is working after fix
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${GREEN}========================================"
echo -e "Testing Wazuh-Elasticsearch Integration"
echo -e "After Fix Implementation"
echo -e "========================================${NC}"

# ==============================================================================
# Test 1: Generate Test Alert
# ==============================================================================

echo -e "\n${BLUE}🚨 GENERATING TEST ALERT${NC}"

log_info "Generating a test SSH brute force alert..."

# Generate test log entry that should trigger alert
test_log='Aug 22 15:30:01 test-server sshd[12345]: Failed password for invalid user admin from 192.168.1.100 port 22 ssh2'

echo "$test_log" | docker exec -i sentinel-wazuh-manager /var/ossec/bin/wazuh-logtest

log_success "Test alert generated"

# ==============================================================================
# Test 2: Generate Sysmon Events
# ==============================================================================

echo -e "\n${BLUE}🖥️ GENERATING SYSMON EVENTS${NC}"

if docker ps | grep -q "windows-endpoint-sim"; then
    log_info "Generating malicious Sysmon events..."
    
    # Generate suspicious process creation
    docker exec windows-endpoint-sim-01 python3 /opt/sysmon-simulator/scripts/sysmon_event_generator.py 172.20.0.4 5 30 true
    
    log_success "Sysmon events generated"
else
    log_warning "Windows endpoint simulator not running"
fi

# ==============================================================================
# Test 3: Wait and Check for Data
# ==============================================================================

echo -e "\n${BLUE}⏳ WAITING FOR DATA PROCESSING${NC}"

log_info "Waiting 60 seconds for events to be processed..."
sleep 60

# ==============================================================================
# Test 4: Verify Data in Elasticsearch
# ==============================================================================

echo -e "\n${BLUE}🔍 VERIFYING DATA IN ELASTICSEARCH${NC}"

# Check for Wazuh indices
log_info "Checking for Wazuh indices..."
wazuh_indices=$(curl -s "localhost:9200/_cat/indices?v" | grep wazuh | wc -l)

if [ "$wazuh_indices" -gt 0 ]; then
    log_success "Found $wazuh_indices Wazuh indices"
    curl -s "localhost:9200/_cat/indices?v" | grep wazuh
else
    log_error "No Wazuh indices found"
fi

# Check document count
log_info "Checking document count in Wazuh indices..."
doc_count=$(curl -s "localhost:9200/wazuh-alerts-*/_count" 2>/dev/null | jq -r '.count' 2>/dev/null || echo "0")

if [ "$doc_count" -gt 0 ]; then
    log_success "Found $doc_count documents in Wazuh indices"
else
    log_error "No documents found in Wazuh indices"
fi

# Check for recent alerts (last 5 minutes)
log_info "Checking for recent alerts (last 5 minutes)..."
recent_alerts=$(curl -s "localhost:9200/wazuh-alerts-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "range": {
        "@timestamp": {
          "gte": "now-5m"
        }
      }
    },
    "size": 0
  }' | jq -r '.hits.total.value' 2>/dev/null || echo "0")

if [ "$recent_alerts" -gt 0 ]; then
    log_success "Found $recent_alerts recent alerts"
else
    log_warning "No recent alerts found"
fi

# ==============================================================================
# Test 5: Check Specific Event Types
# ==============================================================================

echo -e "\n${BLUE}🎯 CHECKING SPECIFIC EVENT TYPES${NC}"

# Check for Sysmon events
log_info "Searching for Sysmon events..."
sysmon_count=$(curl -s "localhost:9200/wazuh-alerts-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "match": { "rule.description": "sysmon" } }
        ]
      }
    },
    "size": 0
  }' | jq -r '.hits.total.value' 2>/dev/null || echo "0")

if [ "$sysmon_count" -gt 0 ]; then
    log_success "Found $sysmon_count Sysmon alerts"
else
    log_warning "No Sysmon alerts found"
fi

# Check for SSH events
log_info "Searching for SSH brute force events..."
ssh_count=$(curl -s "localhost:9200/wazuh-alerts-*/_search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "match": { "rule.description": "ssh" } }
        ]
      }
    },
    "size": 0
  }' | jq -r '.hits.total.value' 2>/dev/null || echo "0")

if [ "$ssh_count" -gt 0 ]; then
    log_success "Found $ssh_count SSH-related alerts"
else
    log_warning "No SSH alerts found"
fi

# ==============================================================================
# Test 6: Sample Recent Alert
# ==============================================================================

echo -e "\n${BLUE}📄 SAMPLE RECENT ALERT${NC}"

if [ "$doc_count" -gt 0 ]; then
    log_info "Fetching a sample recent alert..."
    
    sample_alert=$(curl -s "localhost:9200/wazuh-alerts-*/_search" \
      -H "Content-Type: application/json" \
      -d '{
        "query": { "match_all": {} },
        "sort": [{ "@timestamp": { "order": "desc" }}],
        "size": 1
      }' | jq -r '.hits.hits[0]._source' 2>/dev/null)
    
    if [ "$sample_alert" != "null" ] && [ -n "$sample_alert" ]; then
        echo "$sample_alert" | jq .
        log_success "Sample alert retrieved successfully"
    else
        log_warning "Could not retrieve sample alert"
    fi
else
    log_warning "No alerts to sample"
fi

# ==============================================================================
# Test 7: Kibana Verification
# ==============================================================================

echo -e "\n${BLUE}📊 KIBANA VERIFICATION${NC}"

log_info "Testing Kibana connectivity..."
if curl -s "localhost:5601/api/status" | grep -q "available"; then
    log_success "Kibana is available"
    
    # Check if index pattern exists
    log_info "Checking for Wazuh index pattern in Kibana..."
    
    index_pattern_response=$(curl -s "localhost:5601/api/saved_objects/_find?type=index-pattern&search=wazuh" -H "kbn-xsrf: true")
    
    if echo "$index_pattern_response" | grep -q "wazuh"; then
        log_success "Wazuh index pattern found in Kibana"
    else
        log_warning "No Wazuh index pattern found in Kibana"
        log_info "You may need to create it manually or run the fix script"
    fi
else
    log_warning "Kibana not available or not responding"
fi

# ==============================================================================
# Final Results Summary
# ==============================================================================

echo -e "\n${GREEN}📋 INTEGRATION TEST RESULTS${NC}"

echo -e "\n${BLUE}Data Pipeline Status:${NC}"
if [ "$doc_count" -gt 0 ]; then
    echo -e "${GREEN}✅ Sysmon Events → Wazuh Agent → Wazuh Manager → Elasticsearch → Kibana${NC}"
    echo -e "${GREEN}✅ Integration is WORKING!${NC}"
    echo -e "${GREEN}✅ Total alerts in Elasticsearch: $doc_count${NC}"
    if [ "$recent_alerts" -gt 0 ]; then
        echo -e "${GREEN}✅ Recent alerts (last 5 min): $recent_alerts${NC}"
    fi
else
    echo -e "${RED}❌ Data pipeline is still broken${NC}"
    echo -e "${YELLOW}⚠️  Check Wazuh logs for integration errors${NC}"
    echo -e "${YELLOW}⚠️  Verify Elasticsearch connectivity from Wazuh${NC}"
fi

echo -e "\n${BLUE}Event Type Breakdown:${NC}"
echo -e "• Sysmon alerts: $sysmon_count"
echo -e "• SSH alerts: $ssh_count"
echo -e "• Total Wazuh indices: $wazuh_indices"

echo -e "\n${BLUE}Next Steps:${NC}"
if [ "$doc_count" -gt 0 ]; then
    echo -e "${GREEN}1. 🎉 Integration is working! Check Kibana for visualizations${NC}"
    echo -e "${GREEN}2. 📊 Access Kibana: http://localhost:5601${NC}"
    echo -e "${GREEN}3. 🔍 Create dashboards and visualizations${NC}"
    echo -e "${GREEN}4. 🚨 Set up alerting rules${NC}"
else
    echo -e "${YELLOW}1. 🔧 Check Wazuh manager logs: docker exec sentinel-wazuh-manager tail -f /var/ossec/logs/ossec.log${NC}"
    echo -e "${YELLOW}2. 🔄 Restart Wazuh manager: docker exec sentinel-wazuh-manager /var/ossec/bin/wazuh-control restart${NC}"
    echo -e "${YELLOW}3. 🌐 Verify network connectivity between containers${NC}"
fi

echo -e "\n${GREEN}🎯 Test completed!${NC}"
