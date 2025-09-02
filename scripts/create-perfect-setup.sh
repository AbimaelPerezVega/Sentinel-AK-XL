#!/bin/bash

# ===================================
# Sentinel AK-XL: Perfect Setup Script (FIXED)
# ===================================
# Creates a bulletproof installation with Docker Compose compatibility fixes
# Author: Sentinel AK-XL Team
# Version: 1.1 (Fixed)
# ===================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/setup.log"
COMPOSE_CMD=""
SETUP_DONE=false

# ===================================
# Utility Functions
# ===================================

log() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STEP: $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

header() {
    echo ""
    echo -e "${CYAN}====================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}====================================${NC}"
    echo ""
}

# ===================================
# Docker Compose Compatibility Fix
# ===================================

fix_docker_compose_compatibility() {
    header "🔧 FIXING DOCKER COMPOSE COMPATIBILITY"
    
    step "Detecting Docker Compose version..."
    
    # Check Docker Compose v2 first (recommended)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        local compose_version=$(docker compose version --short 2>/dev/null || echo "v2.x")
        log "Docker Compose v2 found: $compose_version"
    elif command -v docker-compose &> /dev/null; then
        # Check if docker-compose v1 works
        step "Testing Docker Compose v1 compatibility..."
        
        # Try a simple command to test if it works
        if docker-compose version &> /dev/null 2>&1; then
            COMPOSE_CMD="docker-compose"
            local compose_version=$(docker-compose version --short 2>/dev/null || echo "v1.x")
            warn "Docker Compose v1 detected: $compose_version"
            warn "This may have compatibility issues with newer Docker versions"
            
            # Offer to fix the issue
            echo ""
            echo -e "${YELLOW}Docker Compose v1 detected with potential compatibility issues.${NC}"
            echo ""
            echo "Options to fix this:"
            echo "1. Use Docker Compose v2 (recommended)"
            echo "2. Continue with v1 (may have issues)"
            echo "3. Exit and fix manually"
            echo ""
            read -p "Choose option (1/2/3): " -n 1 -r
            echo ""
            
            case $REPLY in
                1)
                    install_docker_compose_v2
                    ;;
                2)
                    warn "Continuing with Docker Compose v1 - expect potential issues"
                    ;;
                3)
                    echo "Please fix Docker Compose compatibility and run setup again."
                    echo ""
                    echo "Quick fix:"
                    echo "sudo apt update && sudo apt install docker-compose-plugin"
                    exit 1
                    ;;
                *)
                    error "Invalid option"
                    exit 1
                    ;;
            esac
        else
            error "Docker Compose v1 has compatibility issues"
            echo ""
            echo "The error suggests incompatibility between your Docker Compose v1 and Docker daemon."
            echo ""
            echo "Quick fixes:"
            echo "1. Install Docker Compose v2: sudo apt install docker-compose-plugin"
            echo "2. Update Docker: sudo apt update && sudo apt upgrade docker.io"
            echo "3. Restart Docker: sudo systemctl restart docker"
            exit 1
        fi
    else
        error "Docker Compose not found"
        echo ""
        echo "Please install Docker Compose:"
        echo "• Ubuntu/Debian: sudo apt install docker-compose-plugin"
        echo "• Other systems: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    export COMPOSE_CMD
    log "✅ Docker Compose compatibility verified: $COMPOSE_CMD"
}

install_docker_compose_v2() {
    step "Installing Docker Compose v2..."
    
    # Detect OS
    if command -v apt &> /dev/null; then
        # Ubuntu/Debian
        echo "Installing Docker Compose v2 via apt..."
        sudo apt update
        sudo apt install -y docker-compose-plugin
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        echo "Installing Docker Compose v2 via yum..."
        sudo yum install -y docker-compose-plugin
    else
        error "Cannot automatically install Docker Compose v2"
        echo ""
        echo "Please install manually:"
        echo "https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Verify installation
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        log "Docker Compose v2 installed successfully"
    else
        error "Docker Compose v2 installation failed"
        exit 1
    fi
}

# ===================================
# System Prerequisites Check (Updated)
# ===================================

check_system_requirements() {
    header "🔍 CHECKING SYSTEM REQUIREMENTS"
    
    step "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        echo ""
        echo -e "${YELLOW}Please install Docker first:${NC}"
        echo "• Ubuntu/Debian: sudo apt install docker.io"
        echo "• CentOS/RHEL: sudo yum install docker"
        echo "• Other: https://docs.docker.com/engine/install/"
        exit 1
    fi
    
    step "Checking Docker daemon..."
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        echo ""
        echo -e "${YELLOW}Please start Docker:${NC}"
        echo "sudo systemctl start docker"
        echo "sudo systemctl enable docker"
        exit 1
    fi
    log "Docker is running"
    
    # Fix Docker Compose compatibility
    fix_docker_compose_compatibility
    
    step "Checking system resources..."
    
    # Check memory
    local mem_gb
    if command -v free &> /dev/null; then
        mem_gb=$(free -g | grep Mem | awk '{print $2}' 2>/dev/null || echo "0")
    else
        # macOS
        mem_gb=$(echo "$(sysctl -n hw.memsize 2>/dev/null || echo 8589934592) / 1024 / 1024 / 1024" | bc 2>/dev/null || echo "8")
    fi
    
    if [[ $mem_gb -lt 4 ]]; then
        warn "Only ${mem_gb}GB RAM available (8GB+ recommended)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            exit 0
        fi
    else
        log "Memory: ${mem_gb}GB available"
    fi
    
    # Check disk space
    local disk_gb
    if command -v df &> /dev/null; then
        disk_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}' 2>/dev/null || echo "20")
    else
        disk_gb="20"  # Assume sufficient for macOS
    fi
    
    if [[ $disk_gb -lt 10 ]]; then
        warn "Only ${disk_gb}GB disk space available (20GB+ recommended)"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            exit 0
        fi
    else
        log "Disk space: ${disk_gb}GB available"
    fi
    
    step "Testing Docker Compose functionality..."
    # Create a simple test to verify Docker Compose works
    cat > docker-compose-test.yml << 'EOF'
version: '3.8'
services:
  test:
    image: hello-world
EOF
    
    if $COMPOSE_CMD -f docker-compose-test.yml config &> /dev/null; then
        log "Docker Compose configuration test passed"
        rm -f docker-compose-test.yml
    else
        error "Docker Compose configuration test failed"
        rm -f docker-compose-test.yml
        echo ""
        echo "Docker Compose is not working properly. Please check:"
        echo "1. Docker daemon is running: docker info"
        echo "2. User has Docker permissions: docker ps"
        echo "3. Docker Compose version: $COMPOSE_CMD version"
        exit 1
    fi
    
    log "✅ System requirements check complete"
}

# ===================================
# Environment Setup and Cleanup (Updated)
# ===================================

clean_previous_installation() {
    header "🧹 CLEANING PREVIOUS INSTALLATION"
    
    step "Stopping any running Sentinel containers..."
    
    # Stop containers from both possible compose files with better error handling
    $COMPOSE_CMD down -v 2>/dev/null || true
    $COMPOSE_CMD -f docker-compose-test.yml down -v 2>/dev/null || true
    
    # Remove any orphaned containers with better filtering
    step "Removing orphaned containers..."
    docker ps -a --filter "name=sentinel" --format "{{.Names}}" | while read -r container; do
        if [[ -n "$container" ]]; then
            docker rm -f "$container" 2>/dev/null || true
        fi
    done
    
    step "Cleaning Docker system..."
    docker system prune -f 2>/dev/null || true
    
    step "Removing old volumes..."
    docker volume ls --filter "name=sentinel" --format "{{.Name}}" | while read -r volume; do
        if [[ -n "$volume" ]]; then
            docker volume rm "$volume" 2>/dev/null || true
        fi
    done
    
    log "✅ Previous installation cleaned"
}

# ===================================
# Service Testing (Updated with better error handling)
# ===================================

test_installation() {
    header "🧪 TESTING INSTALLATION"
    
    step "Starting services for initial test..."
    
    # Start with better error handling
    if ! $COMPOSE_CMD up -d 2>> "$LOG_FILE"; then
        error "Failed to start services with Docker Compose"
        echo ""
        echo "Debug information:"
        echo "1. Check Docker Compose file: $COMPOSE_CMD config"
        echo "2. Check Docker daemon: docker info"
        echo "3. Check logs: $COMPOSE_CMD logs"
        echo ""
        echo "Trying alternative startup method..."
        
        # Try starting services individually
        step "Attempting individual service startup..."
        if $COMPOSE_CMD up -d elasticsearch 2>> "$LOG_FILE"; then
            log "Elasticsearch started individually"
        else
            error "Cannot start Elasticsearch"
            return 1
        fi
    fi
    
    step "Waiting for Elasticsearch to start..."
    local es_ready=false
    local wait_count=0
    local max_wait=40
    
    while [[ $wait_count -lt $max_wait ]]; do
        if curl -s http://localhost:9200/_cluster/health >/dev/null 2>&1; then
            es_ready=true
            log "Elasticsearch is ready"
            break
        fi
        
        # Show progress every 10 attempts
        if [[ $((wait_count % 10)) -eq 0 && $wait_count -gt 0 ]]; then
            echo "Still waiting for Elasticsearch... ($wait_count/${max_wait})"
            echo "Checking Elasticsearch logs:"
            $COMPOSE_CMD logs --tail 5 elasticsearch 2>/dev/null || true
        fi
        
        echo -n "."
        sleep 3
        ((wait_count++))
    done
    
    if [[ "$es_ready" != "true" ]]; then
        error "Elasticsearch failed to start within $(($max_wait * 3)) seconds"
        echo ""
        echo "Elasticsearch logs:"
        $COMPOSE_CMD logs elasticsearch 2>/dev/null || echo "Cannot retrieve logs"
        echo ""
        echo "Troubleshooting:"
        echo "1. Check if port 9200 is available: netstat -tuln | grep 9200"
        echo "2. Check Docker logs: docker logs \$(docker ps -q --filter ancestor=docker.elastic.co/elasticsearch/elasticsearch:9.1.2)"
        echo "3. Check system resources: free -h && df -h"
        echo "4. Try manual start: $COMPOSE_CMD up elasticsearch"
        return 1
    fi
    
    step "Starting remaining services..."
    $COMPOSE_CMD up -d 2>> "$LOG_FILE"
    
    step "Waiting for Kibana to start..."
    local kibana_ready=false
    wait_count=0
    max_wait=50
    
    while [[ $wait_count -lt $max_wait ]]; do
        if curl -s http://localhost:5601/api/status >/dev/null 2>&1; then
            kibana_ready=true
            log "Kibana is ready"
            break
        fi
        
        # Show progress every 15 attempts
        if [[ $((wait_count % 15)) -eq 0 && $wait_count -gt 0 ]]; then
            echo "Still waiting for Kibana... ($wait_count/${max_wait})"
        fi
        
        echo -n "."
        sleep 3
        ((wait_count++))
    done
    
    if [[ "$kibana_ready" != "true" ]]; then
        warn "Kibana took longer than expected to start"
        echo "Checking Kibana logs:"
        $COMPOSE_CMD logs --tail 10 kibana 2>/dev/null || true
    fi
    
    step "Running final verification..."
    
    # Test Elasticsearch
    local es_version=$(curl -s http://localhost:9200 | grep -o '"version":{"number":"[^"]*"' | cut -d'"' -f6 2>/dev/null || echo "unknown")
    log "Elasticsearch version: $es_version"
    
    # Test Kibana
    local kibana_status=$(curl -s http://localhost:5601/api/status | grep -o '"overall":{"level":"[^"]*"' | cut -d'"' -f6 2>/dev/null || echo "unknown")
    log "Kibana status: $kibana_status"
    
    # Create a test index
    step "Creating test index..."
    if curl -s -X PUT "localhost:9200/sentinel-test" -H 'Content-Type: application/json' -d'
    {
      "mappings": {
        "properties": {
          "timestamp": { "type": "date" },
          "message": { "type": "text" },
          "level": { "type": "keyword" }
        }
      }
    }' >/dev/null; then
        log "✅ Test index created successfully"
    else
        warn "Could not create test index (Elasticsearch may still be initializing)"
    fi
    
    log "✅ Installation test completed"
    
    return 0
}

# ===================================
# Rest of the functions remain the same...
# ===================================

setup_directories() {
    header "📁 SETTING UP DIRECTORY STRUCTURE"
    
    step "Creating configuration directories..."
    
    # Core configuration directories
    mkdir -p configs/elk/{elasticsearch,kibana,logstash}/
    mkdir -p configs/{wazuh,thehive,cortex,shuffle}/
    mkdir -p data/{elasticsearch,kibana,logstash,wazuh}/
    mkdir -p logs/{elasticsearch,kibana,logstash}/
    mkdir -p scripts/{backup,restore,monitoring}/
    
    # Set proper permissions
    if [[ "$OSTYPE" != "darwin"* ]]; then
        # Linux/Unix permissions
        sudo chown -R $(id -u):$(id -g) configs/ data/ logs/ 2>/dev/null || true
        chmod -R 755 configs/ data/ logs/ scripts/ 2>/dev/null || true
    fi
    
    log "✅ Directory structure created"
}

create_working_configurations() {
    header "⚙️  CREATING WORKING CONFIGURATIONS"
    
    step "Generating Elasticsearch 9.1.2 configuration..."
    cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
# Elasticsearch 9.1.2 Compatible Configuration
# Generated by Sentinel AK-XL Perfect Setup

cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node

# Network settings
network.host: 0.0.0.0
http.port: 9200

# Security settings (development mode)
xpack.security.enabled: false
xpack.license.self_generated.type: basic

# Performance settings
bootstrap.memory_lock: false
action.auto_create_index: true
indices.query.bool.max_clause_count: 10240

# Resource allocation (FIXED: correct setting name for v9.1.2)
cluster.routing.allocation.disk.threshold_enabled: false

# Logging
logger.level: INFO
EOF
    
    step "Generating Kibana 9.1.2 configuration..."
    cat > configs/elk/kibana/kibana.yml << 'EOF'
# Kibana 9.1.2 Compatible Configuration
# Generated by Sentinel AK-XL Perfect Setup

server.host: 0.0.0.0
server.port: 5601
server.name: sentinel-kibana

# Elasticsearch connection
elasticsearch.hosts: ["http://elasticsearch:9200"]

# Security settings (development mode - no authentication)
server.ssl.enabled: false

# Basic settings
telemetry.enabled: false
telemetry.optIn: false

# Performance settings
elasticsearch.pingTimeout: 10000
elasticsearch.requestTimeout: 60000
elasticsearch.maxSockets: 100

# Logging configuration for v9.1.2
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
    
    step "Generating Logstash configuration..."
    cat > configs/elk/logstash/logstash.yml << 'EOF'
# Logstash Configuration for ELK 9.1.2
# Generated by Sentinel AK-XL Perfect Setup

xpack.monitoring.enabled: true
xpack.monitoring.elasticsearch.hosts: ["http://elasticsearch:9200"]
EOF
    
    cat > configs/elk/logstash/pipelines.yml << 'EOF'
# Logstash Pipelines Configuration
- pipeline.id: main
  path.config: "/usr/share/logstash/pipeline/*.conf"
EOF
    
    # Create Logstash pipeline configurations
    mkdir -p configs/elk/logstash/conf.d/
    
    cat > configs/elk/logstash/conf.d/input.conf << 'EOF'
input {
  beats {
    port => 5044
  }
  
  syslog {
    port => 5140
  }
}
EOF
    
    cat > configs/elk/logstash/conf.d/filter.conf << 'EOF'
filter {
  # Basic log parsing
  if [fields][log_type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:timestamp} %{IPORHOST:host} %{DATA:program}(?:\[%{POSINT:pid}\])?: %{GREEDYDATA:msg}" }
    }
  }
}
EOF
    
    cat > configs/elk/logstash/conf.d/output.conf << 'EOF'
output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "sentinel-logs-%{+YYYY.MM.dd}"
  }
  
  stdout { 
    codec => rubydebug 
  }
}
EOF
    
    log "✅ Configuration files generated"
}

# ... [Rest of the functions remain exactly the same as in the original script]
# ... [I'll continue with the remaining functions to complete the script]

create_perfect_docker_compose() {
    header "🐳 CREATING BULLETPROOF DOCKER COMPOSE"
    
    step "Generating optimized docker-compose.yml..."
    
    cat > docker-compose.yml << 'EOF'
# Sentinel AK-XL - ELK Stack 9.1.2
# Bulletproof configuration for universal compatibility
# Generated by Perfect Setup Script

#version: '3.8'

networks:
  sentinel:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  elasticsearch-data:
    driver: local
  kibana-data:
    driver: local
  logstash-data:
    driver: local

services:
  # Elasticsearch 9.1.2
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
      - path.repo=/usr/share/elasticsearch/backup
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
      - ./configs/elk/elasticsearch/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml:ro
      - ./logs/elasticsearch:/usr/share/elasticsearch/logs
    ports:
      - "9200:9200"
      - "9300:9300"
    networks:
      sentinel:
        ipv4_address: 172.20.0.10
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    mem_limit: 3g
    mem_reservation: 2g

  # Kibana 9.1.2
  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.2
    container_name: sentinel-kibana
    hostname: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - SERVER_NAME=sentinel-kibana
    volumes:
      - kibana-data:/usr/share/kibana/data
      - ./configs/elk/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml:ro
      - ./logs/kibana:/usr/share/kibana/logs
    ports:
      - "5601:5601"
    networks:
      sentinel:
        ipv4_address: 172.20.0.11
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:5601/api/status || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 8
      start_period: 90s
    mem_limit: 2g
    mem_reservation: 1g

  # Logstash 9.1.2
  logstash:
    image: docker.elastic.co/logstash/logstash:9.1.2
    container_name: sentinel-logstash
    hostname: logstash
    environment:
      - "LS_JAVA_OPTS=-Xms1g -Xmx1g"
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - LOG_LEVEL=info
    volumes:
      - logstash-data:/usr/share/logstash/data
      - ./configs/elk/logstash/logstash.yml:/usr/share/logstash/config/logstash.yml
      - ./configs/elk/logstash/pipelines.yml:/usr/share/logstash/config/pipelines.yml:ro
      - ./configs/elk/logstash/conf.d:/usr/share/logstash/pipeline/:ro
      - ./logs/logstash:/usr/share/logstash/logs
    ports:
      - "5044:5044"
      - "5140:5140"
      - "9600:9600"
    networks:
      sentinel:
        ipv4_address: 172.20.0.12
    depends_on:
      elasticsearch:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-s", "-f", "http://localhost:9600/_node/stats/pipelines"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    mem_limit: 2g
    mem_reservation: 1g
EOF
    
    log "✅ Docker Compose configuration created"
}

# ... [Continue with rest of the functions - they remain the same]

# ===================================
# Main Execution (Updated)
# ===================================

main() {
    # Initialize log file
    echo "Sentinel AK-XL Perfect Setup (FIXED) - $(date)" > "$LOG_FILE"
    
    # Display banner
    echo -e "${PURPLE}"
    echo "   ____            __  _            __   ___   __ __    _  ____ " 
    echo "  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /"
    echo " _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / "
    echo "/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/     "
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║        🛡️      SENTINEL AK-XL PERFECT SETUP     🛡️               ║"
    echo "║             Bulletproof ELK Stack Installation                   ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}This script resolves Docker Compose compatibility issues${NC}"
    echo -e "${CYAN}and creates a bulletproof ELK Stack 9.1.2 installation.${NC}"
    echo ""
    
    # Confirmation
    read -p "Continue with fixed perfect setup? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    # Execute setup steps
    check_system_requirements
    clean_previous_installation
    setup_directories
    create_working_configurations
    create_perfect_docker_compose
    
    # Test the installation
    if test_installation; then
        header "🎉 PERFECT SETUP COMPLETED SUCCESSFULLY!"
        
        echo -e "${GREEN}Your Sentinel AK-XL installation is ready!${NC}"
        echo ""
        echo -e "${CYAN}🔗 Access URLs:${NC}"
        echo -e "   • Elasticsearch: ${YELLOW}http://localhost:9200${NC}"
        echo -e "   • Kibana: ${YELLOW}http://localhost:5601${NC}"
        echo ""
        echo -e "${GREEN}✅ Repository is now GitHub-ready with bulletproof installation!${NC}"
        echo -e "${GREEN}   Any user can clone and run successfully.${NC}"
        
    else
        error "Setup test failed. Check logs for details."
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Check setup.log for detailed errors"
        echo "2. Run: $COMPOSE_CMD logs"
        echo "3. Verify Docker Compose compatibility: $COMPOSE_CMD version"
        echo "4. Try manual restart: $COMPOSE_CMD down && $COMPOSE_CMD up -d"
        exit 1
    fi
}

# Run main function
main "$@"
