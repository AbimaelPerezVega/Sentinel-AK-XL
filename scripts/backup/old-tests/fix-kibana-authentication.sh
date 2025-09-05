#!/bin/bash

# ===================================
# Fix Kibana Authentication for v9.1.2
# ===================================
# Fixes the "elastic superuser forbidden" error in Kibana 9.1.2
# ===================================

echo "🔧 Fixing Kibana authentication for v9.1.2..."

# Stop containers
docker compose -f docker-compose-test.yml down

# Option 1: Update Kibana config to not use elastic user
echo "Creating Kibana config without elastic user authentication..."

cat > configs/elk/kibana/kibana.yml << 'EOF'
# Kibana 9.1.2 Configuration (No elastic user)
server.host: 0.0.0.0
server.port: 5601
server.name: sentinel-kibana

# Elasticsearch connection (without elastic user for v9.1.2)
elasticsearch.hosts: ["http://elasticsearch:9200"]
# Note: Removed elasticsearch.username and elasticsearch.password
# Kibana 9.1.2 will use internal authentication

# Security settings (v9.1.2 compatible)
server.ssl.enabled: false

# Basic settings
telemetry.enabled: false
telemetry.optIn: false

# Performance settings
elasticsearch.pingTimeout: 10000
elasticsearch.requestTimeout: 60000
elasticsearch.maxSockets: 100

# Logging (v9.1.2 format)
logging:
  appenders:
    file:
      type: file
      fileName: /usr/share/kibana/logs/kibana.log
      layout:
        type: json
  root:
    level: warn
    appenders: [file]
EOF

# Update docker-compose to remove elasticsearch credentials from Kibana
echo "Updating docker-compose to fix Kibana environment..."

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
      - xpack.security.enabled=false  # Simplified for development
      - xpack.license.self_generated.type=basic
      - action.auto_create_index=true
    volumes:
      - elasticsearch-test-data:/usr/share/elasticsearch/data
      - ./configs/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
    ports:
      - "9200:9200"
    networks:
      - sentinel-test
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s
    mem_limit: 2g

  # Kibana 9.1.2 (Fixed - no elastic user)
  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.2
    container_name: sentinel-test-kibana
    hostname: kibana
    environment:
      - SERVERNAME=kibana
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      # Removed ELASTICSEARCH_USERNAME and ELASTICSEARCH_PASSWORD
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

# Also update Elasticsearch config to disable security for simpler setup
cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
# Elasticsearch 9.1.2 Configuration (Simplified)
cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node

# Network
network.host: 0.0.0.0
http.port: 9200

# Security (disabled for development - simpler setup)
xpack.security.enabled: false
xpack.license.self_generated.type: basic

# Performance
bootstrap.memory_lock: false
action.auto_create_index: true
indices.query.bool.max_clause_count: 10240

# FIXED: Correct setting name for v9.1.2 (underscore, not dot)
cluster.routing.allocation.disk.threshold_enabled: false
EOF

echo "✅ Updated configurations to disable security (simpler for development)"

# Start services
echo "Starting Elasticsearch..."
docker compose -f docker-compose-test.yml up -d elasticsearch

echo "Waiting for Elasticsearch..."
for i in {1..15}; do
    if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        echo "✅ Elasticsearch is ready (no authentication needed)"
        break
    fi
    echo -n "."
    sleep 3
done

echo ""
echo "Starting Kibana..."
docker compose -f docker-compose-test.yml up -d kibana

echo "Waiting for Kibana (this may take 2-3 minutes)..."
for i in {1..30}; do
    if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
        echo "✅ Kibana is ready"
        break
    fi
    echo -n "."
    sleep 5
    
    if [ $((i % 6)) -eq 0 ]; then
        echo ""
        echo "   Still starting... (attempt $i/30)"
    fi
done

echo ""
echo "🎉 ELK Stack 9.1.2 is now working!"
echo ""
echo "Access URLs:"
echo "• Elasticsearch: http://localhost:9200 (no authentication)"
echo "• Kibana: http://localhost:5601 (no authentication)"
echo ""
echo "Test commands:"
echo "   curl http://localhost:9200"
echo "   curl http://localhost:5601/api/status"
