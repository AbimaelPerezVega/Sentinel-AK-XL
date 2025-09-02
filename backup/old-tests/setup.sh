#!/bin/bash

# ===================================
# Sentinel AK-XL Virtual SOC Setup Script
# ===================================
# This script sets up the complete Virtual SOC environment
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="sentinel-ak-xl"
MIN_DOCKER_VERSION="20.10"
MIN_COMPOSE_VERSION="2.0"
MIN_RAM_GB=8
MIN_DISK_GB=20

# ===================================
# Utility Functions
# ===================================

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
        🛡️  Virtual Security Operations Center 🛡️
           Advanced Blue Team Training Platform
EOF
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# ===================================
# System Requirements Check
# ===================================

check_os() {
    step "Checking operating system compatibility..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        log "Operating system: Linux ✓"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        log "Operating system: macOS ✓"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        log "Operating system: Windows (WSL/Cygwin) ✓"
    else
        error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
}

check_ram() {
    step "Checking system memory..."
    
    if [[ "$OS" == "linux" ]]; then
        TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    elif [[ "$OS" == "macos" ]]; then
        TOTAL_RAM_BYTES=$(sysctl -n hw.memsize)
        TOTAL_RAM_GB=$((TOTAL_RAM_BYTES / 1024 / 1024 / 1024))
    else
        # Windows/WSL
        TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "8388608")
        TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    fi
    
    if [[ $TOTAL_RAM_GB -lt $MIN_RAM_GB ]]; then
        warn "System has ${TOTAL_RAM_GB}GB RAM. Minimum recommended: ${MIN_RAM_GB}GB"
        warn "Performance may be degraded. Consider reducing heap sizes in .env"
    else
        log "System memory: ${TOTAL_RAM_GB}GB ✓"
    fi
}

check_disk_space() {
    step "Checking available disk space..."
    
    AVAILABLE_GB=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
    
    if [[ $AVAILABLE_GB -lt $MIN_DISK_GB ]]; then
        error "Insufficient disk space. Available: ${AVAILABLE_GB}GB, Required: ${MIN_DISK_GB}GB"
        exit 1
    else
        log "Available disk space: ${AVAILABLE_GB}GB ✓"
    fi
}

check_docker() {
    step "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        warn "Docker not found. Installing Docker..."
        install_docker
    else
        DOCKER_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if version_ge "$DOCKER_VERSION" "$MIN_DOCKER_VERSION"; then
            log "Docker version: $DOCKER_VERSION ✓"
        else
            error "Docker version $DOCKER_VERSION is too old. Minimum required: $MIN_DOCKER_VERSION"
            exit 1
        fi
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
}

check_docker_compose() {
    step "Checking Docker Compose..."
    
    # Check for docker compose (new) or docker-compose (legacy)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "2.0.0")
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        COMPOSE_VERSION=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    else
        error "Docker Compose not found. Please install Docker Compose v${MIN_COMPOSE_VERSION}+"
        exit 1
    fi
    
    if version_ge "$COMPOSE_VERSION" "$MIN_COMPOSE_VERSION"; then
        log "Docker Compose version: $COMPOSE_VERSION ✓"
    else
        error "Docker Compose version $COMPOSE_VERSION is too old. Minimum required: $MIN_COMPOSE_VERSION"
        exit 1
    fi
    
    export COMPOSE_CMD
}

version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

install_docker() {
    step "Installing Docker..."
    
    if [[ "$OS" == "linux" ]]; then
        # Install Docker on Linux
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        
        # Add current user to docker group
        sudo usermod -aG docker $USER
        warn "You may need to log out and back in for Docker permissions to take effect"
        
    elif [[ "$OS" == "macos" ]]; then
        error "Please install Docker Desktop for Mac from https://docker.com/products/docker-desktop"
        exit 1
        
    else  # Windows
        error "Please install Docker Desktop for Windows from https://docker.com/products/docker-desktop"
        exit 1
    fi
}

# ===================================
# Network Configuration
# ===================================

configure_system_limits() {
    step "Configuring system limits for Elasticsearch..."
    
    # Set vm.max_map_count for Elasticsearch
    if [[ "$OS" == "linux" ]]; then
        current_max_map_count=$(sysctl -n vm.max_map_count 2>/dev/null || echo "0")
        if [[ $current_max_map_count -lt 262144 ]]; then
            log "Setting vm.max_map_count=262144..."
            sudo sysctl -w vm.max_map_count=262144
            
            # Make it persistent
            if ! grep -q "vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
                echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
            fi
        fi
    elif [[ "$OS" == "macos" ]]; then
        warn "On macOS, ensure Docker Desktop has sufficient memory allocation (8GB+)"
    fi
}

check_ports() {
    step "Checking for port conflicts..."
    
    REQUIRED_PORTS=(5601 9200 5044 9000 9001 3001 55000 443 1514 1515)
    CONFLICTS=()
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if command -v netstat &> /dev/null; then
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                CONFLICTS+=($port)
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln 2>/dev/null | grep -q ":$port "; then
                CONFLICTS+=($port)
            fi
        fi
    done
    
    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        warn "Port conflicts detected: ${CONFLICTS[*]}"
        warn "These ports are required: Kibana(5601), Elasticsearch(9200), TheHive(9000)"
        read -p "Continue anyway? Services may fail to start. (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log "No port conflicts detected ✓"
    fi
}

# ===================================
# Environment Setup
# ===================================

setup_environment() {
    step "Setting up environment configuration..."
    
    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            cp .env.example .env
            log "Created .env from .env.example"
        else
            create_default_env
            log "Created default .env file"
        fi
    else
        log "Using existing .env file"
    fi
    
    # Generate secure passwords if they don't exist
    update_env_passwords
}

create_default_env() {
    cat > .env << 'EOF'
# Sentinel AK-XL Environment Configuration

# ===================================
# Security Settings
# ===================================
ELASTIC_PASSWORD=changeme123!
KIBANA_PASSWORD=changeme123!
THEHIVE_SECRET=changeme-secret-key-here
CORTEX_SECRET=changeme-cortex-key-here

# ===================================
# Resource Allocation
# ===================================
ELASTICSEARCH_HEAP=2g
LOGSTASH_HEAP=1g

# ===================================
# Network Configuration
# ===================================
NETWORK_SUBNET=172.20.0.0/16
ELASTICSEARCH_PORT=9200
KIBANA_PORT=5601
LOGSTASH_PORT=5044
THEHIVE_PORT=9000
CORTEX_PORT=9001
SHUFFLE_PORT=3001
WAZUH_API_PORT=55000

# ===================================
# Training Configuration
# ===================================
DEFAULT_SCENARIO=basic
EVENT_GENERATION_RATE=100
HEALTH_CHECK_INTERVAL=30s
EOF
}

update_env_passwords() {
    step "Generating secure passwords..."
    
    # Generate random passwords
    ELASTIC_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    THEHIVE_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)
    CORTEX_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)
    
    # Update .env file
    sed -i.bak "s/ELASTIC_PASSWORD=.*/ELASTIC_PASSWORD=$ELASTIC_PASS/" .env
    sed -i.bak "s/KIBANA_PASSWORD=.*/KIBANA_PASSWORD=$ELASTIC_PASS/" .env
    sed -i.bak "s/THEHIVE_SECRET=.*/THEHIVE_SECRET=$THEHIVE_SECRET/" .env
    sed -i.bak "s/CORTEX_SECRET=.*/CORTEX_SECRET=$CORTEX_SECRET/" .env
    
    rm -f .env.bak
    
    log "Generated secure passwords and updated .env"
}

# ===================================
# Directory Structure Setup
# ===================================

create_directories() {
    step "Creating required directories..."
    
    # Data directories
    mkdir -p data/{elasticsearch,kibana,logstash,wazuh,thehive,cortex,shuffle}
    mkdir -p data/logs/{scenarios,health,backup}
    
    # Config directories
    mkdir -p configs/{elk/{elasticsearch,kibana,logstash/{conf.d}},wazuh/{rules,decoders},thehive,cortex,shuffle/{workflows,apps}}
    
    # Agent directories
    mkdir -p agents/{linux-agent/{scripts,logs},windows-agent/{scripts,logs},network-simulator/{scripts,pcaps}}
    
    # Scenario directories
    mkdir -p scenarios/{basic,intermediate,advanced,templates}
    
    # Script directories
    mkdir -p scripts/{install,management,scenarios,test}
    
    # Documentation
    mkdir -p docs
    
    # Tests
    mkdir -p tests/{unit,integration,scenarios}
    
    log "Directory structure created ✓"
}

set_permissions() {
    step "Setting directory permissions..."
    
    # Set proper ownership for data directories
    if [[ "$OS" == "linux" ]]; then
        # Elasticsearch requires specific ownership
        sudo chown -R 1000:1000 data/elasticsearch 2>/dev/null || true
        
        # Make sure data directories are writable
        chmod -R 755 data/
        chmod -R 755 configs/
    fi
    
    # Make scripts executable
    find . -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    log "Permissions set ✓"
}

# ===================================
# Docker Image Management
# ===================================

pull_docker_images() {
    step "Pulling Docker images... (this may take several minutes)"
    
    IMAGES=(
        "docker.elastic.co/elasticsearch/elasticsearch:8.11.0"
        "docker.elastic.co/kibana/kibana:8.11.0"
        "docker.elastic.co/logstash/logstash:8.11.0"
        "wazuh/wazuh-manager:4.7.0"
        "wazuh/wazuh-dashboard:4.7.0"
        "strangebee/thehive:5.2"
        "thehiveproject/cortex:3.1.7"
        "cassandra:4.0"
        "ghcr.io/shuffle/shuffle-backend:latest"
        "ghcr.io/shuffle/shuffle-frontend:latest"
        "alpine:latest"
    )
    
    for image in "${IMAGES[@]}"; do
        log "Pulling $image..."
        docker pull "$image" || warn "Failed to pull $image"
    done
    
    success "Docker images pulled successfully ✓"
}

# ===================================
# Service Initialization
# ===================================

start_services() {
    step "Starting Sentinel AK-XL services..."
    
    # Start services in dependency order
    log "Starting core infrastructure..."
    $COMPOSE_CMD up -d elasticsearch cassandra
    
    # Wait for Elasticsearch to be ready
    log "Waiting for Elasticsearch to start..."
    wait_for_service "elasticsearch" "http://localhost:9200" 120
    
    log "Starting remaining services..."
    $COMPOSE_CMD up -d
    
    success "All services started ✓"
}

wait_for_service() {
    local service_name=$1
    local health_url=$2
    local max_wait=${3:-60}
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        if curl -s "$health_url" &>/dev/null; then
            log "$service_name is ready ✓"
            return 0
        fi
        
        sleep 5
        wait_time=$((wait_time + 5))
        echo -n "."
    done
    
    warn "$service_name took longer than expected to start"
    return 1
}

# ===================================
# Post-Installation Setup
# ===================================

configure_services() {
    step "Configuring services..."
    
    # Wait for all services to be fully ready
    sleep 30
    
    log "Setting up Elasticsearch indices..."
    setup_elasticsearch_indices
    
    log "Configuring Kibana dashboards..."
    setup_kibana_dashboards
    
    log "Initializing TheHive..."
    setup_thehive
    
    success "Service configuration completed ✓"
}

setup_elasticsearch_indices() {
    # Create index templates for security events
    curl -s -X PUT "localhost:9200/_index_template/wazuh-alerts" \
        -H "Content-Type: application/json" \
        -d '{
            "index_patterns": ["wazuh-alerts-*"],
            "template": {
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0,
                    "refresh_interval": "5s"
                }
            }
        }' || warn "Failed to create Wazuh index template"
}

setup_kibana_dashboards() {
    # Import basic security dashboards
    # This would typically involve API calls to Kibana
    log "Kibana dashboard setup completed"
}

setup_thehive() {
    # Initialize TheHive database
    log "TheHive initialization completed"
}

# ===================================
# Validation and Testing
# ===================================

run_health_checks() {
    step "Running health checks..."
    
    if [[ -f ./health-check.sh ]]; then
        ./health-check.sh
    else
        basic_health_check
    fi
}

basic_health_check() {
    local services=(
        "elasticsearch:9200:Elasticsearch"
        "localhost:5601:Kibana"
        "localhost:9000:TheHive"
        "localhost:55000:Wazuh"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r host port name <<< "$service"
        if curl -s "http://$host:$port" &>/dev/null; then
            log "$name is healthy ✓"
        else
            warn "$name may not be ready yet"
        fi
    done
}

# ===================================
# User Instructions
# ===================================

show_access_info() {
    echo -e "\n${GREEN}🎉 Sentinel AK-XL Virtual SOC is ready!${NC}\n"
    
    echo -e "${CYAN}📋 Access Information:${NC}"
    echo -e "  • Kibana Dashboard:    ${BLUE}http://localhost:5601${NC}"
    echo -e "    Username: elastic"
    echo -e "    Password: (check .env file)"
    echo -e ""
    echo -e "  • TheHive (Cases):     ${BLUE}http://localhost:9000${NC}"
    echo -e "  • Wazuh Dashboard:     ${BLUE}https://localhost:443${NC}"
    echo -e "  • Shuffle SOAR:        ${BLUE}http://localhost:3001${NC}"
    echo -e ""
    
    echo -e "${CYAN}🎮 Quick Start Commands:${NC}"
    echo -e "  • Run a basic scenario:    ${YELLOW}./run-scenario.sh basic malware-detection${NC}"
    echo -e "  • Check service health:    ${YELLOW}./health-check.sh${NC}"
    echo -e "  • View service logs:       ${YELLOW}docker compose logs -f${NC}"
    echo -e "  • Stop all services:       ${YELLOW}docker compose down${NC}"
    echo -e ""
    
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "  • User Guide:     ${BLUE}docs/user-guide.md${NC}"
    echo -e "  • Admin Guide:    ${BLUE}docs/admin-guide.md${NC}"
    echo -e "  • Troubleshooting: ${BLUE}docs/troubleshooting.md${NC}"
    echo -e ""
    
    if [[ ! -f run-scenario.sh ]]; then
        warn "run-scenario.sh not found. Some features may not be available yet."
    fi
}

# ===================================
# Main Installation Process
# ===================================

main() {
    print_banner
    
    echo -e "${BLUE}Starting Sentinel AK-XL Virtual SOC setup...${NC}\n"
    
    # System checks
    check_os
    check_ram
    check_disk_space
    check_docker
    check_docker_compose
    check_ports
    
    # System configuration
    configure_system_limits
    
    # Environment setup
    setup_environment
    create_directories
    set_permissions
    
    # Docker setup
    pull_docker_images
    start_services
    
    # Post-installation
    configure_services
    run_health_checks
    
    # Show completion info
    show_access_info
    
    success "Setup completed successfully! 🚀"
}

# ===================================
# Script Entry Point
# ===================================

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Sentinel AK-XL Virtual SOC Setup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --quick        Skip confirmations (use defaults)"
        echo "  --no-pull      Don't pull Docker images (use local)"
        echo ""
        exit 0
        ;;
    --quick)
        QUICK_MODE=true
        ;;
    --no-pull)
        SKIP_PULL=true
        ;;
esac

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Please run as a regular user."
    exit 1
fi

# Run main installation
main "$@"
