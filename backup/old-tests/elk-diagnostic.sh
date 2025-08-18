#!/bin/bash

# ===================================
# ELK Stack 9.1.2 Diagnostic Tool
# ===================================
# Comprehensive diagnostic and troubleshooting tool
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
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

section() {
    echo -e "\n${CYAN}==== $1 ====${NC}"
}

echo -e "${CYAN}🔍 ELK Stack 9.1.2 Diagnostic Tool${NC}"
echo "=================================="

section "1. Docker Environment Check"

# Check Docker version
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log "Docker: $DOCKER_VERSION"
else
    error "Docker is not installed or not in PATH"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    log "Docker Compose: $COMPOSE_VERSION"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    log "Docker Compose (plugin): $COMPOSE_VERSION"
else
    error "Docker Compose is not available"
    exit 1
fi

# Check available resources
log "System Resources:"
echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}' 2>/dev/null || echo 'Unknown')"
echo "  Disk Space: $(df -h . | awk 'NR==2 {print $4}' 2>/dev/null || echo 'Unknown')"

section "2. Container Status"

if docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -E "(elasticsearch|kibana|logstash)" >/dev/null 2>&1; then
    log "ELK Containers found:"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -E "(elasticsearch|kibana|logstash)"
else
    warn "No ELK containers found"
fi

section "3. Network Connectivity"

# Test Elasticsearch
log "Testing Elasticsearch connectivity..."
if curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    log "✅ Elasticsearch is responding"
    
    # Get detailed status
    ES_HEALTH=$(curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health)
    ES_STATUS=$(echo "$ES_HEALTH" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    ES_NODES=$(echo "$ES_HEALTH" | grep -o '"number_of_nodes":[0-9]*' | cut -d':' -f2)
    
    log "  Cluster Status: $ES_STATUS"
    log "  Nodes: $ES_NODES"
    
    # Get version info
    ES_VERSION=$(curl -s -u elastic:changeme123! http://localhost:9200 | grep -o '"number":"[^"]*"' | head -1 | cut -d'"' -f4)
    log "  Version: $ES_VERSION"
else
    error "❌ Elasticsearch is not responding"
    
    # Check if container is running
    if docker ps | grep elasticsearch >/dev/null; then
        warn "Elasticsearch container is running but not responding"
        log "Recent Elasticsearch logs:"
        docker logs sentinel-test-elasticsearch --tail 10 2>/dev/null || echo "  No logs available"
    else
        error "Elasticsearch container is not running"
    fi
fi

# Test Kibana
log "Testing Kibana connectivity..."
if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
    log "✅ Kibana is responding"
    
    # Get Kibana status
    KIBANA_STATUS=$(curl -s http://localhost:5601/api/status | grep -o '"overall":{"level":"[^"]*"' | cut -d'"' -f6)
    log "  Status: $KIBANA_STATUS"
else
    error "❌ Kibana is not responding"
    
    # Check if container is running
    if docker ps | grep kibana >/dev/null; then
        warn "Kibana container is running but not responding"
        log "Recent Kibana logs:"
        docker logs sentinel-test-kibana --tail 15 2>/dev/null || echo "  No logs available"
    else
        error "Kibana container is not running"
    fi
fi

section "4. Configuration Files Check"

# Check if config files exist
CONFIG_FILES=(
    "configs/elk/elasticsearch/elasticsearch.yml"
    "configs/elk/kibana/kibana.yml"
    "docker-compose-test.yml"
)

for file in "${CONFIG_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        log "✅ $file exists"
    else
        error "❌ $file is missing"
    fi
done

section "5. Port Usage Check"

log "Checking if required ports are available..."

PORTS=(9200 5601)
for port in "${PORTS[@]}"; do
    if ss -tlnp 2>/dev/null | grep ":$port " >/dev/null || netstat -tlnp 2>/dev/null | grep ":$port " >/dev/null; then
        PROCESS=$(ss -tlnp 2>/dev/null | grep ":$port " | awk '{print $6}' | head -1 || netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
        log "Port $port is in use by: $PROCESS"
    else
        warn "Port $port is not in use"
    fi
done

section "6. Docker Images Check"

log "Available ELK images:"
docker images | grep -E "(elasticsearch|kibana|logstash)" | head -10

section "7. Volume and Data Check"

log "Docker volumes:"
docker volume ls | grep -E "(elasticsearch|kibana|logstash)" || warn "No ELK volumes found"

log "Volume sizes:"
for vol in $(docker volume ls -q | grep -E "(elasticsearch|kibana)"); do
    SIZE=$(docker system df -v | grep "$vol" | awk '{print $3}' 2>/dev/null || echo "Unknown")
    log "  $vol: $SIZE"
done

section "8. Memory Usage"

if docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep -E "(elasticsearch|kibana|logstash)" >/dev/null; then
    log "Container resource usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(Container|elasticsearch|kibana|logstash)"
else
    warn "No running ELK containers to show stats"
fi

section "9. Common Issues Check"

# Check for common configuration errors
log "Checking for common configuration issues..."

# Check xpack.security configuration
if [[ -f "configs/elk/kibana/kibana.yml" ]]; then
    if grep -q "xpack.security.enabled" configs/elk/kibana/kibana.yml; then
        error "Found 'xpack.security.enabled' in Kibana config - this causes issues in v9.1.2"
        log "  Recommendation: Remove this line from configs/elk/kibana/kibana.yml"
    else
        log "✅ No problematic xpack.security.enabled in Kibana config"
    fi
fi

# Check logging configuration
if [[ -f "configs/elk/kibana/kibana.yml" ]]; then
    if grep -q "logging.level:" configs/elk/kibana/kibana.yml; then
        warn "Found 'logging.level:' in Kibana config - this may cause issues in v9.1.2"
        log "  Recommendation: Use structured logging configuration instead"
    fi
fi

section "10. Recommendations"

echo -e "\n${YELLOW}💡 Troubleshooting Recommendations:${NC}"

if ! curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
    echo "• Elasticsearch Issues:"
    echo "  - Check logs: docker logs sentinel-test-elasticsearch"
    echo "  - Verify memory allocation: ES_JAVA_OPTS=-Xms1g -Xmx1g"
    echo "  - Ensure port 9200 is not used by another service"
fi

if ! curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
    echo "• Kibana Issues:"
    echo "  - Check logs: docker logs sentinel-test-kibana"
    echo "  - Remove xpack.security.enabled from kibana.yml if present"
    echo "  - Ensure Elasticsearch is healthy before starting Kibana"
    echo "  - Wait 2-3 minutes for Kibana first-time setup"
fi

echo "• General:"
echo "  - Use: ./fix-elk-v9-compatibility.sh to apply all fixes"
echo "  - Restart services: docker compose -f docker-compose-test.yml restart"
echo "  - Clean restart: docker compose -f docker-compose-test.yml down -v && ./fix-elk-v9-compatibility.sh"

echo -e "\n${CYAN}Diagnostic complete!${NC}"
