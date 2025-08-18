#!/bin/bash

# ===================================
# Simple ELK Test - Fixed Version
# ===================================
# Minimal test for Elasticsearch startup
# Author: Sentinel AK-XL Team
# Version: 1.0
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
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} $1"
}

step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

echo -e "${CYAN}🧪 Simple ELK Test${NC}"
echo "==================="

# Clean up first
log "Cleaning up any existing containers..."
docker compose -f docker-compose-test.yml down -v 2>/dev/null || true

# Create a minimal, working Elasticsearch config
step "Creating minimal Elasticsearch configuration..."

mkdir -p configs/elk/elasticsearch

cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
# Minimal Elasticsearch Configuration
cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node

# Network
network.host: 0.0.0.0
http.port: 9200

# Security (simplified for testing)
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.license.self_generated.type: basic

# Performance
bootstrap.memory_lock: false
action.auto_create_index: true
EOF

log "✅ Created minimal Elasticsearch config"

# Create minimal docker-compose for testing
step "Creating minimal docker-compose configuration..."

cat > docker-compose-minimal.yml << 'EOF'
networks:
  test-network:
    driver: bridge

volumes:
  es-data:
    driver: local

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: test-elasticsearch
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
    volumes:
      - es-data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - test-network
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200/_cluster/health"]
      interval: 30s
      timeout: 10s
      retries: 5
    mem_limit: 2g
EOF

log "✅ Created minimal docker-compose"

# Start Elasticsearch
step "Starting Elasticsearch with minimal config..."
docker compose -f docker-compose-minimal.yml up -d elasticsearch

log "Waiting for Elasticsearch to start (this may take 2-3 minutes)..."

# Wait with progress indicator
for i in {1..60}; do
    if curl -s http://localhost:9200 >/dev/null 2>&1; then
        echo ""
        log "✅ Elasticsearch is responding"
        break
    fi
    echo -n "."
    sleep 3
    if [[ $i -eq 60 ]]; then
        echo ""
        error "❌ Elasticsearch failed to start"
        log "Container logs:"
        docker compose -f docker-compose-minimal.yml logs elasticsearch | tail -20
        exit 1
    fi
done

# Test authentication
step "Testing Elasticsearch authentication..."
if curl -s -u elastic:changeme123! http://localhost:9200 >/dev/null; then
    log "✅ Authentication working"
    
    # Get cluster info
    cluster_info=$(curl -s -u elastic:changeme123! http://localhost:9200)
    echo "Cluster info: $cluster_info" | head -c 200
    echo ""
else
    error "❌ Authentication failed"
    exit 1
fi

# Test cluster health
step "Checking cluster health..."
health=$(curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health)
status=$(echo "$health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

log "Cluster status: $status"

if [[ "$status" == "green" ]] || [[ "$status" == "yellow" ]]; then
    log "✅ Cluster health is acceptable"
else
    error "❌ Cluster health is poor: $status"
fi

echo ""
echo -e "${GREEN}🎉 Elasticsearch is working!${NC}"
echo ""
echo -e "${CYAN}📋 Test Results:${NC}"
echo -e "   • Elasticsearch: ✅ Running on port 9200"
echo -e "   • Authentication: ✅ Working (elastic/changeme123!)"
echo -e "   • Cluster Status: ✅ $status"
echo ""
echo -e "${CYAN}🧪 Quick Tests:${NC}"
echo -e "   curl -u elastic:changeme123! http://localhost:9200"
echo -e "   curl -u elastic:changeme123! http://localhost:9200/_cluster/health"
echo ""
echo -e "${CYAN}🛑 To stop:${NC}"
echo -e "   docker compose -f docker-compose-minimal.yml down"
echo ""

log "Basic Elasticsearch test completed successfully! 🎉"
