#!/bin/bash

# ===================================
# Test ELK Stack Installation
# ===================================
# Quick test script for users to verify the installation works
# ===================================

echo "🧪 Testing ELK Stack Installation..."

# Start services
echo "Starting ELK Stack..."
docker-compose up -d

# Wait for Elasticsearch
echo "Waiting for Elasticsearch..."
for i in {1..20}; do
    if curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        echo "✅ Elasticsearch is ready"
        break
    fi
    echo -n "."
    sleep 3
done

# Wait for Kibana  
echo "Waiting for Kibana..."
for i in {1..24}; do
    if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
        echo "✅ Kibana is ready"
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo "🎉 Installation test complete!"
echo ""
echo "Access URLs:"
echo "• Elasticsearch: http://localhost:9200 (elastic/changeme123!)"  
echo "• Kibana: http://localhost:5601"
echo ""
echo "To stop: docker-compose down"
