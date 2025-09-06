#!/bin/bash
set -euo pipefail

echo -e "\033[0;34m"
echo "███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     "
echo "██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     "
echo "███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     "
echo "╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     "
echo "███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗"
echo "╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
echo -e "\033[0m"
echo -e "\033[1;33m           Testing Alert Generation\033[0m"
echo ""

echo "🎯 Generating test alerts..."

# SSH brute force simulation
echo "🔒 Simulating SSH brute force..."
for i in {1..3}; do
    echo "$(date) sshd[$$]: Failed password for root from 192.168.1.100 port 22" | \
    docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-logtest -q 2>/dev/null || true
    sleep 1
done

# Malware simulation
echo "🦠 Simulating malware detection..."
echo "$(date) Windows Defender: Threat detected - Malware:Win32/TestVirus" | \
docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-logtest -q 2>/dev/null || true

echo ""
echo "⏳ Waiting for alerts to process..."
sleep 20

# Check alerts
alert_count=$(curl -s localhost:9200/wazuh-alerts-*/_count 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2 || echo "0")

if [[ $alert_count -gt 0 ]]; then
    echo "✅ Found $alert_count alerts in Elasticsearch"
else
    echo "⚠️  No alerts found yet (may need more time)"
fi

echo ""
echo "🎉 Test completed!"
