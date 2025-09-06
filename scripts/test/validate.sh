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
echo -e "\033[1;33m           Validating SOC Setup\033[0m"
echo ""

errors=0

# Check Docker
if command -v docker &> /dev/null; then
    echo "✅ Docker installed"
else
    echo "❌ Docker not installed"
    ((errors++))
fi

# Check services
services=(elasticsearch logstash kibana wazuh-manager wazuh-indexer)
for service in "${services[@]}"; do
    if docker compose ps | grep -q "$service.*Up"; then
        echo "✅ $service running"
    else
        echo "❌ $service not running"
        ((errors++))
    fi
done

# Check endpoints
endpoints=(
    "localhost:9200"
    "localhost:5601"
    "localhost:8443"
)

for endpoint in "${endpoints[@]}"; do
    if curl -s "$endpoint" > /dev/null 2>&1; then
        echo "✅ $endpoint responding"
    else
        echo "❌ $endpoint not responding"
        ((errors++))
    fi
done

echo ""
if [[ $errors -eq 0 ]]; then
    echo "🎉 VALIDATION PASSED: SOC is ready!"
else
    echo "⚠️  VALIDATION FAILED: $errors issues found"
fi
