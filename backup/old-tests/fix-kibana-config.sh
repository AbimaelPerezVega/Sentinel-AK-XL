#!/bin/bash

# ===================================
# Fix Kibana Configuration
# ===================================
# Fixes environment variable issues in Kibana config
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

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

echo -e "${CYAN}🔧 Fixing Kibana Configuration${NC}"

# Fix the Kibana configuration - remove environment variable references
step "Updating Kibana configuration..."

cat > configs/elk/kibana/kibana.yml << 'EOF'
# Basic Kibana Configuration for Testing
server.name: "sentinel-kibana"
server.host: "0.0.0.0"
server.port: 5601

# Elasticsearch connection (hardcoded for testing)
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.username: "elastic"
elasticsearch.password: "changeme123!"

# Security
xpack.security.enabled: true
xpack.security.encryptionKey: "a7a6311933d3503b89bc2dbc36572c33a6c10925682e591bffcab6911c06786d"

# Basic settings
kibana.index: ".kibana-sentinel"
kibana.defaultAppId: "discover"

# Monitoring
monitoring.enabled: true

# Disable SSL for development
elasticsearch.ssl.verificationMode: none
EOF

log "✅ Updated Kibana configuration with hardcoded password"

# Update docker-compose to pass environment variables properly
step "Updating docker-compose-test.yml for proper environment handling..."

cat > docker-compose-test.yml << 'EOF'
networks:
  sentinel-test:
    driver: bridge

volumes:
  elasticsearch-test-data:
    driver: local
  kibana-test-data:
    driver: local
  logstash-test-data:
    driver: local

services:
  # Elasticsearch
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: sentinel-test-elasticsearch
    hostname: elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=sentinel-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - xpack.security.enabled=true
      - ELASTIC_PASSWORD=changeme123!
      - xpack.license.self_generated.type=basic
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch-test-data:/usr/share/elasticsearch/data
      - ./configs/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
    ports:
      - "9200:9200"
    networks:
      - sentinel-test
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health | grep -vq '\"status\":\"red\"'"]
      interval: 30s
      timeout: 10s
      retries: 5
    mem_limit: 4g
    cpus: 2.0

  # Kibana
  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: sentinel-test-kibana
    hostname: kibana
    environment:
      - SERVERNAME=kibana
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123!
      - xpack.security.enabled=true
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
      test: ["CMD-SHELL", "curl -s http://localhost:5601/api/status | grep -q 'available'"]
      interval: 30s
      timeout: 10s
      retries: 5
    mem_limit: 2g
    cpus: 1.0

  # Logstash
  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: sentinel-test-logstash
    hostname: logstash
    environment:
      - "LS_JAVA_OPTS=-Xms1g -Xmx1g"
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123!
    volumes:
      - logstash-test-data:/usr/share/logstash/data
      - ./configs/elk/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./configs/elk/logstash/pipelines.yml:/usr/share/logstash/config/pipelines.yml:ro
      - ./configs/elk/logstash/conf.d:/usr/share/logstash/pipeline:ro
    ports:
      - "5044:5044"
      - "8080:8080"
      - "9000:9000"
      - "9600:9600"
    networks:
      - sentinel-test
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9600 | grep -q 'ok'"]
      interval: 30s
      timeout: 10s
      retries: 5
    mem_limit: 2g
    cpus: 1.0
EOF

log "✅ Updated docker-compose-test.yml with explicit environment variables"

# Create a simple test script that works with the current setup
step "Creating simple working test script..."

cat > test-elk-simple.sh << 'EOF'
#!/bin/bash

# Simple ELK Test - Works with current setup
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

echo -e "${CYAN}🧪 Simple ELK Test${NC}"
echo "=================="

# Clean up
log "Cleaning up..."
docker compose -f docker-compose-test.yml down -v 2>/dev/null || true

# Start Elasticsearch
step "Starting Elasticsearch..."
docker compose -f docker-compose-test.yml up -d elasticsearch

log "Waiting for Elasticsearch (60 seconds max)..."
for i in {1..20}; do
    if curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        log "✅ Elasticsearch is ready"
        break
    fi
    echo -n "."
    sleep 3
    if [[ $i -eq 20 ]]; then
        echo ""
        log "❌ Elasticsearch timeout"
        docker compose -f docker-compose-test.yml logs elasticsearch | tail -10
        exit 1
    fi
done

# Start Kibana
step "Starting Kibana..."
docker compose -f docker-compose-test.yml up -d kibana

log "Waiting for Kibana (120 seconds max)..."
for i in {1..40}; do
    if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
        log "✅ Kibana is ready"
        break
    fi
    echo -n "."
    sleep 3
    if [[ $i -eq 40 ]]; then
        echo ""
        log "❌ Kibana timeout"
        docker compose -f docker-compose-test.yml logs kibana | tail -10
        exit 1
    fi
done

# Start Logstash
step "Starting Logstash..."
docker compose -f docker-compose-test.yml up -d logstash

log "Waiting for Logstash (60 seconds max)..."
for i in {1..20}; do
    if curl -s http://localhost:9600 >/dev/null 2>&1; then
        log "✅ Logstash is ready"
        break
    fi
    echo -n "."
    sleep 3
    if [[ $i -eq 20 ]]; then
        echo ""
        log "❌ Logstash timeout"
        docker compose -f docker-compose-test.yml logs logstash | tail -10
        exit 1
    fi
done

echo ""
echo -e "${GREEN}🎉 ELK Stack is working!${NC}"
echo ""
echo -e "${CYAN}📋 Access Information:${NC}"
echo -e "   • Elasticsearch: http://localhost:9200 (elastic/changeme123!)"
echo -e "   • Kibana: http://localhost:5601 (elastic/changeme123!)"
echo -e "   • Logstash: http://localhost:9600"
echo ""
echo -e "${CYAN}🧪 Test Commands:${NC}"
echo -e "   curl -u elastic:changeme123! http://localhost:9200/_cluster/health"
echo -e "   curl http://localhost:5601/api/status"
echo ""
echo -e "${CYAN}🛑 To stop:${NC}"
echo -e "   docker compose -f docker-compose-test.yml down"
EOF

chmod +x test-elk-simple.sh

log "✅ Created test-elk-simple.sh"

log "🎉 Kibana configuration fixes completed!"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "1. Test with new script: ${YELLOW}./test-elk-simple.sh${NC}"
echo -e "2. Or continue verbose test: ${YELLOW}./test-elk-verbose.sh${NC}"
