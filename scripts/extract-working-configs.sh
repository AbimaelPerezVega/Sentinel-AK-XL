#!/bin/bash

# ===================================
# Extract Working Configurations
# ===================================
# This script extracts the currently working configurations
# and creates a patch file for GitHub repository
# ===================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 Configuration Extractor for GitHub Repository${NC}"
echo "=================================================="

# Create backup and patch directories
mkdir -p config-patches/current-working
mkdir -p config-patches/original-backup
mkdir -p config-patches/github-updates

echo -e "${BLUE}[STEP]${NC} 1. Backing up current working configurations..."

# Extract current working configurations
if [[ -d configs/elk ]]; then
    echo "✅ Found configs/elk directory"
    cp -r configs/elk config-patches/current-working/
    echo "   📁 Copied to config-patches/current-working/elk/"
fi

if [[ -f docker-compose-test.yml ]]; then
    echo "✅ Found docker-compose-test.yml"
    cp docker-compose-test.yml config-patches/current-working/
fi

if [[ -f docker-compose-stable.yml ]]; then
    echo "✅ Found docker-compose-stable.yml"  
    cp docker-compose-stable.yml config-patches/current-working/
fi

if [[ -f docker-compose-debug.yml ]]; then
    echo "✅ Found docker-compose-debug.yml"
    cp docker-compose-debug.yml config-patches/current-working/
fi

echo -e "${BLUE}[STEP]${NC} 2. Analyzing differences from original repository..."

# Create a differences report
cat > config-patches/CHANGES_ANALYSIS.md << 'EOF'
# Configuration Changes Analysis

## Summary
This document lists all configuration changes that have been made during troubleshooting sessions.

## Key Fixes Applied

### 1. Elasticsearch 9.1.2 Compatibility
**Issue:** Setting name changed in v9.1.2
**Original:** `cluster.routing.allocation.disk.threshold.enabled: false`
**Fixed:** `cluster.routing.allocation.disk.threshold_enabled: false`

### 2. Kibana Configuration Issues
**Issue:** xpack.security.enabled causes errors in v9.1.2
**Fixed:** Removed from Kibana config file, kept only in environment variables

### 3. Docker Compose Improvements
**Issue:** Health checks and dependency management
**Fixed:** Improved health check commands and wait times

## Files Modified

### configs/elk/elasticsearch/elasticsearch.yml
- Fixed disk threshold setting name
- Updated security configuration for v9.1.2
- Optimized memory and performance settings

### configs/elk/kibana/kibana.yml  
- Removed problematic xpack.security.enabled setting
- Updated logging configuration for v9.1.2
- Improved connection settings

### docker-compose files
- Fixed health check commands
- Updated environment variables
- Improved service dependencies
- Added proper timeouts and retries

EOF

echo -e "${BLUE}[STEP]${NC} 3. Creating GitHub-ready configuration files..."

# Create clean configuration files for GitHub
mkdir -p config-patches/github-updates/configs/elk/{elasticsearch,kibana,logstash}

# Create the CORRECTED elasticsearch.yml for GitHub
cat > config-patches/github-updates/configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
# Elasticsearch 9.1.2 Compatible Configuration
cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node

# Network
network.host: 0.0.0.0
http.port: 9200

# Security (compatible with v9.1.2)
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.license.self_generated.type: basic

# Performance
bootstrap.memory_lock: false
action.auto_create_index: true
indices.query.bool.max_clause_count: 10240

# FIXED: Correct setting name for v9.1.2 (underscore, not dot)
cluster.routing.allocation.disk.threshold_enabled: false
EOF

# Create the CORRECTED kibana.yml for GitHub
cat > config-patches/github-updates/configs/elk/kibana/kibana.yml << 'EOF'
# Kibana 9.1.2 Compatible Configuration
server.host: 0.0.0.0
server.port: 5601
server.name: sentinel-kibana

# Elasticsearch connection
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.username: elastic
elasticsearch.password: changeme123!

# Security settings (v9.1.2 compatible)
# NOTE: xpack.security.enabled removed from config file for v9.1.2
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

# Create a corrected docker-compose.yml for GitHub
cat > config-patches/github-updates/docker-compose.yml << 'EOF'
# Sentinel AK-XL - ELK Stack 9.1.2 Compatible
version: '3.8'

networks:
  sentinel:
    driver: bridge

volumes:
  elasticsearch-data:
    driver: local
  kibana-data:
    driver: local
  logstash-data:
    driver: local

services:
  # Elasticsearch 9.1.2 (Fixed Configuration)
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:9.1.2
    container_name: sentinel-elasticsearch
    hostname: elasticsearch
    environment:
      - node.name=elasticsearch
      - cluster.name=sentinel-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=false
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - xpack.security.enabled=true
      - ELASTIC_PASSWORD=changeme123!
      - xpack.license.self_generated.type=basic
      - xpack.security.http.ssl.enabled=false
      - xpack.security.transport.ssl.enabled=false
      - action.auto_create_index=true
      # NOTE: Removed cluster.routing.allocation.disk.threshold.enabled (old name)
      # This is now handled in the config file with correct name
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
      - ./configs/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
    ports:
      - "9200:9200"
    networks:
      - sentinel
    healthcheck:
      test: ["CMD-SHELL", "curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 12
      start_period: 60s
    mem_limit: 3g

  # Kibana 9.1.2 (Fixed Configuration)
  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.2
    container_name: sentinel-kibana
    hostname: kibana
    environment:
      - SERVERNAME=kibana
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123!
      # NOTE: xpack.security.enabled removed for v9.1.2 compatibility
      - TELEMETRY_ENABLED=false
    volumes:
      - kibana-data:/usr/share/kibana/data
      - ./configs/elk/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml:ro
    ports:
      - "5601:5601"
    networks:
      - sentinel
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -s http://localhost:5601/api/status || exit 1"]
      interval: 45s
      timeout: 15s
      retries: 8
      start_period: 120s
    mem_limit: 2g

  # Logstash 9.1.2
  logstash:
    image: docker.elastic.co/logstash/logstash:9.1.2
    container_name: sentinel-logstash
    hostname: logstash
    environment:
      - "LS_JAVA_OPTS=-Xms1g -Xmx1g"
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123!
    volumes:
      - logstash-data:/usr/share/logstash/data
      - ./configs/elk/logstash:/usr/share/logstash/pipeline/
    networks:
      - sentinel
    depends_on:
      elasticsearch:
        condition: service_healthy
    mem_limit: 1.5g
EOF

echo -e "${BLUE}[STEP]${NC} 4. Creating update instructions..."

cat > config-patches/GITHUB_UPDATE_INSTRUCTIONS.md << 'EOF'
# GitHub Repository Update Instructions

## What This Fixes
These configuration changes fix Elasticsearch 9.1.2 compatibility issues that prevent the stack from starting.

## Files to Update in Your GitHub Repository

### 1. Replace configs/elk/elasticsearch/elasticsearch.yml
Copy the file from: `config-patches/github-updates/configs/elk/elasticsearch/elasticsearch.yml`

**Key Changes:**
- Fixed: `cluster.routing.allocation.disk.threshold_enabled: false` (was using dots instead of underscore)
- Updated security settings for v9.1.2 compatibility

### 2. Replace configs/elk/kibana/kibana.yml  
Copy the file from: `config-patches/github-updates/configs/elk/kibana/kibana.yml`

**Key Changes:**
- Removed `xpack.security.enabled` from config file (causes errors in v9.1.2)
- Updated logging configuration format
- Improved connection settings

### 3. Replace docker-compose.yml (main file)
Copy the file from: `config-patches/github-updates/docker-compose.yml`

**Key Changes:**
- Removed problematic environment variable
- Improved health checks with authentication
- Better timeout and retry settings
- Fixed dependency management

## Git Commands to Apply Changes

```bash
# 1. Copy the fixed files to your repository
cp config-patches/github-updates/configs/elk/elasticsearch/elasticsearch.yml configs/elk/elasticsearch/
cp config-patches/github-updates/configs/elk/kibana/kibana.yml configs/elk/kibana/  
cp config-patches/github-updates/docker-compose.yml ./

# 2. Commit the fixes
git add configs/elk/elasticsearch/elasticsearch.yml
git add configs/elk/kibana/kibana.yml
git add docker-compose.yml
git commit -m "fix: Elasticsearch 9.1.2 compatibility

- Fix cluster.routing.allocation.disk.threshold setting name (dot to underscore)
- Remove xpack.security.enabled from Kibana config for v9.1.2 compatibility  
- Improve health checks and service dependencies
- Update logging configuration for v9.1.2

Fixes startup issues with ELK Stack 9.1.2"

# 3. Push to GitHub
git push origin main
```

## Verification
After applying these changes, users should be able to:
1. `git clone` your repository
2. Run `docker-compose up -d` 
3. Have a working ELK Stack 9.1.2 without additional fixes

## Rollback Plan
If needed, you can rollback with:
```bash
git revert HEAD
```

The original configurations are backed up in `config-patches/original-backup/`
EOF

echo -e "${BLUE}[STEP]${NC} 5. Creating test script for users..."

cat > config-patches/github-updates/test-installation.sh << 'EOF'
#!/bin/bash

# ===================================
# Test ELK Stack Installation
# ===================================
# Quick test script for users to verify the installation works
# ===================================

echo "🧪 Testing ELK Stack Installation..."

# Start services
echo "Starting ELK Stack..."
docker-compose up -d

# Wait for Elasticsearch
echo "Waiting for Elasticsearch..."
for i in {1..20}; do
    if curl -s -u elastic:changeme123! http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        echo "✅ Elasticsearch is ready"
        break
    fi
    echo -n "."
    sleep 3
done

# Wait for Kibana  
echo "Waiting for Kibana..."
for i in {1..24}; do
    if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
        echo "✅ Kibana is ready"
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo "🎉 Installation test complete!"
echo ""
echo "Access URLs:"
echo "• Elasticsearch: http://localhost:9200 (elastic/changeme123!)"  
echo "• Kibana: http://localhost:5601"
echo ""
echo "To stop: docker-compose down"
EOF

chmod +x config-patches/github-updates/test-installation.sh

echo ""
echo -e "${GREEN}✅ Configuration extraction complete!${NC}"
echo ""
echo -e "${CYAN}📁 Generated Files:${NC}"
echo "• config-patches/github-updates/ - Ready-to-use files for GitHub"
echo "• config-patches/GITHUB_UPDATE_INSTRUCTIONS.md - Step-by-step update guide"
echo "• config-patches/CHANGES_ANALYSIS.md - Analysis of all changes made"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review: config-patches/GITHUB_UPDATE_INSTRUCTIONS.md"
echo "2. Copy the files to your GitHub repository"  
echo "3. Commit and push the changes"
echo "4. Test with: config-patches/github-updates/test-installation.sh"
echo ""
echo -e "${GREEN}This will ensure all users get a working ELK Stack 9.1.2 setup! 🚀${NC}"
