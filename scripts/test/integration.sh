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
echo -e "\033[1;33m           Testing Wazuh-ELK Integration\033[0m"
echo ""

echo "🔍 Testing data flow..."

# Check if Wazuh indices exist
indices=$(curl -s localhost:9200/_cat/indices 2>/dev/null | grep -c wazuh || echo "0")

if [[ $indices -gt 0 ]]; then
    echo "✅ Found $indices Wazuh indices in Elasticsearch"
else
    echo "❌ No Wazuh indices found"
fi

# Check document count
docs=$(curl -s localhost:9200/wazuh-alerts-*/_count 2>/dev/null | grep -o '"count":[0-9]*' | cut -d: -f2 || echo "0")

if [[ $docs -gt 0 ]]; then
    echo "✅ Found $docs documents in Wazuh indices"
else
    echo "⚠️  No documents found (may be normal for new setup)"
fi

# Test connectivity
if curl -s localhost:9200 > /dev/null && curl -sk https://localhost:8443 > /dev/null; then
    echo "✅ Connectivity: Elasticsearch ↔ Wazuh"
else
    echo "❌ Connectivity issues detected"
fi

echo ""
echo "🎉 Integration test completed!"
