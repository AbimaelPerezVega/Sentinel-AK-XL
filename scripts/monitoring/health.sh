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
echo -e "\033[1;33m           Health Check\033[0m"
echo ""

overall_health="healthy"

# Check Elasticsearch
if curl -s localhost:9200/_cluster/health | grep -q "green\|yellow"; then
    echo "✅ Elasticsearch: HEALTHY"
else
    echo "❌ Elasticsearch: UNHEALTHY"
    overall_health="unhealthy"
fi

# Check Kibana
if curl -s localhost:5601 > /dev/null; then
    echo "✅ Kibana: HEALTHY"
else
    echo "❌ Kibana: UNHEALTHY"
    overall_health="unhealthy"
fi

# Check Wazuh
if curl -sk https://localhost:8443 > /dev/null; then
    echo "✅ Wazuh Dashboard: HEALTHY"
else
    echo "❌ Wazuh Dashboard: UNHEALTHY"
    overall_health="unhealthy"
fi

echo ""
if [[ $overall_health == "healthy" ]]; then
    echo "🎉 Overall Status: HEALTHY"
else
    echo "⚠️  Overall Status: NEEDS ATTENTION"
fi
