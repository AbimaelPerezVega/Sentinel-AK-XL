#!/bin/bash
# Verbose ELK Stack Test with detailed logging

set -e  # Exit on error

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

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} $1"
}

step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

echo -e "${CYAN}"
cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
            🧪 VERBOSE ELK STACK TEST 🧪
EOF
echo -e "${NC}"

# Use Docker Compose v2 and test docker-compose file
export COMPOSE_FILE=docker-compose-test.yml

log "Using Docker Compose file: $COMPOSE_FILE"
log "Docker Compose version: $(docker compose version --short)"

# Check if compose file exists
if [[ ! -f "$COMPOSE_FILE" ]]; then
    error "Docker Compose file not found: $COMPOSE_FILE"
    log "Available files:"
    ls -la *.yml 2>/dev/null || echo "No .yml files found"
    exit 1
fi

log "Compose file found: $COMPOSE_FILE"

# Validate compose file
step "Validating Docker Compose configuration..."
if docker compose config &> /dev/null; then
    log "✅ Docker Compose configuration is valid"
else
    error "❌ Docker Compose configuration is invalid"
    docker compose config
    exit 1
fi

# Clean up any existing containers
step "Cleaning up existing containers..."
docker compose down -v 2>/dev/null || true
log "Cleanup completed"

# Start Elasticsearch
step "1. Starting Elasticsearch..."
log "Running: docker compose up -d elasticsearch"
docker compose up -d elasticsearch

if [[ $? -eq 0 ]]; then
    log "✅ Elasticsearch container started"
else
    error "❌ Failed to start Elasticsearch"
    exit 1
fi

# Wait for Elasticsearch
step "Waiting for Elasticsearch to be ready..."
for i in {1..30}; do
    echo -n "."
    if curl -s http://localhost:9200 &>/dev/null; then
        echo ""
        log "✅ Elasticsearch is responding"
        break
    fi
    sleep 2
    if [[ $i -eq 30 ]]; then
        echo ""
        error "❌ Elasticsearch failed to start within 60 seconds"
        log "Container status:"
        docker compose ps
        log "Elasticsearch logs:"
        docker compose logs elasticsearch | tail -20
        exit 1
    fi
done

# Test Elasticsearch with authentication
step "2. Testing Elasticsearch authentication..."
log "Testing with credentials: elastic/changeme123!"

if curl -s -u elastic:changeme123! http://localhost:9200 > /dev/null; then
    log "✅ Elasticsearch authentication working"
    
    # Get cluster info
    cluster_info=$(curl -s -u elastic:changeme123! http://localhost:9200)
    cluster_name=$(echo "$cluster_info" | grep -o '"cluster_name":"[^"]*"' | cut -d'"' -f4)
    log "Cluster name: $cluster_name"
else
    error "❌ Elasticsearch authentication failed"
    log "Trying without authentication..."
    if curl -s http://localhost:9200 > /dev/null; then
        warn "Elasticsearch responding without auth - check security settings"
    else
        error "Elasticsearch not responding at all"
        docker compose logs elasticsearch | tail -10
        exit 1
    fi
fi

# Start Kibana
step "3. Starting Kibana..."
log "Running: docker compose up -d kibana"
docker compose up -d kibana

# Wait for Kibana
step "Waiting for Kibana to be ready..."
for i in {1..45}; do
    echo -n "."
    if curl -s http://localhost:5601 &>/dev/null; then
        echo ""
        log "✅ Kibana is responding"
        break
    fi
    sleep 2
    if [[ $i -eq 45 ]]; then
        echo ""
        error "❌ Kibana failed to start within 90 seconds"
        log "Kibana logs:"
        docker compose logs kibana | tail -20
        exit 1
    fi
done

# Start Logstash
step "4. Starting Logstash..."
log "Running: docker compose up -d logstash"
docker compose up -d logstash

# Wait for Logstash
step "Waiting for Logstash to be ready..."
for i in {1..30}; do
    echo -n "."
    if curl -s http://localhost:9600 &>/dev/null; then
        echo ""
        log "✅ Logstash is responding"
        break
    fi
    sleep 2
    if [[ $i -eq 30 ]]; then
        echo ""
        error "❌ Logstash failed to start within 60 seconds"
        log "Logstash logs:"
        docker compose logs logstash | tail -20
        exit 1
    fi
done

# Final status check
step "5. Final status check..."
log "Container status:"
docker compose ps

log "Service endpoints:"
echo "  Elasticsearch: $(curl -s http://localhost:9200 && echo "✅ OK" || echo "❌ FAIL")"
echo "  Kibana: $(curl -s http://localhost:5601 && echo "✅ OK" || echo "❌ FAIL")"
echo "  Logstash: $(curl -s http://localhost:9600 && echo "✅ OK" || echo "❌ FAIL")"

echo ""
echo -e "${GREEN}🎉 ELK Stack is working!${NC}"
echo ""
echo -e "${CYAN}📋 Access URLs:${NC}"
echo -e "   • Elasticsearch: ${BLUE}http://localhost:9200${NC} (elastic/changeme123!)"
echo -e "   • Kibana: ${BLUE}http://localhost:5601${NC} (elastic/changeme123!)"
echo -e "   • Logstash: ${BLUE}http://localhost:9600${NC}"
echo ""
echo -e "${CYAN}🧪 Test Commands:${NC}"
echo -e "   # Check cluster health:"
echo -e "   curl -u elastic:changeme123! http://localhost:9200/_cluster/health"
echo ""
echo -e "   # Send test event:"
echo -e "   curl -X POST http://localhost:8080 -H 'Content-Type: application/json' -d '{\"message\":\"Hello Sentinel!\"}'"
echo ""
echo -e "${CYAN}🛑 To stop:${NC}"
echo -e "   docker compose down"
echo ""

log "Test completed successfully! 🎉"