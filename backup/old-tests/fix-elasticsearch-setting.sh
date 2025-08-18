#!/bin/bash

# ===================================
# Fix Elasticsearch 9.1.2 Setting Error
# ===================================
# Fixes the cluster.routing.allocation.disk.threshold.enabled setting
# ===================================

echo "🔧 Fixing Elasticsearch 9.1.2 setting error..."

# Stop any running containers
docker compose -f docker-compose-test.yml down -v 2>/dev/null || true

# Fix the Elasticsearch configuration
echo "Updating elasticsearch.yml with correct setting name..."

cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
# Elasticsearch 9.1.2 Configuration (Fixed)
cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node

# Network
network.host: 0.0.0.0
http.port: 9200

# Security (simplified for development)
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.license.self_generated.type: basic

# Performance
bootstrap.memory_lock: false
action.auto_create_index: true
indices.query.bool.max_clause_count: 10240

# FIXED: Use correct setting name for v9.1.2
cluster.routing.allocation.disk.threshold_enabled: false
EOF

echo "✅ Fixed elasticsearch.yml with correct setting name"

# Also fix the docker-compose to remove the problematic environment variable
echo "Updating docker-compose-test.yml..."

cat > docker-compose-test.yml << 'EOF'
networks:
  sentinel-test:
    driver: bridge

volumes:
  elasticsearch-test-data:
    driver: local
  kibana-test-data:
    driver: local

services:
  # Elasticsearch 9.1.2 (Fixed)
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:9.1.2
    container_name: sentinel-test-elasticsearch
    hostname: elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=sentinel-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=false
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=true
      - ELASTIC_PASSWORD=changeme123!
      - xpack.license.self_generated.type=basic
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
      - action.auto_create_index=true
      # REMOVED: cluster.routing.allocation.disk.threshold.enabled (wrong name)
      # ADDED: Use correct name in config file instead
    volumes:
      - elasticsearch-test-data:/usr/share/elasticsearch/data
      - ./configs/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
    ports:
      - "9200:9200"
    networks:
      - sentinel-test
    healthcheck:
      test: ["CMD-SHELL", "curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s
    mem_limit: 2g

  # Kibana 9.1.2 (compatible configuration)
  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.2
    container_name: sentinel-test-kibana
    hostname: kibana
    environment:
      - SERVERNAME=kibana
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123!
      - TELEMETRY_ENABLED=false
    volumes:
      - kibana-test-data:/usr/share/kibana/data
      - ./configs/elk/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml:ro
    ports:
      - "5601:5601"
    networks:
      - sentinel-test
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:5601/api/status || exit 1"]
      interval: 45s
      timeout: 15s
      retries: 8
      start_period: 120s
    mem_limit: 1.5g
EOF

echo "✅ Fixed docker-compose-test.yml"

# Start Elasticsearch
echo "Starting Elasticsearch with fixed configuration..."
docker compose -f docker-compose-test.yml up -d elasticsearch

echo "Waiting for Elasticsearch to start..."
for i in {1..20}; do
    if curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        echo "✅ Elasticsearch is working!"
        
        # Get version and health
        ES_INFO=$(curl -s -u elastic:changeme123! http://localhost:9200)
        ES_VERSION=$(echo "$ES_INFO" | grep -o '"number":"[^"]*"' | head -1 | cut -d'"' -f4)
        ES_HEALTH=$(curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        
        echo "   Version: $ES_VERSION"
        echo "   Health: $ES_HEALTH"
        break
    fi
    echo -n "."
    sleep 3
    
    if [[ $i -eq 20 ]]; then
        echo ""
        echo "❌ Still not working. Checking logs:"
        docker logs sentinel-test-elasticsearch --tail 10
        exit 1
    fi
done

echo ""
echo "🎉 Elasticsearch 9.1.2 is now working!"
echo ""
echo "Next: Start Kibana with:"
echo "   docker compose -f docker-compose-test.yml up -d kibana"
echo ""
echo "Or test Elasticsearch:"
echo "   curl -u elastic:changeme123! http://localhost:9200"
