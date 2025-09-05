#!/bin/bash

# ===================================
# Docker Compose Fix Script for Sentinel AK-XL
# ===================================
# Fixes Docker Compose compatibility issues
# Author: Sentinel AK-XL Team
# Version: 1.0
# ===================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[FIX]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
   ____            __  _            __   ___   __ __    _  ____
  / __/___  ___  / /_(_)__  ___   / /  / _ | / //_/___| |/_/ / /
 _\ \/ -_)/ _ \/ __/ / _ \/ -_) / /  / __ |/ ,< ___/  >  </ / / 
/___/\__/_//_/\__/_/_//_/\__/ /_/  /_/ |_/_/|_|  /_/|_/_/_/  
                                                              
              🔧 DOCKER COMPOSE FIX 🔧
                Compatibility Resolver
EOF
    echo -e "${NC}"
}

# ===================================
# Diagnostic Functions
# ===================================

diagnose_issue() {
    step "Diagnosing Docker Compose issue..."
    
    echo "Docker version:"
    docker --version
    echo ""
    
    echo "Docker Compose (legacy) version:"
    docker-compose --version 2>/dev/null || echo "Not available"
    echo ""
    
    echo "Docker Compose (plugin) version:"
    docker compose version 2>/dev/null || echo "Not available"
    echo ""
    
    echo "Python packages related to Docker:"
    pip list | grep -i docker 2>/dev/null || echo "No Docker Python packages found via pip"
    echo ""
    
    echo "System package manager Docker packages:"
    if command -v apt &> /dev/null; then
        dpkg -l | grep docker 2>/dev/null || echo "No Docker packages found via apt"
    elif command -v yum &> /dev/null; then
        yum list installed | grep docker 2>/dev/null || echo "No Docker packages found via yum"
    fi
}

# ===================================
# Fix Functions
# ===================================

fix_requests_package() {
    step "Fixing requests package compatibility..."
    
    # The error suggests a conflict with the requests package and urllib3
    if command -v pip3 &> /dev/null; then
        log "Upgrading requests and urllib3 packages..."
        pip3 install --upgrade requests urllib3 --user
    elif command -v pip &> /dev/null; then
        log "Upgrading requests and urllib3 packages..."
        pip install --upgrade requests urllib3 --user
    else
        warn "pip not found, skipping Python package fix"
    fi
}

install_docker_compose_v2() {
    step "Installing Docker Compose v2 (recommended)..."
    
    # Check if Docker Compose v2 is already available
    if docker compose version &> /dev/null; then
        log "Docker Compose v2 is already available"
        return 0
    fi
    
    # Install Docker Compose v2 plugin
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log "Installing Docker Compose v2 for Linux..."
        
        # Create docker plugins directory
        mkdir -p ~/.docker/cli-plugins/
        
        # Download Docker Compose v2
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        log "Latest Docker Compose version: $COMPOSE_VERSION"
        
        curl -SL "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-linux-x86_64" -o ~/.docker/cli-plugins/docker-compose
        chmod +x ~/.docker/cli-plugins/docker-compose
        
        log "Docker Compose v2 installed successfully"
    else
        warn "Manual installation required for your OS. Please update Docker Desktop."
    fi
}

fix_docker_permissions() {
    step "Checking Docker permissions..."
    
    if ! docker info &> /dev/null; then
        error "Docker daemon not accessible. Checking permissions..."
        
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if ! groups | grep -q docker; then
                log "Adding current user to docker group..."
                sudo usermod -aG docker $USER
                warn "Please log out and log back in for group changes to take effect"
                warn "Or run: newgrp docker"
            fi
        fi
    else
        log "Docker permissions are correct"
    fi
}

remove_conflicting_packages() {
    step "Handling conflicting Docker packages..."
    
    # Check what's installed where
    local pip_docker_compose=$(pip3 show docker-compose 2>/dev/null | grep "Location" | grep -v "/usr/lib/python3/dist-packages" || echo "")
    local system_docker_compose=$(dpkg -l | grep "docker-compose" || echo "")
    
    if [[ -n "$pip_docker_compose" ]]; then
        log "Removing user-installed docker-compose..."
        pip3 uninstall docker-compose -y --user 2>/dev/null || true
    fi
    
    # Check for conflicting Python packages in user directory only
    local user_packages=$(pip3 list --user 2>/dev/null | grep -E "(docker-compose|docker-py)" || echo "")
    
    if [[ -n "$user_packages" ]]; then
        log "Removing user-installed conflicting packages..."
        pip3 uninstall docker-compose docker-py -y --user 2>/dev/null || true
    fi
    
    if [[ -n "$system_docker_compose" ]]; then
        log "System docker-compose package detected - this is OK, we'll use Docker Compose v2"
        log "System package: $system_docker_compose"
    fi
    
    log "Package cleanup completed"
}

update_scripts_to_use_v2() {
    step "Updating scripts to use Docker Compose v2..."
    
    # Update test-everything.sh
    if [[ -f test-everything.sh ]]; then
        log "Updating test-everything.sh to prefer Docker Compose v2..."
        sed -i.bak 's/docker-compose/docker compose/g' test-everything.sh
    fi
    
    # Update test-basic.sh
    if [[ -f test-basic.sh ]]; then
        log "Updating test-basic.sh to prefer Docker Compose v2..."
        sed -i.bak 's/docker-compose/docker compose/g' test-basic.sh
    fi
    
    # Update other scripts
    local scripts=(
        "cleanup.sh"
        "health-check.sh"
        "setup.sh"
        "quick-setup.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log "Updating $script to prefer Docker Compose v2..."
            sed -i.bak 's/COMPOSE_CMD="docker-compose"/COMPOSE_CMD="docker compose"/g' "$script"
        fi
    done
}

# ===================================
# Alternative Fix Functions
# ===================================

create_environment_override() {
    step "Creating environment override for Docker Compose..."
    
    # Create a local environment override
    cat > .env.docker-compose << 'EOF'
# Docker Compose Environment Override
# Use Docker Compose v2 (plugin) instead of legacy version
export COMPOSE_CMD="docker compose"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
EOF
    
    # Create a source script
    cat > source-docker-env.sh << 'EOF'
#!/bin/bash
# Source this script to use the correct Docker Compose version
export COMPOSE_CMD="docker compose"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "✅ Environment configured for Docker Compose v2"
echo "Use: \$COMPOSE_CMD instead of docker-compose"
echo "Example: \$COMPOSE_CMD up -d"
EOF
    
    chmod +x source-docker-env.sh
    log "Created environment override files"
}

simple_wrapper_fix() {
    step "Creating simple wrapper solution..."
    
    # Since you have Docker Compose v2 already installed, let's just use it
    cat > dc << 'EOF'
#!/bin/bash
# Simple Docker Compose v2 wrapper
exec docker compose "$@"
EOF
    
    chmod +x dc
    
    log "Created 'dc' wrapper command"
    log "You can now use './dc' instead of 'docker-compose'"
}

update_test_scripts_simple() {
    step "Updating test scripts to use Docker Compose v2..."
    
    # Create updated versions of the test scripts
    if [[ -f test-everything.sh ]]; then
        log "Creating test-everything-v2.sh with Docker Compose v2..."
        cp test-everything.sh test-everything-v2.sh
        
        # Replace docker-compose with docker compose in the new file
        sed -i 's/docker-compose/docker compose/g' test-everything-v2.sh
        sed -i 's/COMPOSE_CMD="docker-compose"/COMPOSE_CMD="docker compose"/g' test-everything-v2.sh
        
        # Add environment setup at the beginning
        sed -i '1a\\n# Use Docker Compose v2\nexport COMPOSE_CMD="docker compose"' test-everything-v2.sh
        
        chmod +x test-everything-v2.sh
    fi
    
    if [[ -f test-basic.sh ]]; then
        log "Creating test-basic-v2.sh with Docker Compose v2..."
        cp test-basic.sh test-basic-v2.sh
        
        # Replace docker-compose with docker compose
        sed -i 's/docker-compose/docker compose/g' test-basic-v2.sh
        sed -i 's/COMPOSE_CMD="docker-compose"/COMPOSE_CMD="docker compose"/g' test-basic-v2.sh
        
        # Add environment setup
        sed -i '1a\\n# Use Docker Compose v2\nexport COMPOSE_CMD="docker compose"' test-basic-v2.sh
        
        chmod +x test-basic-v2.sh
    fi
    
    log "Created v2 versions of test scripts"
}

# ===================================
# Test Functions
# ===================================

test_docker_compose() {
    step "Testing Docker Compose functionality..."
    
    # Test Docker Compose v2 first
    if docker compose version &> /dev/null; then
        log "✅ Docker Compose v2 is working"
        export COMPOSE_CMD="docker compose"
        
        # Test with a simple config
        echo "Testing with minimal configuration..."
        cat > test-compose.yml << 'EOF'
version: '3.8'
services:
  test:
    image: alpine:latest
    command: echo "Docker Compose test successful"
EOF
        
        if docker compose -f test-compose.yml config &> /dev/null; then
            log "✅ Docker Compose configuration test passed"
            rm -f test-compose.yml
            return 0
        else
            error "❌ Docker Compose configuration test failed"
            rm -f test-compose.yml
            return 1
        fi
        
    elif command -v docker-compose &> /dev/null; then
        log "⚠️  Using legacy docker-compose"
        export COMPOSE_CMD="docker-compose"
        
        # Test with a simple config
        cat > test-compose.yml << 'EOF'
version: '3.8'
services:
  test:
    image: alpine:latest
    command: echo "Docker Compose test successful"
EOF
        
        if docker-compose -f test-compose.yml config &> /dev/null; then
            log "✅ Legacy docker-compose working"
            rm -f test-compose.yml
            return 0
        else
            error "❌ Legacy docker-compose test failed"
            rm -f test-compose.yml
            return 1
        fi
    else
        error "❌ No working Docker Compose found"
        return 1
    fi
}

# ===================================
# Main Fix Process
# ===================================

run_fixes() {
    log "Running comprehensive Docker Compose fixes..."
    
    # Diagnose the current state
    diagnose_issue
    
    # Apply gentle fixes (no sudo required)
    fix_docker_permissions
    remove_conflicting_packages
    fix_requests_package
    
    # Create alternative solutions
    create_environment_override
    simple_wrapper_fix
    update_test_scripts_simple
    
    # Test the fixes
    if test_docker_compose; then
        log "✅ Docker Compose fixes applied successfully!"
        show_usage_info_v2
    else
        error "❌ Basic test failed, but alternative solutions created"
        show_alternative_usage
    fi
}

# ===================================
# Information Functions
# ===================================

show_usage_info_v2() {
    echo ""
    echo -e "${CYAN}🎉 Docker Compose Fixed Successfully!${NC}"
    echo ""
    echo -e "${CYAN}📋 Available Solutions:${NC}"
    echo -e "✅ Docker Compose v2 is available: ${YELLOW}docker compose${NC}"
    echo -e "✅ Simple wrapper created: ${YELLOW}./dc${NC}"
    echo -e "✅ Updated test scripts: ${YELLOW}./test-everything-v2.sh${NC}"
    echo -e "✅ Environment override: ${YELLOW}source source-docker-env.sh${NC}"
    echo ""
    echo -e "${CYAN}🚀 Recommended Next Steps:${NC}"
    echo -e "1. ${GREEN}Use the v2 test script:${NC} ${YELLOW}./test-everything-v2.sh${NC}"
    echo -e "2. ${GREEN}Or use the wrapper:${NC} ${YELLOW}./dc -f docker-compose-test.yml up -d${NC}"
    echo -e "3. ${GREEN}Or source the environment:${NC} ${YELLOW}source source-docker-env.sh && ./test-everything.sh${NC}"
    echo ""
    echo -e "${CYAN}💡 Quick Test:${NC}"
    echo -e "   docker compose --version"
    echo -e "   ./dc --version"
    echo ""
}

show_alternative_usage() {
    echo ""
    echo -e "${YELLOW}⚠️  Alternative Solutions Created${NC}"
    echo ""
    echo -e "${CYAN}🎯 Try these options:${NC}"
    echo ""
    echo -e "${GREEN}Option 1 - Use v2 test script:${NC}"
    echo -e "   ./test-everything-v2.sh"
    echo ""
    echo -e "${GREEN}Option 2 - Use wrapper command:${NC}"
    echo -e "   ./dc -f docker-compose-test.yml up -d elasticsearch"
    echo -e "   curl -u elastic:changeme123! http://localhost:9200"
    echo ""
    echo -e "${GREEN}Option 3 - Set environment and run:${NC}"
    echo -e "   source source-docker-env.sh"
    echo -e "   export COMPOSE_CMD='docker compose'"
    echo -e "   ./test-everything.sh"
    echo ""
    echo -e "${GREEN}Option 4 - Manual Docker Compose v2:${NC}"
    echo -e "   docker compose -f docker-compose-test.yml up -d"
    echo ""
}

show_manual_steps() {
    echo ""
    echo -e "${YELLOW}⚠️  Manual Steps Required${NC}"
    echo ""
    echo -e "${CYAN}1. Check Docker installation:${NC}"
    echo -e "   sudo systemctl status docker"
    echo -e "   docker --version"
    echo ""
    echo -e "${CYAN}2. Restart Docker service:${NC}"
    echo -e "   sudo systemctl restart docker"
    echo ""
    echo -e "${CYAN}3. Log out and log back in${NC}"
    echo -e "   (This applies group permissions)"
    echo ""
    echo -e "${CYAN}4. Install Docker Compose manually:${NC}"
    echo -e "   https://docs.docker.com/compose/install/"
    echo ""
    echo -e "${CYAN}5. Use the wrapper script:${NC}"
    echo -e "   ./docker-compose-wrapper.sh up -d"
    echo ""
}

# ===================================
# Main Function
# ===================================

main() {
    print_banner
    
    case "${1:-}" in
        --help|-h)
            echo "Docker Compose Fix Script for Sentinel AK-XL"
            echo ""
            echo "Usage: $0 [option]"
            echo ""
            echo "Options:"
            echo "  --help, -h         Show this help"
            echo "  --diagnose         Only run diagnostics"
            echo "  --test             Only test current setup"
            echo "  --force            Force all fixes"
            echo ""
            echo "This script fixes common Docker Compose compatibility issues."
            echo ""
            exit 0
            ;;
        --diagnose)
            diagnose_issue
            ;;
        --test)
            test_docker_compose
            ;;
        --force)
            log "Force mode: applying all fixes..."
            run_fixes
            ;;
        "")
            log "Starting Docker Compose compatibility fix..."
            run_fixes
            ;;
        *)
            error "Unknown option: $1"
            error "Use --help for usage information"
            exit 1
            ;;
    esac
}

# ===================================
# Script Entry Point
# ===================================

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Please run as a regular user."
    exit 1
fi

# Run main function
main "$@"
