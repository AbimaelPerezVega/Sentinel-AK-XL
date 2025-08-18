#!/bin/bash

# ===================================
# Fix Elasticsearch Configuration
# ===================================
# Removes index-level settings from node configuration
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

echo -e "${CYAN}🔧 Fixing Elasticsearch Configuration${NC}"

# Fix the Elasticsearch configuration
step "Updating Elasticsearch configuration..."

cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
# Basic Elasticsearch Configuration for Testing
cluster.name: sentinel-cluster
node.name: sentinel-elasticsearch-node
discovery.type: single-node

# Network
network.host: 0.0.0.0
http.port: 9200

# Security
xpack.security.enabled: true
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.license.self_generated.type: basic

# Performance
bootstrap.memory_lock: true
indices.query.bool.max_clause_count: 10240

# Cluster settings
action.auto_create_index: true

# NOTE: Index-level settings removed from node config
# These will be set via index templates instead
EOF

log "✅ Updated Elasticsearch configuration"

# Fix the test-everything-v2.sh syntax error
step "Fixing test-everything-v2.sh syntax error..."

if [[ -f test-everything-v2.sh ]]; then
    # Fix the malformed filename
    sed -i 's/docker compose-test\.yml/docker-compose-test.yml/g' test-everything-v2.sh
    log "✅ Fixed test-everything-v2.sh syntax error"
else
    log "⚠️  test-everything-v2.sh not found"
fi

# Update docker-compose-test.yml to remove obsolete version
step "Updating docker-compose-test.yml..."

if [[ -f docker-compose-test.yml ]]; then
    # Remove the version line to avoid warnings
    sed -i '/^version:/d' docker-compose-test.yml
    log "✅ Removed obsolete version from docker-compose-test.yml"
fi

log "🎉 Configuration fixes completed!"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "1. Test Elasticsearch: ${YELLOW}./test-elk-verbose.sh${NC}"
echo -e "2. Or use fixed v2 script: ${YELLOW}./test-everything-v2.sh${NC}"
