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
echo -e "\033[1;33m           Deploying SOC Stack...\033[0m"
echo ""

if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi

echo "🚀 Starting Elasticsearch..."
docker compose up -d elasticsearch
sleep 30

echo "🚀 Starting Logstash..."
docker compose up -d logstash
sleep 20

echo "🚀 Starting Kibana..."
docker compose up -d kibana
sleep 30

echo "🚀 Starting Wazuh..."
docker compose up -d wazuh-manager wazuh-indexer wazuh-dashboard
sleep 30

echo ""
echo "✅ SOC Stack deployed!"
echo "🌐 Kibana: http://localhost:5601"
echo "🌐 Wazuh: https://localhost:8443"
