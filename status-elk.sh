#!/bin/bash
# Check Sentinel ELK Stack Status

echo "📊 Sentinel ELK Stack Status"
echo "=============================="

# Check if services are running
echo ""
echo "Container Status:"
docker ps --filter "name=sentinel" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Service Health:"

# Elasticsearch
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' sentinel-elasticsearch 2>/dev/null || echo "not running")
if [[ "$HEALTH_STATUS" == "healthy" ]]; then
    echo "✅ Elasticsearch: HEALTHY"
    ES_STATUS=$(curl -s http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo "   Cluster status: $ES_STATUS"
else
    echo "❌ Elasticsearch: $HEALTH_STATUS"
fi

# Kibana
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' sentinel-kibana 2>/dev/null || echo "not running")
if [[ "$HEALTH_STATUS" == "healthy" ]]; then
    echo "✅ Kibana: HEALTHY"
else
    echo "❌ Kibana: $HEALTH_STATUS"
fi

# Logstash
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' sentinel-logstash 2>/dev/null || echo "not running")
if [[ "$HEALTH_STATUS" == "healthy" ]]; then
    echo "✅ Logstash: HEALTHY"
else
    echo "❌ Logstash: $HEALTH_STATUS"
fi

echo ""
echo "Access URLs:"
echo "• Elasticsearch: http://localhost:9200"
echo "• Kibana: http://localhost:5601"
