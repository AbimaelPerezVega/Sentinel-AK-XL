#!/usr/bin/env bash
# ==============================================================================
# Sentinel AK-XL - Automated Setup Script
# 
# This script checks for all required software dependencies, validates versions,
# and provides automated installation/update options for the Virtual SOC platform.
#
# Usage:
#   ./automated_setup.sh
#
# Requirements checked:
# - OS: Ubuntu 20.04+ or WSL2
# - Docker Engine: 20.10+
# - Docker Compose: 2.0+
# - System utilities: curl, jq, awk, git
# - Memory: 10GB+ RAM
# - Storage: 50GB+ free space
# ==============================================================================
set -euo pipefail

# --- Colors & logging ---
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $(date '+%F %T') - $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}  $(date '+%F %T') - $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%F %T') - $*"; }
err()  { echo -e "${RED}[ERR]${NC}  $(date '+%F %T') - $*" >&2; }
bold() { echo -e "${BOLD}$*${NC}"; }

# --- Configuration ---
REQUIRED_DOCKER_VERSION="20.10"
REQUIRED_COMPOSE_VERSION="2.0"
REQUIRED_RAM_GB=10
REQUIRED_DISK_GB=50
REQUIRED_UBUNTU_VERSION="20.04"

# --- Global status tracking ---
ISSUES_FOUND=0
INSTALL_QUEUE=()

# --- Banner ---
display_banner() {
echo -e "${BLUE}"
cat << 'EOF'
███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     
██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     
███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     
╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     
███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗
╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝

    _   _   _ _____ ___  __  __    _  _____ _____ ____  
   / \ | | | |_   _/ _ \|  \/  |  / \|_   _| ____|  _ \ 
  / _ \| | | | | || | | | |\/| | / _ \ | | |  _| | | | |
 / ___ \ |_| | | || |_| | |  | |/ ___ \| | | |___| |_| |
/_/__ \_\___/__|_| \___/|_|__|_/_/   \_\_| |_____|____/ 
/ ___|| ____|_   _| | | |  _ \                          
\___ \|  _|   | | | | | | |_) |                         
 ___) | |___  | | | |_| |  __/                          
|____/|_____| |_|  \___/|_|_    _  _____ ___  ____      
\ \   / / \  | |   |_ _|  _ \  / \|_   _/ _ \|  _ \     
 \ \ / / _ \ | |    | || | | |/ _ \ | || | | | |_) |    
  \ V / ___ \| |___ | || |_| / ___ \| || |_| |  _ <     
   \_/_/   \_\_____|___|____/_/   \_\_| \___/|_| \_\    
EOF
echo -e "${NC}"
bold "           🛡️  AUTOMATED SETUP VALIDATOR  🛡️"
echo ""
info "Checking system requirements for Sentinel AK-XL Virtual SOC..."
echo ""
}

# --- Utility functions ---
is_wsl() { 
    grep -qi "microsoft" /proc/version 2>/dev/null || [[ -n "${WSL_INTEROP:-}" ]]
}

is_ubuntu() { 
    [[ -f /etc/os-release ]] && . /etc/os-release && [[ "${ID:-}" == "ubuntu" ]]
}

is_macos() {
    [[ "$(uname)" == "Darwin" ]]
}

version_compare() {
    # Returns 0 if $1 >= $2, 1 otherwise
    printf '%s\n%s\n' "$2" "$1" | sort -V -C 2>/dev/null
}

get_ram_gb() {
    if is_macos; then
        # macOS: convert bytes to GB
        echo "$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))"
    else
        # Linux: convert KB to GB
        awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo
    fi
}

get_free_space_gb() {
    if is_macos; then
        df -g . | awk 'NR==2 {print $4}'
    else
        df -BG . | awk 'NR==2 {gsub(/G/, "", $4); print $4}'
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -p "${prompt} (y/n): " response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

add_to_install_queue() {
    INSTALL_QUEUE+=("$1")
    ((ISSUES_FOUND++))
}

# --- System checks ---
check_operating_system() {
    bold "🖥️  Checking Operating System..."
    
    if is_macos; then
        local macos_version=$(sw_vers -productVersion)
        ok "macOS ${macos_version} detected"
        warn "Note: This project is optimized for Linux. macOS support may have limitations."
        info "Consider using Docker Desktop for macOS or a Linux VM"
        return 0
    fi
    
    if is_ubuntu; then
        local ubuntu_version=$(lsb_release -rs 2>/dev/null || echo "unknown")
        if version_compare "$ubuntu_version" "$REQUIRED_UBUNTU_VERSION"; then
            ok "Ubuntu ${ubuntu_version} detected (>= ${REQUIRED_UBUNTU_VERSION} required)"
        else
            warn "Ubuntu ${ubuntu_version} detected, but ${REQUIRED_UBUNTU_VERSION}+ recommended"
            warn "Some features may not work optimally"
        fi
        
        if is_wsl; then
            ok "WSL2 environment detected"
            info "Ensure WSL2 is configured with adequate resources (see ~/.wslconfig)"
        fi
    else
        warn "Non-Ubuntu Linux distribution detected"
        info "Ubuntu ${REQUIRED_UBUNTU_VERSION}+ is recommended for optimal compatibility"
        
        # Check for basic Linux requirements
        if [[ ! -f /etc/os-release ]]; then
            err "Cannot determine Linux distribution. /etc/os-release not found"
            add_to_install_queue "os-check"
        fi
    fi
}

check_system_resources() {
    bold "💾 Checking System Resources..."
    
    # Memory check
    local ram_gb=$(get_ram_gb)
    info "Detected RAM: ${ram_gb} GB"
    
    if (( ram_gb >= REQUIRED_RAM_GB )); then
        ok "RAM: ${ram_gb} GB (>= ${REQUIRED_RAM_GB} GB required) ✓"
    else
        warn "RAM: ${ram_gb} GB (< ${REQUIRED_RAM_GB} GB required) ⚠️"
        
        if is_wsl; then
            warn "For WSL2, configure ~/.wslconfig:"
            cat << 'EOF'
[wsl2]
memory=12GB
processors=4
swap=2GB
EOF
            info "After creating/updating ~/.wslconfig, restart WSL with: wsl --shutdown"
        else
            warn "Consider adding more RAM or adjusting Docker memory limits"
        fi
        add_to_install_queue "memory-config"
    fi
    
    # Disk space check
    local free_space_gb=$(get_free_space_gb)
    info "Available disk space: ${free_space_gb} GB"
    
    if (( free_space_gb >= REQUIRED_DISK_GB )); then
        ok "Disk space: ${free_space_gb} GB (>= ${REQUIRED_DISK_GB} GB required) ✓"
    else
        warn "Disk space: ${free_space_gb} GB (< ${REQUIRED_DISK_GB} GB required) ⚠️"
        warn "Free up disk space or use external storage for Docker volumes"
        add_to_install_queue "disk-space"
    fi
}

check_docker() {
    bold "🐳 Checking Docker Engine..."
    
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        local docker_major_minor=$(echo "$docker_version" | grep -oE '[0-9]+\.[0-9]+')
        
        if version_compare "$docker_major_minor" "$REQUIRED_DOCKER_VERSION"; then
            ok "Docker ${docker_version} detected (>= ${REQUIRED_DOCKER_VERSION} required) ✓"
            
            # Check if Docker daemon is running
            if docker ps >/dev/null 2>&1; then
                ok "Docker daemon is running ✓"
            else
                warn "Docker is installed but daemon is not running"
                info "Start Docker service: sudo systemctl start docker"
                add_to_install_queue "docker-service"
            fi
            
            # Check Docker permissions
            if docker ps >/dev/null 2>&1 || groups | grep -q docker; then
                ok "Docker permissions configured ✓"
            else
                warn "Current user not in docker group"
                info "Add user to docker group: sudo usermod -aG docker \$USER"
                add_to_install_queue "docker-permissions"
            fi
            
        else
            warn "Docker ${docker_version} detected, but ${REQUIRED_DOCKER_VERSION}+ required"
            if prompt_yes_no "Update Docker to the latest version?"; then
                add_to_install_queue "docker-update"
            fi
        fi
    else
        warn "Docker not found ❌"
        if prompt_yes_no "Install Docker Engine?"; then
            add_to_install_queue "docker-install"
        fi
    fi
}

check_docker_compose() {
    bold "🐙 Checking Docker Compose..."
    
    # Check for docker compose (modern syntax)
    if docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version --short 2>/dev/null || docker compose version | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -n1 | sed 's/^v//')
        local compose_major_minor=$(echo "$compose_version" | grep -oE '[0-9]+\.[0-9]+')
        
        if version_compare "$compose_major_minor" "$REQUIRED_COMPOSE_VERSION"; then
            ok "Docker Compose ${compose_version} detected (>= ${REQUIRED_COMPOSE_VERSION} required) ✓"
        else
            warn "Docker Compose ${compose_version} detected, but ${REQUIRED_COMPOSE_VERSION}+ required"
            if prompt_yes_no "Update Docker Compose?"; then
                add_to_install_queue "compose-update"
            fi
        fi
        
    # Check for legacy docker-compose
    elif command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        local compose_major_minor=$(echo "$compose_version" | grep -oE '[0-9]+\.[0-9]+')
        
        ok "Legacy docker-compose ${compose_version} detected"
        info "Consider migrating to 'docker compose' (plugin version) for better performance"
        
        if version_compare "$compose_major_minor" "1.29"; then
            ok "Version is compatible ✓"
        else
            warn "Legacy docker-compose version may have compatibility issues"
            if prompt_yes_no "Install modern Docker Compose plugin?"; then
                add_to_install_queue "compose-install"
            fi
        fi
    else
        warn "Docker Compose not found ❌"
        if prompt_yes_no "Install Docker Compose?"; then
            add_to_install_queue "compose-install"
        fi
    fi
}

check_system_utilities() {
    bold "🔧 Checking System Utilities..."
    
    local required_utils=("curl" "jq" "awk" "git")
    local missing_utils=()
    
    for util in "${required_utils[@]}"; do
        if command -v "$util" >/dev/null 2>&1; then
            local version_info=""
            case "$util" in
                curl) version_info=$(curl --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "") ;;
                jq) version_info=$(jq --version | grep -oE '[0-9]+\.[0-9]+' || echo "") ;;
                git) version_info=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "") ;;
                awk) version_info="system" ;;
            esac
            ok "${util} ${version_info} ✓"
        else
            warn "${util} not found ❌"
            missing_utils+=("$util")
        fi
    done
    
    if [[ ${#missing_utils[@]} -gt 0 ]]; then
        if prompt_yes_no "Install missing utilities: ${missing_utils[*]}?"; then
            add_to_install_queue "system-utilities:${missing_utils[*]}"
        fi
    fi
}

check_python() {
    bold "🐍 Checking Python (optional for simulators)..."
    
    if command -v python3 >/dev/null 2>&1; then
        local python_version=$(python3 --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        ok "Python3 ${python_version} detected ✓"
        
        # Check pip
        if command -v pip3 >/dev/null 2>&1; then
            ok "pip3 available ✓"
        else
            warn "pip3 not found - may be needed for Python dependencies"
        fi
    else
        warn "Python3 not found (optional - used by some simulation scenarios)"
        if prompt_yes_no "Install Python3?"; then
            add_to_install_queue "python3"
        fi
    fi
}

# --- Installation functions ---
install_docker() {
    info "Installing Docker Engine..."
    
    if is_ubuntu; then
        # Official Docker installation for Ubuntu
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Set up repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add user to docker group
        sudo usermod -aG docker "$USER"
        
        ok "Docker installed successfully"
        warn "Please log out and log back in for docker group membership to take effect"
        
    elif is_macos; then
        warn "Please install Docker Desktop for macOS from: https://docs.docker.com/docker-for-mac/install/"
        info "After installation, start Docker Desktop and ensure it's running"
        
    else
        warn "Automated Docker installation not supported for this OS"
        info "Please install Docker manually: https://docs.docker.com/engine/install/"
    fi
}

install_docker_compose() {
    info "Installing Docker Compose plugin..."
    
    if is_ubuntu; then
        # Install via apt (modern method)
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
        ok "Docker Compose plugin installed"
        
    elif is_macos; then
        info "Docker Compose is included with Docker Desktop for macOS"
        
    else
        # Generic installation
        info "Installing Docker Compose via curl..."
        local compose_version="2.20.0"  # Latest stable
        sudo curl -L "https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        ok "Docker Compose installed"
    fi
}

install_system_utilities() {
    local utils="$1"
    info "Installing system utilities: $utils"
    
    if is_ubuntu; then
        sudo apt-get update
        for util in $utils; do
            case "$util" in
                curl) sudo apt-get install -y curl ;;
                jq) sudo apt-get install -y jq ;;
                git) sudo apt-get install -y git ;;
                awk) sudo apt-get install -y gawk ;;
            esac
        done
        
    elif is_macos; then
        if command -v brew >/dev/null 2>&1; then
            for util in $utils; do
                case "$util" in
                    jq) brew install jq ;;
                    git) brew install git ;;
                    # curl and awk are built-in on macOS
                esac
            done
        else
            warn "Homebrew not found. Please install utilities manually or install Homebrew first"
            info "Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        fi
        
    else
        warn "Please install the following utilities manually: $utils"
    fi
}

install_python() {
    info "Installing Python3..."
    
    if is_ubuntu; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip
        
    elif is_macos; then
        if command -v brew >/dev/null 2>&1; then
            brew install python3
        else
            warn "Please install Python3 manually or install Homebrew first"
        fi
        
    else
        warn "Please install Python3 manually for your distribution"
    fi
}

# --- Main execution functions ---
run_checks() {
    check_operating_system
    check_system_resources
    check_docker
    check_docker_compose
    check_system_utilities
    check_python
}

process_install_queue() {
    if [[ ${#INSTALL_QUEUE[@]} -eq 0 ]]; then
        ok "All requirements satisfied! ✅"
        echo ""
        bold "🚀 Ready to deploy Sentinel AK-XL!"
        info "Next steps:"
        echo "  1. Run: ./initial_setup.sh"
        echo "  2. Configure your .env file with API keys"
        echo "  3. Access dashboards at http://localhost:5601"
        return 0
    fi
    
    echo ""
    bold "📋 Installation Summary:"
    warn "Found ${ISSUES_FOUND} issue(s) that need attention:"
    
    for item in "${INSTALL_QUEUE[@]}"; do
        echo "  - $item"
    done
    
    echo ""
    if prompt_yes_no "Proceed with automated installation/fixes?"; then
        echo ""
        info "Starting automated installation process..."
        
        for item in "${INSTALL_QUEUE[@]}"; do
            case "$item" in
                docker-install) install_docker ;;
                docker-update) install_docker ;;
                compose-install) install_docker_compose ;;
                compose-update) install_docker_compose ;;
                system-utilities:*) 
                    local utils="${item#system-utilities:}"
                    install_system_utilities "$utils" ;;
                python3) install_python ;;
                docker-service)
                    info "Starting Docker service..."
                    sudo systemctl start docker
                    sudo systemctl enable docker ;;
                docker-permissions)
                    info "Adding user to docker group..."
                    sudo usermod -aG docker "$USER"
                    warn "Please log out and log back in for changes to take effect" ;;
                memory-config)
                    warn "Please configure system memory as indicated above" ;;
                disk-space)
                    warn "Please free up disk space before proceeding" ;;
                *)
                    warn "Manual intervention required for: $item" ;;
            esac
        done
        
        echo ""
        ok "Installation process completed!"
        warn "If Docker group membership was changed, please log out and log back in"
        echo ""
        bold "🔄 Re-run this script to verify all requirements are now satisfied"
        
    else
        echo ""
        warn "Installation cancelled. Please resolve the issues manually and re-run this script."
        info "Refer to the project documentation for manual installation instructions."
    fi
}

create_env_template() {
    if [[ ! -f .env ]]; then
        info "Creating .env template..."
        cat > .env << 'EOF'
# Wazuh Authentication
WAZUH_INDEXER_PASSWORD=SecurePassword123
WAZUH_API_PASSWORD=SecurePassword123

# Threat Intelligence (Get your API key from https://www.virustotal.com/gui/user/apikey)
VIRUSTOTAL_API_KEY=your-virustotal-api-key-here
# Alternative name (both work)
VT_API_KEY=your-virustotal-api-key-here
EOF
        ok ".env template created"
        warn "Please edit .env file with your actual API keys before running initial_setup.sh"
    fi
}

# --- Main execution ---
main() {
    display_banner
    
    # Run all checks
    run_checks
    
    echo ""
    bold "==============================================="
    
    # Process installation queue
    process_install_queue
    
    # Create .env template if it doesn't exist
    create_env_template
    
    echo ""
    bold "📚 Additional Resources:"
    echo "  - Project Documentation: ./docs/"
    echo "  - Quick Start Guide: ./docs/01-getting-started/quick-start-guide.md"
    echo "  - System Requirements: ./docs/01-getting-started/system-requirements.md"
    echo "  - Troubleshooting: ./docs/03-operations/troubleshooting.md"
    echo ""
}

# Execute main function
main "$@"