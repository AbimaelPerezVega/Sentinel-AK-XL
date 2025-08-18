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
