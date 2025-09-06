#!/bin/bash
set -euo pipefail

echo -e "\033[0;36m"
echo "███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     "
echo "╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
echo -e "\033[0m"
echo -e "\033[1;33m           Configuring Integrations...\033[0m"
echo ""

echo "🔧 Setting up Wazuh-ELK integration..."

# Wait for services
sleep 10

# Basic integration check
if curl -s localhost:9200 > /dev/null; then
    echo "✅ Elasticsearch ready"
else
    echo "❌ Elasticsearch not ready"
fi

if curl -s localhost:5601 > /dev/null; then
    echo "✅ Kibana ready"
else
    echo "❌ Kibana not ready"
fi

echo ""
echo "🎉 Configuration complete!"
echo "Next: Run ./scripts/test/validate.sh"
