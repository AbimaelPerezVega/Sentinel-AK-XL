#!/bin/bash
# Monitor Sysmon simulation health

echo "=== Sysmon Simulation Health Check ==="
echo "Date: $(date)"
echo

# Find Wazuh manager container dynamically
WAZUH_CONTAINER=$(docker ps --format "{{.Names}}" | grep wazuh-manager | head -1)

# Check container status
echo "Container Status:"
docker ps --filter name=windows-endpoint-sim --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

# Check agent registration
echo "Wazuh Agent Registration:"
if [ -n "$WAZUH_CONTAINER" ]; then
    docker exec $WAZUH_CONTAINER /var/ossec/bin/manage_agents -l | grep WIN-ENDPOINT || echo "No agents registered"
else
    echo "Wazuh manager container not found"
fi
echo

# Check recent events
echo "Recent Sysmon Events (last 5):"
docker exec windows-endpoint-sim-01 tail -n 5 /var/log/sysmon-simulator.log 2>/dev/null || echo "No events found"
echo

# Check Wazuh manager logs
echo "Recent Wazuh Manager Activity:"
if [ -n "$WAZUH_CONTAINER" ]; then
    docker exec $WAZUH_CONTAINER tail -n 5 /var/ossec/logs/ossec.log | grep -E "(sysmon|WIN-ENDPOINT)" || echo "No Sysmon activity in manager logs"
else
    echo "Wazuh manager container not found"
fi
echo

# Check Elasticsearch indices
echo "Elasticsearch Indices:"
curl -s "localhost:9200/_cat/indices/wazuh*?v" 2>/dev/null || echo "Cannot connect to Elasticsearch"
echo

echo "=== Health Check Complete ==="
