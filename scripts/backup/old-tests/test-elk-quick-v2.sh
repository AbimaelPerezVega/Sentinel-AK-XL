#!/bin/bash
# Quick ELK Stack Test - Docker Compose v2 Version

echo "🧪 Quick ELK Stack Test (v2)"
echo "============================"

# Use Docker Compose v2 and test docker-compose file
export COMPOSE_FILE=docker-compose-test.yml

echo "1. Starting Elasticsearch..."
docker compose up -d elasticsearch
sleep 30

echo "2. Testing Elasticsearch..."
if curl -s -u elastic:changeme123! http://localhost:9200 > /dev/null; then
    echo "✅ Elasticsearch is working"
else
    echo "❌ Elasticsearch failed"
    echo "Container logs:"
    docker compose logs elasticsearch | tail -10
    exit 1
fi

echo "3. Starting Kibana..."
docker compose up -d kibana
sleep 60

echo "4. Testing Kibana..."
if curl -s http://localhost:5601 > /dev/null; then
    echo "✅ Kibana is working"
else
    echo "❌ Kibana failed"
    echo "Container logs:"
    docker compose logs kibana | tail -10
    exit 1
fi

echo "5. Starting Logstash..."
docker compose up -d logstash
sleep 30

echo "6. Testing Logstash..."
if curl -s http://localhost:9600 > /dev/null; then
    echo "✅ Logstash is working"
else
    echo "❌ Logstash failed"
    echo "Container logs:"
    docker compose logs logstash | tail -10
    exit 1
fi

echo ""
echo "🎉 ELK Stack is working!"
echo "📋 Access URLs:"
echo "   Elasticsearch: http://localhost:9200 (elastic/changeme123!)"
echo "   Kibana: http://localhost:5601 (elastic/changeme123!)"
echo "   Logstash: http://localhost:9600"
echo ""
echo "📧 Send test event:"
echo "   curl -X POST http://localhost:8080 -H 'Content-Type: application/json' -d '{\"message\":\"test\"}'"
echo ""
echo "🛑 To stop:"
echo "   docker compose down"
