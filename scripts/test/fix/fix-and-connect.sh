#!/bin/bash
# ==============================================================================
# FINAL SCRIPT: Reset, Initialize, and Configure Wazuh + Filebeat
# ==============================================================================
set -e
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}--- Starting the definitive Wazuh & Filebeat fix ---${NC}"

# --- 1. Full Cleanup ---
echo "✅ Step 1: Stopping and removing all containers, networks, and volumes..."
docker compose down -v
echo -e "${GREEN}Cleanup complete.${NC}"

# --- 2. Create Local Configs ---
echo -e "\n✅ Step 2: Preparing local configuration files..."
FILEBEAT_CONFIG="./configs/wazuh/filebeat/filebeat.yml"
mkdir -p ./configs/wazuh/filebeat
cat > "$FILEBEAT_CONFIG" << 'EOF'
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/ossec/logs/alerts/alerts.json
  json.keys_under_root: true
  json.overwrite_keys: true
output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  protocol: "http"
EOF
echo -e "${GREEN}Filebeat config is ready.${NC}"

# --- 3. Start Services with Clean State ---
echo -e "\n✅ Step 3: Starting all services. Wazuh will initialize itself."
docker compose up -d

echo -e "\n${GREEN}Waiting 60 seconds for services to initialize properly...${NC}"
sleep 60

# --- 4. Copy Configurations into Running Container ---
echo -e "\n✅ Step 4: Injecting custom configurations into the running container..."
docker cp "$FILEBEAT_CONFIG" sentinel-wazuh-manager:/etc/filebeat/filebeat.yml
docker cp "./configs/wazuh/ossec.conf" sentinel-wazuh-manager:/var/ossec/etc/ossec.conf
echo -e "${GREEN}Configuration files copied successfully.${NC}"

# --- 5. Restart Wazuh Manager to Apply New Configs ---
echo -e "\n✅ Step 5: Restarting Wazuh Manager to apply our custom settings..."
docker compose restart wazuh-manager

echo -e "\n${GREEN}Restart complete. Waiting 45 seconds for final verification...${NC}"
sleep 45

# --- 6. Final Verification ---
echo -e "\n${BLUE}--- Step 6: Verifying the connection ---${NC}"
LOG_OUTPUT=$(docker logs sentinel-wazuh-manager 2>&1)

if echo "$LOG_OUTPUT" | grep -q "Connection to http://elasticsearch:9200 established"; then
    echo -e "${GREEN}🎉🎉🎉 IT WORKS! Connection to Elasticsearch established! 🎉🎉🎉${NC}"
    echo "The data pipeline is now active. You can proceed with agent registration."
else
    echo -e "${RED}❌ FINAL ATTEMPT FAILED. The issue is deeper than expected.${NC}"
    echo -e "${YELLOW}Please review the final logs:${NC}"
    echo "docker logs sentinel-wazuh-manager"
fi
