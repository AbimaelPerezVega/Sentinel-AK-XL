#!/bin/bash

# ===================================
# Sentinel AK-XL Virtual SOC Cleanup Script
# ===================================
# This script cleans up the Virtual SOC environment
# Use this to reset training scenarios or troubleshoot issues
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
BACKUP_DIR="$SCRIPT_DIR/backups"

# ===================================
# Utility Functions
# ===================================

print_banner() {
    echo -e "${RED}"
    cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
              🧹 CLEANUP & RESET UTILITY 🧹
                  Virtual SOC Environment
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
# Cleanup Options
# ===================================

show_menu() {
    echo -e "\n${CYAN}Select cleanup operation:${NC}"
    echo -e "  ${YELLOW}1)${NC} Stop all services"
    echo -e "  ${YELLOW}2)${NC} Stop services + Remove containers"
    echo -e "  ${YELLOW}3)${NC} Full cleanup (containers + volumes + networks)"
    echo -e "  ${YELLOW}4)${NC} Reset training data only"
    echo -e "  ${YELLOW}5)${NC} Clean Docker cache and images"
    echo -e "  ${YELLOW}6)${NC} Factory reset (everything except configurations)"
    echo -e "  ${YELLOW}7)${NC} Nuclear option (complete wipe including configs)"
    echo -e "  ${YELLOW}8)${NC} Backup current state before cleanup"
    echo -e "  ${YELLOW}q)${NC} Quit"
    echo ""
}

# ===================================
# Docker Compose Detection
# ===================================

detect_compose() {
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        error "Docker Compose not found"
        exit 1
    fi
    export COMPOSE_CMD
}

# ===================================
# Service Management
# ===================================

stop_services() {
    step "Stopping Sentinel AK-XL services..."
    
    if [[ -f docker-compose.yml ]]; then
        $COMPOSE_CMD stop
        success "All services stopped ✓"
    else
        warn "docker-compose.yml not found, stopping containers by label..."
        docker stop $(docker ps -q --filter "label=com.docker.compose.project=$PROJECT_NAME" 2>/dev/null) 2>/dev/null || true
    fi
}

remove_containers() {
    step "Removing containers..."
    
    if [[ -f docker-compose.yml ]]; then
        $COMPOSE_CMD down
        success "Containers removed ✓"
    else
        warn "docker-compose.yml not found, removing containers by label..."
        docker rm -f $(docker ps -aq --filter "label=com.docker.compose.project=$PROJECT_NAME" 2>/dev/null) 2>/dev/null || true
    fi
}

remove_volumes() {
    step "Removing Docker volumes..."
    
    if [[ -f docker-compose.yml ]]; then
        $COMPOSE_CMD down -v
    fi
    
    # Remove named volumes
    VOLUMES=$(docker volume ls -q --filter "name=${PROJECT_NAME}" 2>/dev/null || true)
    if [[ -n "$VOLUMES" ]]; then
        echo "$VOLUMES" | xargs docker volume rm 2>/dev/null || true
        log "Named volumes removed"
    fi
    
    success "Volumes removed ✓"
}

remove_networks() {
    step "Removing custom networks..."
    
    # Remove project networks
    NETWORKS=$(docker network ls -q --filter "name=${PROJECT_NAME}" 2>/dev/null || true)
    if [[ -n "$NETWORKS" ]]; then
        echo "$NETWORKS" | xargs docker network rm 2>/dev/null || true
        log "Custom networks removed"
    fi
    
    success "Networks cleaned ✓"
}

# ===================================
# Data Management
# ===================================

clean_data_directories() {
    step "Cleaning data directories..."
    
    if [[ -d data ]]; then
        # Create backup timestamp
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        
        # Backup important data before cleaning
        if [[ "$1" != "--no-backup" ]]; then
            create_data_backup "$TIMESTAMP"
        fi
        
        # Clean specific data directories
        local dirs_to_clean=(
            "data/elasticsearch/data"
            "data/elasticsearch/logs"
            "data/kibana/data"
            "data/logstash/data"
            "data/wazuh/logs"
            "data/wazuh/queue"
            "data/thehive/files"
            "data/cortex/jobs"
            "data/shuffle/workflows"
            "data/logs"
        )
        
        for dir in "${dirs_to_clean[@]}"; do
            if [[ -d "$dir" ]]; then
                rm -rf "$dir"
                mkdir -p "$dir"
                log "Cleaned $dir"
            fi
        done
        
        # Reset permissions
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo chown -R 1000:1000 data/elasticsearch 2>/dev/null || true
            chmod -R 755 data/ 2>/dev/null || true
        fi
        
        success "Data directories cleaned ✓"
    else
        warn "Data directory not found"
    fi
}

reset_training_data() {
    step "Resetting training data only..."
    
    # Remove scenario logs and generated data
    local training_dirs=(
        "data/logs/scenarios"
        "scenarios/*/output"
        "scenarios/*/generated"
        "agents/*/logs"
        "agents/network-simulator/pcaps"
    )
    
    for pattern in "${training_dirs[@]}"; do
        find . -path "./$pattern" -type d -exec rm -rf {} + 2>/dev/null || true
    done
    
    # Recreate directories
    mkdir -p data/logs/scenarios
    mkdir -p agents/{linux-agent,windows-agent,network-simulator}/logs
    mkdir -p agents/network-simulator/pcaps
    
    success "Training data reset ✓"
}

# ===================================
# Docker Image Management
# ===================================

clean_docker_cache() {
    step "Cleaning Docker cache and unused images..."
    
    # Remove unused images
    docker image prune -f
    
    # Remove build cache
    docker builder prune -f
    
    # Show space reclaimed
    log "Docker cache cleaned"
    
    success "Docker cache cleanup completed ✓"
}

remove_project_images() {
    step "Removing Sentinel AK-XL Docker images..."
    
    # List of project images
    local images=(
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
    )
    
    # Also remove locally built images
    local built_images=$(docker images --filter "label=project=sentinel-ak-xl" -q 2>/dev/null || true)
    
    for image in "${images[@]}"; do
        if docker image inspect "$image" &>/dev/null; then
            docker rmi "$image" 2>/dev/null || warn "Could not remove $image (may be in use)"
        fi
    done
    
    if [[ -n "$built_images" ]]; then
        echo "$built_images" | xargs docker rmi -f 2>/dev/null || true
    fi
    
    success "Project images removed ✓"
}

# ===================================
# Configuration Management
# ===================================

reset_configurations() {
    step "Resetting configurations to defaults..."
    
    # Backup current configs
    if [[ -d configs ]]; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        mkdir -p "$BACKUP_DIR"
        tar -czf "$BACKUP_DIR/configs_backup_$TIMESTAMP.tar.gz" configs/ 2>/dev/null || true
        log "Configurations backed up to $BACKUP_DIR/configs_backup_$TIMESTAMP.tar.gz"
    fi
    
    # Remove dynamic configs (keep templates)
    find configs/ -name "*.generated" -delete 2>/dev/null || true
    find configs/ -name "*.auto" -delete 2>/dev/null || true
    
    # Reset .env to example
    if [[ -f .env.example ]] && [[ -f .env ]]; then
        cp .env .env.backup."$(date +%Y%m%d_%H%M%S)"
        cp .env.example .env
        log "Environment file reset to defaults"
    fi
    
    success "Configurations reset ✓"
}

# ===================================
# Backup Functions
# ===================================

create_data_backup() {
    local timestamp=${1:-$(date +%Y%m%d_%H%M%S)}
    
    step "Creating data backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup critical data
    if [[ -d data ]]; then
        tar -czf "$BACKUP_DIR/data_backup_$timestamp.tar.gz" \
            --exclude="data/elasticsearch/data" \
            --exclude="data/*/logs" \
            data/ 2>/dev/null || true
        log "Data backup created: $BACKUP_DIR/data_backup_$timestamp.tar.gz"
    fi
    
    # Backup configurations
    if [[ -d configs ]]; then
        tar -czf "$BACKUP_DIR/configs_backup_$timestamp.tar.gz" configs/ 2>/dev/null || true
        log "Config backup created: $BACKUP_DIR/configs_backup_$timestamp.tar.gz"
    fi
    
    # Backup environment
    if [[ -f .env ]]; then
        cp .env "$BACKUP_DIR/env_backup_$timestamp"
        log "Environment backup created: $BACKUP_DIR/env_backup_$timestamp"
    fi
    
    success "Backup completed ✓"
}

# ===================================
# System Information
# ===================================

show_system_info() {
    step "Current system status..."
    
    echo -e "\n${CYAN}🐳 Docker Status:${NC}"
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(sentinel|elastic|kibana|wazuh|thehive|cortex|shuffle)" || echo "No Sentinel containers running"
    
    echo -e "\n${CYAN}💾 Docker Volumes:${NC}"
    docker volume ls | grep -E "(sentinel|elastic|wazuh|thehive)" || echo "No project volumes found"
    
    echo -e "\n${CYAN}🌐 Docker Networks:${NC}"
    docker network ls | grep -E "(sentinel)" || echo "No project networks found"
    
    echo -e "\n${CYAN}💽 Disk Usage:${NC}"
    if [[ -d data ]]; then
        du -sh data/ 2>/dev/null || echo "Cannot calculate data directory size"
    fi
    
    echo -e "\n${CYAN}🗄️ Available Backups:${NC}"
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -lh "$BACKUP_DIR"/ 2>/dev/null || echo "No backups found"
    else
        echo "No backup directory found"
    fi
}

# ===================================
# Cleanup Operations
# ===================================

cleanup_stop_only() {
    log "Performing: Stop services only"
    stop_services
}

cleanup_containers() {
    log "Performing: Stop services + Remove containers"
    remove_containers
}

cleanup_full() {
    log "Performing: Full cleanup (containers + volumes + networks)"
    remove_containers
    remove_volumes
    remove_networks
}

cleanup_training_only() {
    log "Performing: Reset training data only"
    stop_services
    reset_training_data
}

cleanup_docker_cache() {
    log "Performing: Clean Docker cache and images"
    clean_docker_cache
}

cleanup_factory_reset() {
    log "Performing: Factory reset (everything except configurations)"
    
    warn "This will remove all containers, volumes, networks, and data!"
    read -p "Are you sure? Type 'YES' to continue: " -r
    if [[ $REPLY != "YES" ]]; then
        log "Cancelled by user"
        return
    fi
    
    create_data_backup
    remove_containers
    remove_volumes
    remove_networks
    clean_data_directories --no-backup
    clean_docker_cache
}

cleanup_nuclear() {
    log "Performing: Nuclear option (complete wipe)"
    
    error "⚠️  DANGER: This will remove EVERYTHING including configurations!"
    warn "This action cannot be undone without backups!"
    read -p "Type 'NUCLEAR' to confirm total destruction: " -r
    if [[ $REPLY != "NUCLEAR" ]]; then
        log "Cancelled by user"
        return
    fi
    
    create_data_backup
    remove_containers
    remove_volumes
    remove_networks
    clean_data_directories --no-backup
    reset_configurations
    remove_project_images
    clean_docker_cache
    
    error "🔥 Nuclear cleanup completed. System reset to initial state."
}

# ===================================
# Interactive Mode
# ===================================

interactive_mode() {
    while true; do
        show_system_info
        show_menu
        read -p "Enter your choice: " choice
        
        case $choice in
            1) cleanup_stop_only ;;
            2) cleanup_containers ;;
            3) cleanup_full ;;
            4) cleanup_training_only ;;
            5) cleanup_docker_cache ;;
            6) cleanup_factory_reset ;;
            7) cleanup_nuclear ;;
            8) create_data_backup ;;
            q|Q) 
                log "Exiting cleanup utility"
                exit 0
                ;;
            *)
                warn "Invalid option. Please try again."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
        clear
    done
}

# ===================================
# Main Function
# ===================================

main() {
    print_banner
    
    detect_compose
    
    # Handle command line arguments
    case "${1:-}" in
        --help|-h)
            echo "Sentinel AK-XL Cleanup Script"
            echo ""
            echo "Usage: $0 [operation]"
            echo ""
            echo "Operations:"
            echo "  stop              Stop all services"
            echo "  containers        Stop and remove containers"
            echo "  full              Full cleanup (containers + volumes + networks)"
            echo "  training          Reset training data only"
            echo "  cache             Clean Docker cache"
            echo "  factory           Factory reset (keep configs)"
            echo "  nuclear           Complete wipe (including configs)"
            echo "  backup            Create backup of current state"
            echo "  interactive       Interactive mode (default)"
            echo ""
            echo "Options:"
            echo "  --help, -h        Show this help"
            echo "  --force           Skip confirmations"
            echo ""
            exit 0
            ;;
        stop)
            cleanup_stop_only
            ;;
        containers)
            cleanup_containers
            ;;
        full)
            cleanup_full
            ;;
        training)
            cleanup_training_only
            ;;
        cache)
            cleanup_docker_cache
            ;;
        factory)
            cleanup_factory_reset
            ;;
        nuclear)
            cleanup_nuclear
            ;;
        backup)
            create_data_backup
            ;;
        interactive|"")
            interactive_mode
            ;;
        *)
            error "Unknown operation: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
    
    success "Cleanup operation completed! 🧹"
}

# ===================================
# Script Entry Point
# ===================================

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root."
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f docker-compose.yml ]] && [[ ! -f README.md ]]; then
    warn "This doesn't appear to be the Sentinel AK-XL directory"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run main function
main "$@"
