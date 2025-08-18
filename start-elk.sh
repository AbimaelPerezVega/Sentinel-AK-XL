#!/bin/bash
# Start Sentinel ELK Stack

echo "🚀 Starting Sentinel ELK Stack..."

# Determine compose command
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi

# Start services
echo "Starting services..."
$COMPOSE_CMD up -d

echo "✅ Services started. Waiting for health checks..."

# Wait for Elasticsearch
echo -n "Waiting for Elasticsearch..."
for i in {1..40}; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' sentinel-elasticsearch 2>/dev/null)
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo ""
        echo "✅ Elasticsearch is ready (healthy)"
        ES_READY=true
        break
    fi
    echo -n "."
    sleep 3
done
if [ "$ES_READY" != true ]; then
    echo ""
    echo "❌ Elasticsearch failed to become healthy. Check logs: $COMPOSE_CMD logs elasticsearch"
    exit 1
fi


# Wait for Kibana
echo -n "Waiting for Kibana..."
for i in {1..50}; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' sentinel-kibana 2>/dev/null)
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo ""
        echo "✅ Kibana is ready (healthy)"
        KIBANA_READY=true
        break
    fi
    echo -n "."
    sleep 3
done
if [ "$KIBANA_READY" != true ]; then
    echo ""
    echo "❌ Kibana failed to become healthy. Check logs: $COMPOSE_CMD logs kibana"
    exit 1
fi

# Wait for Logstash
echo -n "Waiting for Logstash..."
for i in {1..40}; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' sentinel-logstash 2>/dev/null)
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        echo ""
        echo "✅ Logstash is ready (healthy)"
        LOGSTASH_READY=true
        break
    fi
    echo -n "."
    sleep 3
done
if [ "$LOGSTASH_READY" != true ]; then
    echo ""
    echo "❌ Logstash failed to become healthy. Check logs: $COMPOSE_CMD logs logstash"
    exit 1
fi


echo ""
echo "🎉 Sentinel ELK Stack is ready!"
echo ""
echo "Access URLs:"
echo "• Elasticsearch: http://localhost:9200"
echo "• Kibana: http://localhost:5601"
echo ""
echo "Useful commands:"
echo "• View logs: $COMPOSE_CMD logs -f"
echo "• Stop stack: $COMPOSE_CMD down"
echo "• Restart: $COMPOSE_CMD restart"
