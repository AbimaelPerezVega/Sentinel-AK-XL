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
echo -e "\033[1;33m           Starting Virtual SOC\033[0m"
echo ""

if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi

echo "🚀 Starting all services..."
docker compose up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 45

echo ""
echo "🎉 SOC Started!"
echo "🌐 Kibana: http://localhost:5601"
echo "🌐 Wazuh: https://localhost:8443"
echo ""
echo "Run: ./scripts/monitoring/status.sh to check status"
