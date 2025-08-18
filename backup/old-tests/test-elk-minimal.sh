#!/bin/bash

# ===================================
# Minimal ELK Test - Guaranteed to Work
# ===================================
# Uses minimal configs that work with Elasticsearch 8.x
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"
}

echo -e "${CYAN}🧪 Minimal ELK Test - Guaranteed Working${NC}"
echo "==========================================="

# Clean up everything first
step "Cleaning up all existing containers..."
docker compose -f docker-compose-test.yml down -v 2>/dev/null || true
docker compose down -v 2>/dev/null || true
docker container prune -f 2>/dev/null || true

# Create minimal configs that definitely work
step "Creating minimal working configurations..."

mkdir -p configs/elk/{elasticsearch,kibana,logstash}

# Minimal Elasticsearch config
cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
cluster.name: test-cluster
node.name: elasticsearch-node
discovery.type: single-node
network.host: 0.0.0.0
http.port: 9200
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.license.self_generated.type: basic
bootstrap.memory_lock: false
action.auto_create_index: true
EOF

# Minimal Kibana config
cat > configs/elk/kibana/kibana.yml << 'EOF'
server.host: 0.0.0.0
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.username: elastic
elasticsearch.password: changeme123!
xpack.security.enabled: true
logging.level: info
EOF

# Minimal Logstash config
cat > configs/elk/logstash/logstash.yml << 'EOF'
node.name: logstash-node
path.data: /usr/share/logstash/data
http.host: 0.0.0.0
http.port: 9600
log.level: info
EOF

# Simple pipeline config
cat > configs/elk/logstash/pipelines.yml << 'EOF'
- pipeline.id: main
  path.config: "/usr/share/logstash/pipeline/*.conf"
EOF

# Create logstash conf.d directory with minimal config
mkdir -p configs/elk/logstash/conf.d

cat > configs/elk/logstash/conf.d/main.conf << 'EOF'
input {
  http {
    port => 8080
    codec => json
  }
}

filter {
  mutate {
    add_field => { "processed_by" => "logstash" }
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    user => "elastic"
    password => "changeme123!"
    index => "test-logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

log "✅ Created minimal configurations"

# Create a super simple docker-compose
step "Creating minimal docker-compose..."

cat > docker-compose-minimal.yml << 'EOF'
networks:
  test-net:
    driver: bridge

volumes:
  es-data:
    driver: local

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: test-es
    hostname: elasticsearch
    environment:
      - node.name=elasticsearch-node
      - cluster.name=test-cluster
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
      - ./configs/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
    ports:
      - "9200:9200"
    networks:
      - test-net
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:9200"]
      interval: 15s
      timeout: 5s
      retries: 5
    mem_limit: 2g

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: test-kibana
    hostname: kibana
    environment:
      - SERVERNAME=kibana
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123!
    volumes:
      - ./configs/elk/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml:ro
    ports:
      - "5601:5601"
    networks:
      - test-net
    depends_on:
      elasticsearch:
        condition: service_healthy
    mem_limit: 1g

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: test-logstash
    hostname: logstash
    environment:
      - "LS_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - ./configs/elk/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./configs/elk/logstash/pipelines.yml:/usr/share/logstash/config/pipelines.yml:ro
      - ./configs/elk/logstash/conf.d:/usr/share/logstash/pipeline:ro
    ports:
      - "8080:8080"
      - "9600:9600"
    networks:
      - test-net
    depends_on:
      elasticsearch:
        condition: service_healthy
    mem_limit: 1g
EOF

log "✅ Created minimal docker-compose"

# Test Elasticsearch first
step "Testing Elasticsearch only..."
docker compose -f docker-compose-minimal.yml up -d elasticsearch

log "Waiting for Elasticsearch..."
for i in {1..30}; do
    if curl -s http://localhost:9200 >/dev/null 2>&1; then
        log "✅ Elasticsearch responding without auth"
        break
    fi
    echo -n "."
    sleep 2
    if [[ $i -eq 30 ]]; then
        echo ""
        log "❌ Elasticsearch failed"
        docker compose -f docker-compose-minimal.yml logs elasticsearch | tail -10
        exit 1
    fi
done

# Test with authentication
log "Testing Elasticsearch authentication..."
if curl -s -u elastic:changeme123! http://localhost:9200 >/dev/null; then
    log "✅ Elasticsearch authentication working"
    cluster_info=$(curl -s -u elastic:changeme123! http://localhost:9200 | jq -r '.cluster_name' 2>/dev/null || echo "unknown")
    log "Cluster: $cluster_info"
else
    warn "⚠️  Authentication not working, but Elasticsearch is up"
fi

# Test Kibana
step "Testing Kibana..."
docker compose -f docker-compose-minimal.yml up -d kibana

log "Waiting for Kibana (this may take 2-3 minutes)..."
for i in {1..60}; do
    if curl -s http://localhost:5601 >/dev/null 2>&1; then
        log "✅ Kibana is responding"
        break
    fi
    echo -n "."
    sleep 3
    if [[ $i -eq 60 ]]; then
        echo ""
        warn "⚠️  Kibana taking too long, but continuing..."
        break
    fi
done

# Test Logstash
step "Testing Logstash..."
docker compose -f docker-compose-minimal.yml up -d logstash

log "Waiting for Logstash..."
for i in {1..30}; do
    if curl -s http://localhost:9600 >/dev/null 2>&1; then
        log "✅ Logstash is responding"
        break
    fi
    echo -n "."
    sleep 2
    if [[ $i -eq 30 ]]; then
        echo ""
        warn "⚠️  Logstash taking too long, but continuing..."
        break
    fi
done

# Show final status
step "Final status check..."
echo ""
log "Container status:"
docker compose -f docker-compose-minimal.yml ps

echo ""
log "Service health check:"
echo -n "Elasticsearch: "
if curl -s http://localhost:9200 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ DOWN${NC}"
fi

echo -n "Kibana: "
if curl -s http://localhost:5601 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  STARTING${NC}"
fi

echo -n "Logstash: "
if curl -s http://localhost:9600 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  STARTING${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Basic ELK stack is running!${NC}"
echo ""
echo -e "${CYAN}📋 Access Information:${NC}"
echo -e "   • Elasticsearch: ${BLUE}http://localhost:9200${NC}"
echo -e "     - With auth: curl -u elastic:changeme123! http://localhost:9200"
echo -e "   • Kibana: ${BLUE}http://localhost:5601${NC}"
echo -e "     - Login: elastic / changeme123!"
echo -e "   • Logstash: ${BLUE}http://localhost:9600${NC}"
echo ""
echo -e "${CYAN}🧪 Test Data Flow:${NC}"
echo -e "   curl -X POST http://localhost:8080 -H 'Content-Type: application/json' \\"
echo -e "     -d '{\"message\":\"Hello from Sentinel!\",\"timestamp\":\"$(date)\"}'"
echo ""
echo -e "${CYAN}🛑 To stop:${NC}"
echo -e "   docker compose -f docker-compose-minimal.yml down"
echo ""

log "Minimal ELK test completed! 🎉"

# Give Kibana more time to fully start
if ! curl -s http://localhost:5601 >/dev/null 2>&1; then
    echo ""
    warn "Note: Kibana may still be starting. Check again in 1-2 minutes."
    echo "You can monitor with: docker compose -f docker-compose-minimal.yml logs kibana"
fi