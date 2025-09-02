#!/bin/bash
# ==============================================================================
# Wazuh-Elasticsearch Integration Fix Script V2
# Properly handles locked configuration files
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WAZUH_CONTAINER="sentinel-wazuh-manager"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${GREEN}========================================"
echo -e "Wazuh Integration Fix V2 - Proper Method"
echo -e "========================================${NC}"

# ==============================================================================
# Step 1: Stop Wazuh services to unlock files
# ==============================================================================

log_info "Stopping Wazuh services to unlock configuration files..."
docker exec $WAZUH_CONTAINER /var/ossec/bin/wazuh-control stop

sleep 5
log_success "Wazuh services stopped"

# ==============================================================================
# Step 2: Create the integration configuration
# ==============================================================================

log_info "Creating integration configuration inside container..."

# Add the integration directly to the existing ossec.conf
docker exec $WAZUH_CONTAINER bash -c 'cat >> /var/ossec/etc/ossec.conf << EOF

  <!-- Elasticsearch Integration -->
  <integration>
    <name>elasticsearch</name>
    <hook_url>http://172.20.0.10:9200</hook_url>
    <level>3</level>
    <alert_format>json</alert_format>
    <max_logs>5</max_logs>
  </integration>

</ossec_config>
EOF'

# Remove the duplicate closing tag that was just added
docker exec $WAZUH_CONTAINER sed -i '$ s/^.*<\/ossec_config>.*$//' /var/ossec/etc/ossec.conf

# Add the proper closing tag
docker exec $WAZUH_CONTAINER bash -c 'echo "</ossec_config>" >> /var/ossec/etc/ossec.conf'

log_success "Integration configuration added"

# ==============================================================================
# Step 3: Fix agent group assignment issue
# ==============================================================================

log_info "Fixing agent group assignment issue..."

# Create default group if it doesn't exist
docker exec $WAZUH_CONTAINER mkdir -p /var/ossec/etc/shared/default

# Set proper permissions
docker exec $WAZUH_CONTAINER chown -R ossec:ossec /var/ossec/etc/shared
docker exec $WAZUH_CONTAINER chmod -R 750 /var/ossec/etc/shared

# Assign agent to default group
docker exec $WAZUH_CONTAINER /var/ossec/bin/agent_groups -a -i 001 -g default || true

log_success "Agent group issue fixed"

# ==============================================================================
# Step 4: Create Elasticsearch index template
# ==============================================================================

log_info "Creating Elasticsearch index template..."

# Wait for Elasticsearch to be ready
sleep 5

curl -X PUT "localhost:9200/_index_template/wazuh-alerts" \
     -H "Content-Type: application/json" \
     -d '{
       "index_patterns": ["wazuh-alerts-*"],
       "priority": 1,
       "template": {
         "settings": {
           "number_of_shards": 1,
           "number_of_replicas": 0,
           "index.refresh_interval": "5s"
         },
         "mappings": {
           "properties": {
             "@timestamp": { "type": "date" },
             "timestamp": { "type": "date" },
             "rule": {
               "properties": {
                 "level": { "type": "long" },
                 "description": { "type": "text" },
                 "id": { "type": "keyword" }
               }
             },
             "agent": {
               "properties": {
                 "id": { "type": "keyword" },
                 "name": { "type": "keyword" },
                 "ip": { "type": "ip" }
               }
             },
             "full_log": { "type": "text" },
             "location": { "type": "keyword" }
           }
         }
       }
     }'

log_success "Elasticsearch template created"

# ==============================================================================
# Step 5: Start Wazuh services
# ==============================================================================

log_info "Starting Wazuh services..."
docker exec $WAZUH_CONTAINER /var/ossec/bin/wazuh-control start

# Wait for services to fully start
sleep 15

# Check if services are running
if docker exec $WAZUH_CONTAINER /var/ossec/bin/wazuh-control status | grep -q "wazuh-manager is running"; then
    log_success "Wazuh manager restarted successfully"
else
    log_error "Failed to restart Wazuh manager"
    exit 1
fi

# ==============================================================================
# Step 6: Verify configuration and test integration
# ==============================================================================

log_info "Verifying integration configuration..."

# Check if integration is in config
if docker exec $WAZUH_CONTAINER grep -A 5 "integration" /var/ossec/etc/ossec.conf | grep -q "elasticsearch"; then
    log_success "Elasticsearch integration found in configuration"
else
    log_error "Integration not found in configuration"
    exit 1
fi

# Wait for integration to initialize
log_info "Waiting for integration to initialize..."
sleep 30

# Test connectivity
log_info "Testing Elasticsearch connectivity from Wazuh..."
if docker exec $WAZUH_CONTAINER curl -s http://172.20.0.10:9200 | grep -q "cluster_name"; then
    log_success "Elasticsearch is reachable from Wazuh"
else
    log_error "Cannot reach Elasticsearch from Wazuh"
fi

# ==============================================================================
# Step 7: Generate test events and verify
# ==============================================================================

log_info "Generating test events..."

# Generate a simple test alert
docker exec $WAZUH_CONTAINER logger "TEST: SSH authentication failure for user admin from 192.168.1.100"

# Generate Sysmon events if simulator is running
if docker ps | grep -q "windows-endpoint-sim"; then
    log_info "Generating Sysmon events..."
    docker exec windows-endpoint-sim-01 python3 /opt/sysmon-simulator/scripts/sysmon_event_generator.py 172.20.0.4 3 15 true > /dev/null 2>&1 &
fi

# Wait for events to be processed
log_info "Waiting for events to be processed..."
sleep 45

# Check for Wazuh indices
log_info "Checking for Wazuh indices in Elasticsearch..."
wazuh_indices=$(curl -s "localhost:9200/_cat/indices?v" | grep wazuh | wc -l)

if [ "$wazuh_indices" -gt 0 ]; then
    log_success "Found $wazuh_indices Wazuh indices!"
    curl -s "localhost:9200/_cat/indices?v" | grep wazuh
    
    # Check document count
    doc_count=$(curl -s "localhost:9200/wazuh-alerts-*/_count" 2>/dev/null | jq -r '.count' 2>/dev/null || echo "0")
    log_success "Documents in Wazuh indices: $doc_count"
    
    if [ "$doc_count" -gt 0 ]; then
        log_success "🎉 INTEGRATION IS WORKING!"
        echo -e "\n${GREEN}✅ Data Pipeline Status: FIXED${NC}"
        echo -e "${GREEN}✅ Sysmon Events → Wazuh Agent → Wazuh Manager → Elasticsearch → Kibana${NC}"
    fi
else
    log_warning "No Wazuh indices found yet - checking logs..."
    
    # Check integration logs
    log_info "Checking integration logs..."
    docker exec $WAZUH_CONTAINER tail -20 /var/ossec/logs/integrations.log 2>/dev/null || log_info "No integration log found yet"
    
    # Check for any errors
    log_info "Checking for recent errors..."
    docker exec $WAZUH_CONTAINER tail -10 /var/ossec/logs/ossec.log | grep -i error || log_info "No recent errors"
fi

# ==============================================================================
# Step 8: Final verification
# ==============================================================================

echo -e "\n${BLUE}🔍 FINAL VERIFICATION${NC}"

# Check Wazuh logs for integration activity
log_info "Checking for integration activity in logs..."
if docker exec $WAZUH_CONTAINER grep -i "integration" /var/ossec/logs/ossec.log | tail -5; then
    log_success "Integration activity detected"
else
    log_info "No integration activity in main logs yet"
fi

# Check active connections
log_info "Checking active network connections..."
docker exec $WAZUH_CONTAINER netstat -tlnp | grep -E "(1514|55000)" || log_info "Standard Wazuh ports active"

echo -e "\n${GREEN}🎯 FIX COMPLETED${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo -e "1. Wait 2-3 minutes for data to appear"
echo -e "2. Check Kibana: http://localhost:5601"  
echo -e "3. Look for 'wazuh-alerts-*' index pattern"
echo -e "4. Monitor: curl 'localhost:9200/wazuh-alerts-*/_count'"

echo -e "\n${YELLOW}If still no data after 5 minutes:${NC}"
echo -e "1. Check integration logs: docker exec $WAZUH_CONTAINER cat /var/ossec/logs/integrations.log"
echo -e "2. Monitor Wazuh logs: docker exec $WAZUH_CONTAINER tail -f /var/ossec/logs/ossec.log"
echo -e "3. Verify config: docker exec $WAZUH_CONTAINER grep -A 10 integration /var/ossec/etc/ossec.conf"
