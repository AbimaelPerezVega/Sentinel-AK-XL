#!/bin/bash
# ==============================================================================
# Wazuh Integration Monitoring Script
# Continuously monitor the integration status
# ==============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"; }

echo -e "${GREEN}========================================"
echo -e "Wazuh Integration Monitor"
echo -e "Press Ctrl+C to stop"
echo -e "========================================${NC}"

monitor_count=0

while true; do
    monitor_count=$((monitor_count + 1))
    
    echo -e "\n${BLUE}--- Check #$monitor_count ---${NC}"
    
    # Check for Wazuh indices
    wazuh_indices=$(curl -s "localhost:9200/_cat/indices?v" 2>/dev/null | grep wazuh | wc -l)
    
    if [ "$wazuh_indices" -gt 0 ]; then
        # Check document count
        doc_count=$(curl -s "localhost:9200/wazuh-alerts-*/_count" 2>/dev/null | jq -r '.count' 2>/dev/null || echo "0")
        
        if [ "$doc_count" -gt 0 ]; then
            log_success "🎉 INTEGRATION WORKING! Indices: $wazuh_indices, Documents: $doc_count"
            
            # Show recent alerts
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
            
            log_success "Recent alerts (last 5 min): $recent_alerts"
            
            # Sample latest alert
            if [ "$recent_alerts" -gt 0 ]; then
                echo -e "\n${BLUE}Latest alert sample:${NC}"
                curl -s "localhost:9200/wazuh-alerts-*/_search" \
                  -H "Content-Type: application/json" \
                  -d '{
                    "query": { "match_all": {} },
                    "sort": [{ "@timestamp": { "order": "desc" }}],
                    "size": 1
                  }' | jq -r '.hits.hits[0]._source | {timestamp, rule: .rule.description, agent: .agent.name, level: .rule.level}' 2>/dev/null
            fi
            
            echo -e "\n${GREEN}✅ Integration is working! You can stop monitoring.${NC}"
            break
        else
            log_warning "Indices found but no documents yet: $wazuh_indices indices"
        fi
    else
        log_info "No Wazuh indices found yet... waiting"
    fi
    
    # Check Wazuh logs for integration activity
    integration_logs=$(docker exec sentinel-wazuh-manager grep -c "integration" /var/ossec/logs/ossec.log 2>/dev/null || echo "0")
    log_info "Integration log entries: $integration_logs"
    
    # Check for errors
    recent_errors=$(docker exec sentinel-wazuh-manager tail -5 /var/ossec/logs/ossec.log 2>/dev/null | grep -i error | wc -l)
    if [ "$recent_errors" -gt 0 ]; then
        log_warning "Recent errors detected: $recent_errors"
    fi
    
    # Wait before next check
    sleep 30
    
    # Stop after 20 checks (10 minutes)
    if [ "$monitor_count" -ge 20 ]; then
        echo -e "\n${YELLOW}Monitoring timeout reached. Check logs manually:${NC}"
        echo -e "docker exec sentinel-wazuh-manager tail -f /var/ossec/logs/ossec.log"
        break
    fi
done
