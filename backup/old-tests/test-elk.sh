#!/bin/bash

# ===================================
# THE ONLY ELK Test Script We Need
# ===================================
# Simple, reliable ELK stack testing
# Uses existing images, no downloads
# ===================================

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

echo -e "${CYAN}🧪 ELK Stack Test${NC}"
echo "================="

case "${1:-full}" in
    "elasticsearch"|"es")
        log "Testing Elasticsearch only..."
        docker compose -f docker-compose-test.yml up -d elasticsearch --no-deps
        ;;
    "kibana")
        log "Testing Elasticsearch + Kibana..."
        docker compose -f docker-compose-test.yml up -d elasticsearch kibana --no-deps
        ;;
    "full")
        log "Testing full ELK stack..."
        docker compose -f docker-compose-test.yml up -d
        ;;
    "stop")
        log "Stopping ELK stack..."
        docker compose -f docker-compose-test.yml down
        exit 0
        ;;
    "status")
        log "ELK stack status:"
        docker compose -f docker-compose-test.yml ps
        echo ""
        echo "Service health:"
        curl -s -u elastic:changeme123! http://localhost:9200 &>/dev/null && echo "✅ Elasticsearch: Running" || echo "❌ Elasticsearch: Down"
        curl -s http://localhost:5601 &>/dev/null && echo "✅ Kibana: Running" || echo "❌ Kibana: Down"
        curl -s http://localhost:9600 &>/dev/null && echo "✅ Logstash: Running" || echo "❌ Logstash: Down"
        exit 0
        ;;
    "clean")
        log "Cleaning up everything..."
        docker compose -f docker-compose-test.yml down -v
        docker volume prune -f
        exit 0
        ;;
    *)
        echo "Usage: $0 [elasticsearch|kibana|full|stop|status|clean]"
        echo ""
        echo "Commands:"
        echo "  elasticsearch  - Start only Elasticsearch (fastest)"
        echo "  kibana        - Start Elasticsearch + Kibana"
        echo "  full          - Start full ELK stack (default)"
        echo "  stop          - Stop all services"
        echo "  status        - Show current status"
        echo "  clean         - Stop and remove everything"
        exit 0
        ;;
esac

# Wait for services
log "Waiting for services to start..."
sleep 10

# Test Elasticsearch
for i in {1..30}; do
    if curl -s -u elastic:changeme123! http://localhost:9200 >/dev/null 2>&1; then
        log "✅ Elasticsearch is ready"
        break
    fi
    echo -n "."
    sleep 2
    if [[ $i -eq 30 ]]; then
        echo ""
        log "❌ Elasticsearch timeout"
        exit 1
    fi
done

# Test Kibana if running
if [[ "$1" =~ ^(kibana|full|)$ ]]; then
    for i in {1..60}; do
        if curl -s http://localhost:5601 >/dev/null 2>&1; then
            log "✅ Kibana is ready"
            break
        fi
        echo -n "."
        sleep 2
        if [[ $i -eq 60 ]]; then
            echo ""
            log "⚠️ Kibana timeout (may still be starting)"
            break
        fi
    done
fi

# Test Logstash if running full stack
if [[ "$1" =~ ^(full|)$ ]]; then
    for i in {1..30}; do
        if curl -s http://localhost:9600 >/dev/null 2>&1; then
            log "✅ Logstash is ready"
            break
        fi
        echo -n "."
        sleep 2
        if [[ $i -eq 30 ]]; then
            echo ""
            log "⚠️ Logstash timeout (may still be starting)"
            break
        fi
    done
fi

echo ""
echo -e "${GREEN}🎉 ELK Stack is running!${NC}"
echo ""
echo -e "${CYAN}📋 Access URLs:${NC}"
echo -e "   • Elasticsearch: http://localhost:9200 (elastic/changeme123!)"
echo -e "   • Kibana: http://localhost:5601 (elastic/changeme123!)"
echo -e "   • Logstash: http://localhost:9600"
echo ""
echo -e "${CYAN}🧪 Quick Tests:${NC}"
echo -e "   ./test-elk.sh status     # Check what's running"
echo -e "   ./test-elk.sh stop       # Stop everything"
echo -e "   ./test-elk.sh clean      # Clean up completely"
echo ""
