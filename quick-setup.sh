#!/bin/bash

# ===================================
# Sentinel AK-XL: Quick Setup
# ===================================
# One-command setup for users who just want it to work
# ===================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ===================================
# Quick Setup Function
# ===================================

quick_setup() {
    echo -e "${BLUE}🚀 Sentinel AK-XL Quick Setup${NC}"
    echo "=================================="
    echo ""
    
    # Check if perfect setup script exists
    if [[ -f "create-perfect-setup.sh" ]]; then
        echo -e "${GREEN}Running perfect setup script...${NC}"
        ./create-perfect-setup.sh
    else
        echo -e "${YELLOW}Perfect setup script not found. Running basic setup...${NC}"
        
        # Basic setup if perfect script missing
        basic_setup
    fi
}

basic_setup() {
    echo -e "${BLUE}📦 Basic ELK Stack Setup${NC}"
    echo ""
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
        exit 1
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        echo -e "${RED}❌ Docker Compose not found.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker and Docker Compose found${NC}"
    
    # Create basic directories
    echo "Creating directories..."
    mkdir -p {configs/elk/{elasticsearch,kibana,logstash},data,logs}
    
    # Check if configurations exist
    if [[ ! -f "configs/elk/elasticsearch/elasticsearch.yml" ]]; then
        echo "Creating basic Elasticsearch config..."
        cat > configs/elk/elasticsearch/elasticsearch.yml << 'EOF'
cluster.name: sentinel-cluster
node.name: elasticsearch
discovery.type: single-node
network.host: 0.0.0.0
http.port: 9200
xpack.security.enabled: false
bootstrap.memory_lock: false
cluster.routing.allocation.disk.threshold_enabled: false
EOF
    fi
    
    if [[ ! -f "configs/elk/kibana/kibana.yml" ]]; then
        echo "Creating basic Kibana config..."
        cat > configs/elk/kibana/kibana.yml << 'EOF'
server.host: 0.0.0.0
server.port: 5601
elasticsearch.hosts: ["http://elasticsearch:9200"]
telemetry.enabled: false
EOF
    fi
    
    # Start services
    echo -e "${BLUE}Starting services...${NC}"
    $COMPOSE_CMD up -d
    
    echo ""
    echo -e "${GREEN}🎉 Basic setup complete!${NC}"
    echo -e "${YELLOW}Access Kibana at: http://localhost:5601${NC}"
    echo -e "${YELLOW}Access Elasticsearch at: http://localhost:9200${NC}"
}

# ===================================
# Help Function
# ===================================

show_help() {
    echo "Sentinel AK-XL Quick Setup"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --force, -f    Force setup without prompts"
    echo "  --basic, -b    Run basic setup only"
    echo ""
    echo "Examples:"
    echo "  $0              # Interactive setup"
    echo "  $0 --force      # Automated setup"
    echo "  $0 --basic      # Basic ELK setup only"
}

# ===================================
# Main Script Logic
# ===================================

# Parse command line arguments
FORCE_MODE=false
BASIC_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --force|-f)
            FORCE_MODE=true
            shift
            ;;
        --basic|-b)
            BASIC_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
if [[ "$BASIC_MODE" == "true" ]]; then
    basic_setup
elif [[ "$FORCE_MODE" == "true" ]]; then
    quick_setup
else
    echo -e "${BLUE}Welcome to Sentinel AK-XL Quick Setup!${NC}"
    echo ""
    echo "This will set up your ELK Stack 9.1.2 environment."
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        quick_setup
    else
        echo "Setup cancelled."
        exit 0
    fi
fi
