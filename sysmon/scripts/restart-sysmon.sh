#!/bin/bash
# Restart Sysmon simulation

    echo "Restarting Sysmon simulation..."

# Stop and remove existing container
docker stop windows-endpoint-sim-01 2>/dev/null || true
docker rm windows-endpoint-sim-01 2>/dev/null || true

# Restart with fresh container
docker run -d \
    --name windows-endpoint-sim-01 \
    --network sentinel-ak-xl_default \
    -e WAZUH_MANAGER=172.20.0.13 \
    -e AGENT_NAME="WIN-ENDPOINT-01" \
    -e HOSTNAME="WIN-ENDPOINT-01" \
    windows-endpoint-simulator:latest

echo "Sysmon simulation restarted"
echo "Check status with: docker logs -f windows-endpoint-sim-01"
