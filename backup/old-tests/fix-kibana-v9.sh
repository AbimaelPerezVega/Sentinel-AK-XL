#!/bin/bash

# ===================================
# Fix ELK Stack 9.1.2 Compatibility Issues
# ===================================
# Resolves Kibana security config errors and Elasticsearch consistency issues
# Author: Sentinel AK-XL Team
# Version: 2.0
# ===================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[FIX]${NC} $1"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo -e "${CYAN}🔧 Fixing ELK Stack 9.1.2 Compatibility Issues${NC}"
echo "=============================================="

# Stop and clean previous containers
step "1. Cleaning previous installation..."
docker compose -f docker-compose-test.yml down -v 2>/dev/null || true
docker system prune -f
log "✅ Previous installation cleaned"

# Create proper directory structure
step "2. Creating configuration directories..."
mkdir -p configs/elk/{elasticsearch,kibana,logstash}
log "✅ Configuration directories created"

# Fix Kibana configuration for v9.1.2
step "3. Creating compatible Kibana configuration..."

cat > configs/elk/kibana/kibana.yml << 'EOF'
# Kibana 9.1.2 Compatible Configuration
server.host: 0.0.0.0
server.port: 5601
server.name: sentinel-kibana

# Elasticsearch connection
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.username: elastic
elasticsearch.password: changeme123!

# Security settings for v9 (no xpack.security.enabled in config file)
server.ssl.enabled: false

# Basic settings
telemetry.enabled: false
telemetry.optIn: false

# Performance settings
elasticsearch.pingTimeout: 10000
elasticsearch.requestTimeout: 60000
elasticsearch.maxSockets: 100

# Logging (simplified for v9)
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

log "✅ Kibana configuration fixed for v9.1.2"

# Fix Elasticsearch configuration
step "4. Creating compatible Elasticsearch configuration..."

cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
# Elasticsearch 9.1.2 Compatible Configuration
cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node

# Network
network.host: 0.0.0.0
http.port: 9200

# Security (basic setup for development)
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.license.self_generated.type: basic

# Performance and stability
bootstrap.memory_lock: false
action.auto_create_index: true
indices.query.bool.max_clause_count: 10240

# Memory settings
cluster.routing.allocation.disk.threshold.enabled: false
EOF

log "✅ Elasticsearch configuration fixed for v9.1.2"

# Create compatible docker-compose
step "5. Creating compatible docker-compose configuration..."

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
  # Elasticsearch 9.1.2
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
      - ELASTIC_PASSWORD=changeme123!
      - xpack.license.self_generated.type=basic
      # Security settings in environment for v9
      - xpack.security.enabled=true
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
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
      retries: 12
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
      # NO xpack.security.enabled here - it causes the error in v9
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

  # Logstash 9.1.2
  logstash:
    image: docker.elastic.co/logstash/logstash:9.1.2
    container_name: sentinel-test-logstash
    hostname: logstash
    environment:
      - "LS_JAVA_OPTS=-Xms512m -Xmx512m"
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123!
    networks:
      - sentinel-test
    depends_on:
      elasticsearch:
        condition: service_healthy
    mem_limit: 1g
EOF

log "✅ Compatible docker-compose created"

# Start services with proper monitoring
step "6. Starting Elasticsearch..."
docker compose -f docker-compose-test.yml up -d elasticsearch

log "Waiting for Elasticsearch to be ready..."
for i in {1..20}; do
    if curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        log "✅ Elasticsearch is ready"
        break
    fi
    echo -n "."
    sleep 3
done

# Check Elasticsearch status
ES_STATUS=$(curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health | grep -o '"status":"[^"]*"' || echo '"status":"unknown"')
log "Elasticsearch status: $ES_STATUS"

step "7. Starting Kibana with compatible configuration..."
docker compose -f docker-compose-test.yml up -d kibana

log "Waiting for Kibana to start (this may take 2-3 minutes)..."
for i in {1..24}; do
    if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
        log "✅ Kibana is ready"
        break
    fi
    echo -n "."
    sleep 5
    
    # Show logs every 30 seconds
    if [ $((i % 6)) -eq 0 ]; then
        echo ""
        log "Checking Kibana logs (attempt $i/24):"
        docker logs sentinel-test-kibana --tail 3 2>/dev/null || true
    fi
done

# Final verification
step "8. Final verification..."
echo ""
log "Service Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
log "Testing connectivity:"

# Test Elasticsearch
if curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    log "✅ Elasticsearch: WORKING"
    ES_VERSION=$(curl -s -u elastic:changeme123! http://localhost:9200 | grep -o '"version":[^}]*' | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
    log "   Version: $ES_VERSION"
else
    error "❌ Elasticsearch: NOT WORKING"
fi

# Test Kibana
if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
    log "✅ Kibana: WORKING"
else
    error "❌ Kibana: NOT WORKING"
    log "Latest Kibana logs:"
    docker logs sentinel-test-kibana --tail 10 2>/dev/null || true
fi

echo ""
echo -e "${CYAN}🎉 ELK Stack 9.1.2 Setup Complete!${NC}"
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
echo -e "• Elasticsearch: http://localhost:9200 (elastic/changeme123!)"
echo -e "• Kibana: http://localhost:5601"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "• View logs: docker compose -f docker-compose-test.yml logs -f"
echo -e "• Stop services: docker compose -f docker-compose-test.yml down"
echo -e "• Restart: docker compose -f docker-compose-test.yml restart"
