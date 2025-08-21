#!/bin/bash

# ===================================
# Configuration Comparison Tool
# ===================================
# Compares your current config with expected templates
# Helps identify missing or incorrect configurations
# ===================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 Sentinel AK-XL Configuration Comparison Tool${NC}"
echo "=================================================="

# Create reference configurations directory
REF_DIR="reference_configs"
mkdir -p "$REF_DIR"

# ===================================
# Generate Reference Configurations
# ===================================

create_reference_elasticsearch_config() {
    cat > "$REF_DIR/elasticsearch.yml" << 'EOF'
# Elasticsearch 9.1.2 Compatible Configuration
cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node

# Network
network.host: 0.0.0.0
http.port: 9200

# Security (basic setup for development)
xpack.security.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
xpack.license.self_generated.type: basic

# Performance and stability
bootstrap.memory_lock: false
action.auto_create_index: true
indices.query.bool.max_clause_count: 10240

# Memory settings (CORRECT: underscore not dot)
cluster.routing.allocation.disk.threshold_enabled: false
EOF
}

create_reference_kibana_config() {
    cat > "$REF_DIR/kibana.yml" << 'EOF'
# Kibana 9.1.2 Compatible Configuration
server.host: 0.0.0.0
server.port: 5601
server.name: sentinel-kibana

# Elasticsearch connection
elasticsearch.hosts: ["http://elasticsearch:9200"]

# Security settings for v9 (no authentication for development)
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
}

create_reference_docker_compose() {
    cat > "$REF_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

networks:
  sentinel-network:
    name: sentinel-network
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  elasticsearch-data:
  kibana-data:
  logstash-data:

services:
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
      - xpack.security.enabled=false
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
      - ./configs/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
    ports:
      - "9200:9200"
    networks:
      sentinel-network:
        ipv4_address: 172.20.0.10
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.2
    container_name: sentinel-kibana
    hostname: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    volumes:
      - kibana-data:/usr/share/kibana/data
      - ./configs/elk/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml:ro
    ports:
      - "5601:5601"
    networks:
      sentinel-network:
        ipv4_address: 172.20.0.11
    depends_on:
      elasticsearch:
        condition: service_healthy

  logstash:
    image: docker.elastic.co/logstash/logstash:9.1.2
    container_name: sentinel-logstash
    hostname: logstash
    environment:
      - "LS_JAVA_OPTS=-Xms1g -Xmx1g"
    volumes:
      - ./configs/elk/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./configs/elk/logstash/pipelines.yml:/usr/share/logstash/config/pipelines.yml:ro
      - ./configs/elk/logstash/conf.d:/usr/share/logstash/pipeline/:ro
    ports:
      - "5044:5044"
      - "9600:9600"
    networks:
      sentinel-network:
        ipv4_address: 172.20.0.12
    depends_on:
      elasticsearch:
        condition: service_healthy
EOF
}

create_reference_env() {
    cat > "$REF_DIR/.env" << 'EOF'
# Sentinel AK-XL Environment Configuration
COMPOSE_PROJECT_NAME=sentinel-ak-xl

# Memory Settings (adjust based on your system)
ES_MEM=2g
KIBANA_MEM=1g
LOGSTASH_MEM=1g
WAZUH_MEM=1g

# Credentials (change for production)
ELASTIC_PASSWORD=changeme123!
WAZUH_INDEXER_PASSWORD=SecretPassword

# Network Configuration
SUBNET=172.20.0.0/16
EOF
}

# ===================================
# Comparison Functions
# ===================================

compare_file() {
    local reference_file="$1"
    local actual_file="$2"
    local file_name="$3"
    
    echo -e "\n${BLUE}📄 Comparing: $file_name${NC}"
    echo "----------------------------------------"
    
    if [[ ! -f "$actual_file" ]]; then
        echo -e "${RED}❌ File missing: $actual_file${NC}"
        echo -e "${YELLOW}Expected location: $actual_file${NC}"
        return 1
    fi
    
    if [[ ! -f "$reference_file" ]]; then
        echo -e "${RED}❌ Reference file missing: $reference_file${NC}"
        return 1
    fi
    
    # Basic comparison
    if diff -q "$reference_file" "$actual_file" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Files are identical${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}⚠️  Files differ${NC}"
    echo ""
    echo -e "${CYAN}Key differences:${NC}"
    
    # Show important differences
    diff -u "$reference_file" "$actual_file" | head -20 | while read -r line; do
        if [[ $line =~ ^- ]]; then
            echo -e "${RED}  $line${NC}"
        elif [[ $line =~ ^+ ]]; then
            echo -e "${GREEN}  $line${NC}"
        elif [[ $line =~ ^@@ ]]; then
            echo -e "${CYAN}  $line${NC}"
        fi
    done
    
    return 1
}

check_critical_settings() {
    local file="$1"
    local file_type="$2"
    
    echo -e "\n${BLUE}🔍 Checking critical settings in $file_type${NC}"
    
    case "$file_type" in
        "elasticsearch")
            # Check for the problematic setting: cluster.routing.allocation.disk.threshold.enabled (with dot before enabled)
            if grep -q "cluster\.routing\.allocation\.disk\.threshold\.enabled" "$file" 2>/dev/null; then
                echo -e "${RED}❌ CRITICAL: Found problematic setting with dot before 'enabled'${NC}"
                echo -e "${YELLOW}   Found: $(grep -n "cluster\.routing\.allocation\.disk\.threshold\.enabled" "$file")${NC}"
                echo -e "${GREEN}   Should be: cluster.routing.allocation.disk.threshold_enabled: false${NC}"
            # Check for correct setting: cluster.routing.allocation.disk.threshold_enabled (with underscore before enabled)
            elif grep -q "cluster\.routing\.allocation\.disk\.threshold_enabled" "$file" 2>/dev/null; then
                echo -e "${GREEN}✅ Correct setting found (underscore before 'enabled')${NC}"
                local line_info=$(grep -n "cluster\.routing\.allocation\.disk\.threshold_enabled" "$file")
                echo -e "${BLUE}   $line_info${NC}"
            else
                echo -e "${BLUE}ℹ️  Disk threshold setting not configured (using defaults)${NC}"
            fi
            
            # Check security setting
            if grep -q "xpack.security.enabled: true" "$file" 2>/dev/null; then
                echo -e "${YELLOW}⚠️  Security enabled (may cause issues in development)${NC}"
            fi
            ;;
            
        "kibana")
            # Check for problematic v9.1.2 settings
            if grep -q "xpack.security.enabled" "$file" 2>/dev/null; then
                echo -e "${YELLOW}⚠️  Found xpack.security.enabled in Kibana config${NC}"
                echo -e "${YELLOW}   This can cause issues in Kibana 9.1.2${NC}"
            else
                echo -e "${GREEN}✅ No problematic security settings found${NC}"
            fi
            
            # Check Elasticsearch connection
            if grep -q "elasticsearch.hosts" "$file" 2>/dev/null; then
                echo -e "${GREEN}✅ Elasticsearch hosts configured${NC}"
            else
                echo -e "${RED}❌ Missing elasticsearch.hosts configuration${NC}"
            fi
            ;;
            
        "docker-compose")
            # Check for authentication issues
            if grep -q "ELASTICSEARCH_USERNAME.*elastic" "$file" 2>/dev/null; then
                echo -e "${YELLOW}⚠️  Found hardcoded elastic user (may cause v9.1.2 issues)${NC}"
            else
                echo -e "${GREEN}✅ No hardcoded authentication found${NC}"
            fi
            
            # Check memory settings
            if grep -q "ES_JAVA_OPTS" "$file" 2>/dev/null; then
                echo -e "${GREEN}✅ Memory configuration found${NC}"
                mem_setting=$(grep "ES_JAVA_OPTS" "$file" | head -1)
                echo -e "${BLUE}   Current: $mem_setting${NC}"
            else
                echo -e "${YELLOW}⚠️  No explicit memory configuration${NC}"
            fi
            ;;
    esac
}

# ===================================
# Main Execution
# ===================================

main() {
    echo "Generating reference configurations..."
    
    # Create reference files
    create_reference_elasticsearch_config
    create_reference_kibana_config  
    create_reference_docker_compose
    create_reference_env
    
    echo -e "${GREEN}✅ Reference configurations created in $REF_DIR/${NC}"
    
    # Compare files
    local comparison_results=0
    
    # Compare Elasticsearch config
    if compare_file "$REF_DIR/elasticsearch.yml" "configs/elk/elasticsearch/elasticsearch.yml" "Elasticsearch Config"; then
        ((comparison_results++))
    fi
    check_critical_settings "configs/elk/elasticsearch/elasticsearch.yml" "elasticsearch"
    
    # Compare Kibana config
    if compare_file "$REF_DIR/kibana.yml" "configs/elk/kibana/kibana.yml" "Kibana Config"; then
        ((comparison_results++))
    fi
    check_critical_settings "configs/elk/kibana/kibana.yml" "kibana"
    
    # Compare Docker Compose
    if compare_file "$REF_DIR/docker-compose.yml" "docker-compose.yml" "Docker Compose"; then
        ((comparison_results++))
    fi
    check_critical_settings "docker-compose.yml" "docker-compose"
    
    # Compare .env (optional)
    if [[ -f ".env" ]]; then
        compare_file "$REF_DIR/.env" ".env" "Environment File"
    else
        echo -e "\n${YELLOW}⚠️  .env file not found (optional but recommended)${NC}"
        echo -e "${BLUE}   You can copy from: $REF_DIR/.env${NC}"
    fi
    
    # Summary
    echo -e "\n${CYAN}📊 COMPARISON SUMMARY${NC}"
    echo "=================================================="
    
    if [[ $comparison_results -eq 3 ]]; then
        echo -e "${GREEN}🎉 All core configurations match references!${NC}"
        echo -e "${GREEN}Your setup should work correctly for team members.${NC}"
    else
        echo -e "${YELLOW}⚠️  Some configurations differ from references${NC}"
        echo -e "${BLUE}This might be OK if differences are intentional${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "1. Review the differences shown above"
        echo "2. Copy reference files if needed:"
        echo "   cp $REF_DIR/elasticsearch.yml configs/elk/elasticsearch/"
        echo "   cp $REF_DIR/kibana.yml configs/elk/kibana/"
        echo "   cp $REF_DIR/docker-compose.yml ."
        echo "3. Test with team validation script: ./validate-for-team.sh"
    fi
    
    echo -e "\n${BLUE}📁 Reference files available in: $REF_DIR/${NC}"
    echo -e "${BLUE}You can use these as templates or copy them directly${NC}"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
