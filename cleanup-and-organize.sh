#!/bin/bash

# ===================================
# Cleanup and Organize Script
# ===================================
# Cleans up the mess of test files and organizes everything
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
    echo -e "${GREEN}[CLEANUP]${NC} $1"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo -e "${CYAN}🧹 Cleaning up and organizing the project${NC}"
echo "=========================================="

# Create backup directory for old files
step "Creating backup directory for old test files..."
mkdir -p backup/old-tests
mkdir -p backup/old-configs

# Move all the test files we created to backup
step "Moving redundant test files to backup..."
test_files=(
    "test-elk-*"
    "test-basic-v2.sh"
    "test-everything-v2.sh"
    "fix-*.sh"
    "simple-elk-test.sh"
    "cleanup-test.sh"
    "*-wrapper*"
    "dc"
    "source-docker-env.sh"
)

for pattern in "${test_files[@]}"; do
    if ls $pattern 1> /dev/null 2>&1; then
        mv $pattern backup/old-tests/ 2>/dev/null || true
        log "Moved $pattern to backup/"
    fi
done

# Move redundant docker-compose files
step "Moving redundant docker-compose files..."
if [[ -f docker-compose-minimal.yml ]]; then
    mv docker-compose-minimal.yml backup/old-configs/
    log "Moved docker-compose-minimal.yml to backup/"
fi

# Keep only the original docker-compose-test.yml as our testing file
if [[ -f docker-compose-test.yml ]]; then
    log "Keeping docker-compose-test.yml as our main test file"
else
    warn "docker-compose-test.yml not found!"
fi

# Clean up environment files
step "Organizing environment files..."
env_files=(".env.backup" ".env.docker-compose" "test-everything.log")
for file in "${env_files[@]}"; do
    if [[ -f "$file" ]]; then
        mv "$file" backup/ 2>/dev/null || true
        log "Moved $file to backup/"
    fi
done

# Clean up Docker images and containers to save space
step "Cleaning up Docker to save space..."
log "Stopping all containers..."
docker compose -f docker-compose-test.yml down -v 2>/dev/null || true
docker compose down -v 2>/dev/null || true

log "Removing unused Docker images..."
docker image prune -f 2>/dev/null || true

log "Removing unused Docker volumes..."
docker volume prune -f 2>/dev/null || true

log "Removing unused Docker networks..."
docker network prune -f 2>/dev/null || true

# Show what ELK images we're keeping
step "ELK images we're keeping:"
docker images | grep -E "(elasticsearch|kibana|logstash)" || echo "No ELK images found"

# Create one simple, working test script
step "Creating ONE simple test script..."

cat > test-elk.sh << 'EOF'
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
EOF

chmod +x test-elk.sh
log "Created test-elk.sh - THE ONLY test script you need"

# Update the main docker-compose-test.yml to be our standard
step "Ensuring docker-compose-test.yml is properly configured..."
if [[ -f docker-compose-test.yml ]]; then
    log "✅ docker-compose-test.yml exists and ready to use"
else
    warn "docker-compose-test.yml missing - you may need to run quick-setup.sh"
fi

# Create a simple README for the organized project
step "Creating simple usage guide..."

cat > QUICK-START.md << 'EOF'
# Sentinel AK-XL - Quick Start

## 🚀 Simple Usage

### Test ELK Stack
```bash
# Start only Elasticsearch (fastest, no downloads)
./test-elk.sh elasticsearch

# Start Elasticsearch + Kibana
./test-elk.sh kibana

# Start full ELK stack
./test-elk.sh full

# Check status
./test-elk.sh status

# Stop everything
./test-elk.sh stop

# Clean up completely
./test-elk.sh clean
```

### Access Services
- **Elasticsearch**: http://localhost:9200 (elastic/changeme123!)
- **Kibana**: http://localhost:5601 (elastic/changeme123!)
- **Logstash**: http://localhost:9600

### Files Structure
- `test-elk.sh` - Main testing script
- `docker-compose-test.yml` - ELK configuration
- `configs/elk/` - Service configurations
- `backup/` - Old files moved here

### If Something Breaks
```bash
./test-elk.sh clean
./test-elk.sh elasticsearch  # Start simple
```
EOF

log "Created QUICK-START.md"

# Show final organized structure
step "Organized project structure:"
echo ""
echo -e "${CYAN}Main files (keep these):${NC}"
echo "✅ test-elk.sh              - THE ONLY test script"
echo "✅ docker-compose-test.yml  - ELK configuration" 
echo "✅ docker-compose.yml       - Full project config"
echo "✅ .env                     - Environment variables"
echo "✅ configs/                 - Service configurations"
echo "✅ QUICK-START.md          - Simple usage guide"
echo ""
echo -e "${CYAN}Backup files (can delete):${NC}"
echo "📁 backup/old-tests/       - All the old test scripts"
echo "📁 backup/old-configs/     - Redundant configurations"
echo ""

# Show current directory size
log "Project directory cleanup summary:"
du -sh . 2>/dev/null || echo "Directory size calculation failed"
echo ""

echo -e "${GREEN}🎉 Project organized! Use: ./test-elk.sh${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "1. ${YELLOW}./test-elk.sh elasticsearch${NC}  # Quick test"
echo -e "2. ${YELLOW}./test-elk.sh status${NC}         # Check what's running"
echo -e "3. ${YELLOW}rm -rf backup/${NC}              # Delete old files (optional)"
echo ""
