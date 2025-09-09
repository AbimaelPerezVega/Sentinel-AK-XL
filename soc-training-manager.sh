#!/bin/bash
# ==============================================================================
# SOC Training Manager
# Manages simulation scenarios and data cleanup for Sentinel SOC training
# ==============================================================================

set -euo pipefail

# Configuration
WAZUH_CONTAINER="sentinel-wazuh-manager"
ELASTICSEARCH_CONTAINER="sentinel-elasticsearch"
KIBANA_CONTAINER="sentinel-kibana"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios-simulator"

# Colors
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'
PURPLE=$'\e[0;35m'
CYAN=$'\e[0;36m'
WHITE=$'\e[1;37m'
NC=$'\e[0m'

# Logging functions
log_info()    { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') - $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') - $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') - $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') - $1"; }

# Global stealth toggle (default: OFF). Enable with --stealth at startup.
STEALTH_MODE=false

# Toggle stealth mode on/off
toggle_stealth() {
  if [ "$STEALTH_MODE" = true ]; then
    STEALTH_MODE=false
    log_info "Stealth mode disabled"
  else
    STEALTH_MODE=true
    log_info "Stealth mode enabled"
  fi
}

# Session key generation for student mode
generate_session_key() {
    echo "TRN$(shuf -i 100-999 -n 1)"
}

# Store session info for verification
SESSION_LOG="/tmp/soc-training-sessions.log"

# Check if Docker containers are running
check_system_status() {
    log_info "Checking system status..."
    
    local containers=("$WAZUH_CONTAINER" "$ELASTICSEARCH_CONTAINER" "$KIBANA_CONTAINER")
    local all_running=true
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            log_success "$container is running"
        else
            log_error "$container is not running"
            all_running=false
        fi
    done
    
    if [ "$all_running" = true ]; then
        log_success "All core services are running"
        
        # Check Elasticsearch health
        if curl -s "http://localhost:9200/_cluster/health" | grep -q "green\|yellow"; then
            log_success "Elasticsearch cluster is healthy"
        else
            log_warning "Elasticsearch cluster health check failed"
        fi
        
        # Check if Kibana is accessible
        if curl -s "http://localhost:5601/api/status" > /dev/null 2>&1; then
            log_success "Kibana is accessible"
        else
            log_warning "Kibana accessibility check failed"
        fi
        
        return 0
    else
        log_error "Some services are not running. Please start the SOC environment first."
        return 1
    fi
}

# Copy simulation scripts to Wazuh container
copy_simulators_to_container() {
    log_info "Copying simulation scripts to Wazuh container..."
    
    local scripts=(
        "ssh-auth/ssh-auth-simulator.sh"
        "network/network-activity-simulator.sh"
        "malware-drop/malware-drop-simulator.sh"
    )
    
    for script in "${scripts[@]}"; do
        local script_path="$SCENARIOS_DIR/$script"
        local script_name=$(basename "$script")
        
        if [ -f "$script_path" ]; then
            docker cp "$script_path" "$WAZUH_CONTAINER:/usr/local/bin/$script_name"
            docker exec "$WAZUH_CONTAINER" chmod +x "/usr/local/bin/$script_name"
            log_success "Copied and made executable: $script_name"
        else
            log_error "Script not found: $script_path"
            return 1
        fi
    done
    
    # Ensure required directories exist
    docker exec "$WAZUH_CONTAINER" mkdir -p /var/ossec/logs/test
    docker exec "$WAZUH_CONTAINER" mkdir -p /var/ossec/data/fimtest
    docker exec "$WAZUH_CONTAINER" chown -R wazuh:wazuh /var/ossec/data/fimtest
    
    log_success "All simulation scripts copied and configured"
}

# Clean Elasticsearch data
clean_elasticsearch_data() {
    echo
    log_warning "This will delete all simulation data from Elasticsearch"
    echo -e "${YELLOW}Actions that will be performed:${NC}"
    echo "  - Delete all sentinel-logs-* indices"
    echo "  - Delete all wazuh-alerts-* indices"
    echo "  - Clear container log files"
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleaning Elasticsearch data..."
        
        # Get list of indices to delete
        log_info "Finding indices to delete..."
        local sentinel_indices=$(curl -s "http://localhost:9200/_cat/indices/sentinel-logs-*?h=index" 2>/dev/null || true)
        local wazuh_indices=$(curl -s "http://localhost:9200/_cat/indices/wazuh-alerts-*?h=index" 2>/dev/null || true)
        
        # Delete sentinel-logs indices one by one
        if [ -n "$sentinel_indices" ]; then
            log_info "Deleting sentinel-logs indices..."
            echo "$sentinel_indices" | while read -r index; do
                if [ -n "$index" ]; then
                    curl -s -X DELETE "http://localhost:9200/$index" > /dev/null
                    log_success "Deleted index: $index"
                fi
            done
        else
            log_info "No sentinel-logs indices found"
        fi
        
        # Delete wazuh-alerts indices one by one
        if [ -n "$wazuh_indices" ]; then
            log_info "Deleting wazuh-alerts indices..."
            echo "$wazuh_indices" | while read -r index; do
                if [ -n "$index" ]; then
                    curl -s -X DELETE "http://localhost:9200/$index" > /dev/null
                    log_success "Deleted index: $index"
                fi
            done
        else
            log_info "No wazuh-alerts indices found"
        fi
        
        # Clean up container log files
        log_info "Cleaning container log files..."
        docker exec "$WAZUH_CONTAINER" sh -c 'rm -f /var/ossec/logs/test/* 2>/dev/null || true'
        docker exec "$WAZUH_CONTAINER" sh -c 'rm -f /var/ossec/data/fimtest/* 2>/dev/null || true'
        
        # Verify cleanup
        sleep 2
        local remaining_sentinel=$(curl -s "http://localhost:9200/_cat/indices/sentinel-logs-*?h=index" 2>/dev/null | wc -l)
        local remaining_wazuh=$(curl -s "http://localhost:9200/_cat/indices/wazuh-alerts-*?h=index" 2>/dev/null | wc -l)
        
        if [ "$remaining_sentinel" -eq 0 ] && [ "$remaining_wazuh" -eq 0 ]; then
            log_success "All simulation data cleared successfully"
        else
            if [ "$remaining_sentinel" -gt 0 ]; then
                log_warning "$remaining_sentinel sentinel-logs indices still exist"
            fi
            if [ "$remaining_wazuh" -gt 0 ]; then
                log_warning "$remaining_wazuh wazuh-alerts indices still exist"
            fi
        fi
        
        log_success "Data cleanup completed"
        sleep 2
    else
        log_info "Data cleanup cancelled"
    fi
}

# Run SSH authentication simulation
run_ssh_simulation() {
    local events=${1:-50}
    local pattern=${2:-mixed}
    
    log_info "Starting SSH authentication simulation..."
    log_info "Events: $events, Pattern: $pattern"

    # Compose env/flags for child scripts
    local common_env=(-e SIM_PARENT=1)
    local stealth_env=()
    local stealth_flags=()
    local verbose_flag=(-v)
    if [ "$STEALTH_MODE" = true ]; then
        stealth_env=(-e STEALTH=1)
        stealth_flags=(--no-banner --quiet --stealth)
        verbose_flag=()
    fi
    
    docker exec "${common_env[@]}" "${stealth_env[@]}" "$WAZUH_CONTAINER" /usr/local/bin/ssh-auth-simulator.sh \
        -n "$events" \
        -p "$pattern" \
        -l /var/ossec/logs/test/sshd.log \
        -d 1-5 \
        "${verbose_flag[@]}" \
        "${stealth_flags[@]}"
    
    log_success "SSH simulation completed"
}

# Run network activity simulation
run_network_simulation() {
    local events=${1:-30}
    local pattern=${2:-portscan_fast}
    
    log_info "Starting network activity simulation..."
    log_info "Events: $events, Pattern: $pattern"

    local common_env=(-e SIM_PARENT=1)
    local stealth_env=()
    local stealth_flags=()
    local verbose_flag=(-v)
    if [ "$STEALTH_MODE" = true ]; then
        stealth_env=(-e STEALTH=1)
        stealth_flags=(--no-banner --quiet --stealth)
        verbose_flag=()
    fi
    
    docker exec "${common_env[@]}" "${stealth_env[@]}" "$WAZUH_CONTAINER" /usr/local/bin/network-activity-simulator.sh \
        -n "$events" \
        -p "$pattern" \
        -d 0-2 \
        "${verbose_flag[@]}" \
        "${stealth_flags[@]}"
    
    log_success "Network simulation completed"
}

# Run malware drop simulation
run_malware_simulation() {
    local files=${1:-10}
    local ratio=${2:-3}
    
    log_info "Starting malware drop simulation..."
    log_info "Files: $files, Malicious ratio: 1 in $ratio"

    local common_env=(-e SIM_PARENT=1)
    local stealth_env=()
    local stealth_flags=()
    if [ "$STEALTH_MODE" = true ]; then
        stealth_env=(-e STEALTH=1)
        stealth_flags=(--no-banner --quiet --stealth)
    fi
    
    docker exec "${common_env[@]}" "${stealth_env[@]}" "$WAZUH_CONTAINER" /usr/local/bin/malware-drop-simulator.sh \
        "${stealth_flags[@]}" \
        "$files" "$ratio"
    
    log_success "Malware simulation completed"
}

# Run mixed attack scenario
run_mixed_scenario() {
    log_info "Starting mixed attack scenario..."
    
    # Run simulations with some delay between them
    run_ssh_simulation 30 "fast_brute" &
    sleep 5
    run_network_simulation 20 "portscan_slow" &
    sleep 10
    run_malware_simulation 8 2 &
    
    # Wait for all background jobs
    wait
    
    log_success "Mixed attack scenario completed"
}

# Run unknown scenario for student mode
run_unknown_scenario() {
    local session_key=$(generate_session_key)
    local scenarios=("ssh_brute" "network_scan" "malware_drop" "mixed")
    local selected_scenario=${scenarios[$RANDOM % ${#scenarios[@]}]}
    
    # Log session for verification
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $session_key - $selected_scenario" >> "$SESSION_LOG"
    
    echo
    log_info "Starting unknown training scenario..."
    echo -e "${CYAN}Session Key: ${WHITE}$session_key${NC}"
    echo -e "${YELLOW}Save this key to verify the scenario later!${NC}"
    echo
    
    case "$selected_scenario" in
        "ssh_brute")
            run_ssh_simulation 40 "fast_brute"
            ;;
        "network_scan")
            run_network_simulation 25 "portscan_fast"
            ;;
        "malware_drop")
            run_malware_simulation 12 2
            ;;
        "mixed")
            run_mixed_scenario
            ;;
    esac
    
    echo
    log_success "Unknown scenario completed"
    echo -e "${CYAN}Session Key: ${WHITE}$session_key${NC} (for verification)"
}

# Verify session key
verify_session_key() {
    echo
    read -p "Enter session key to verify: " session_key
    
    if [ -f "$SESSION_LOG" ] && grep -q "$session_key" "$SESSION_LOG"; then
        local log_line=$(grep "$session_key" "$SESSION_LOG")
        # Extract scenario using the last field after the last dash
        local scenario=$(echo "$log_line" | awk -F' - ' '{print $NF}')
        
        echo
        log_success "Session Key: $session_key"
        echo -e "${CYAN}Scenario Found: $scenario${NC}"
        echo
        
        case "$scenario" in
            "ssh_brute")
                echo -e "${GREEN}Scenario: SSH Brute Force Attack${NC}"
                echo "- Attack Type: Fast brute force"
                echo "- Events: ~40 failed login attempts"
                echo "- Focus: Authentication monitoring"
                echo "- Dashboard: Authentication Monitoring"
                ;;
            "network_scan")
                echo -e "${GREEN}Scenario: Network Port Scanning${NC}"
                echo "- Attack Type: Fast port scan"
                echo "- Events: ~25 network events"
                echo "- Focus: Network reconnaissance detection"
                echo "- Dashboard: Enhanced Network Analysis"
                ;;
            "malware_drop")
                echo -e "${GREEN}Scenario: Malware Drop Simulation${NC}"
                echo "- Attack Type: File integrity monitoring"
                echo "- Events: ~12 files (some malicious)"
                echo "- Focus: VirusTotal integration"
                echo "- Dashboard: Threat Intelligence Overview"
                ;;
            "mixed")
                echo -e "${GREEN}Scenario: Mixed Attack Campaign${NC}"
                echo "- Attack Type: Multi-vector attack"
                echo "- Events: SSH + Network + Malware"
                echo "- Focus: Comprehensive threat detection"
                echo "- Dashboard: All dashboards"
                ;;
            *)
                echo -e "${RED}Unknown scenario: $scenario${NC}"
                echo "Debug - Raw log line: $log_line"
                ;;
        esac
    else
        log_error "Session key not found: $session_key"
        if [ -f "$SESSION_LOG" ]; then
            echo "Available session keys:"
            awk -F' - ' '{print "  " $2}' "$SESSION_LOG" | tail -5
        fi
    fi
    echo
    echo "Press Enter to continue..."
    read
}

# Training scenarios menu
training_menu() {
    while true; do
        echo
        echo -e "${WHITE}=== Training Scenarios ===${NC}"
        echo -e "Current mode: ${YELLOW}$([ "$STEALTH_MODE" = true ] && echo 'STEALTH ON' || echo 'STEALTH OFF')${NC}"
        echo
        echo -e "${CYAN}[INSTRUCTOR MODE]${NC}"
        echo "1. SSH Brute Force Attack"
        echo "2. Network Port Scanning"
        echo "3. Malware Drop Simulation"
        echo "4. Mixed Attack Scenario"
        echo
        echo -e "${PURPLE}[STUDENT MODE]${NC}"
        echo "5. Unknown Scenario (generates session key)"
        echo "6. Verify Session Key"
        echo
        echo "0. Back to Main Menu"
        echo
        read -p "Enter choice [0-6]: " choice
        
        case $choice in
            1)
                echo
                log_info "SSH Brute Force Attack selected"
                run_ssh_simulation 50 "mixed"
                ;;
            2)
                echo
                log_info "Network Port Scanning selected"
                run_network_simulation 30 "portscan_fast"
                ;;
            3)
                echo
                log_info "Malware Drop Simulation selected"
                run_malware_simulation 10 3
                ;;
            4)
                echo
                log_info "Mixed Attack Scenario selected"
                run_mixed_scenario
                ;;
            5)
                echo
                run_unknown_scenario
                ;;
            6)
                verify_session_key
                ;;
            0)
                break
                ;;
            *)
                log_error "Invalid choice. Please try again."
                ;;
        esac
        
        if [ "$choice" != "0" ] && [ "$choice" != "6" ]; then
            echo
            echo -e "${GREEN}Check your Kibana dashboards at: ${WHITE}http://localhost:5601${NC}"
            echo "Press Enter to continue..."
            read
        fi
    done
}


# === Helpers to center text ===
term_cols() {
  local c
  c=$(tput cols 2>/dev/null) || c=80
  echo "${c:-80}"
}

# center_echo "texto_sin_color" "texto_coloreado(opcional)"
center_echo() {
  local plain="$1"
  local colored="${2:-$1}"
  local cols len pad
  cols=$(term_cols)
  len=${#plain}
  pad=$(( (cols - len) / 2 ))
  (( pad < 0 )) && pad=0
  printf "%*s%s\n" "$pad" "" "$colored"
}

# Display banner
show_banner() {
    # Logo ASCII (centrado línea por línea)
    local banner_lines=(
"███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     "
"██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     "
"███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     "
"╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     "
"███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗"
"╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝"
)
    for line in "${banner_lines[@]}"; do
        center_echo "$line" "${BLUE}${line}${NC}"
    done
    echo

    # Etiqueta de modo
    local mode_label
    if [ "${STEALTH_MODE:-false}" = true ]; then
        mode_label="STEALTH ON"
    else
        mode_label="STEALTH OFF"
    fi

    # Tres líneas centradas (plain para ancho, coloreadas para pantalla)
    center_echo "SOC Analyst Training"  "${YELLOW}SOC Analyst Training${NC}"
    center_echo "Training Manager v1.0" "${WHITE}Training Manager v1.0${NC}"
    center_echo "Mode: ${mode_label}"  "${WHITE}Mode: ${YELLOW}${mode_label}${NC}"
    echo
}

# Main menu
main_menu() {
    while true; do
        clear
        show_banner
        echo
        echo "1. Start Training Session"
        echo "2. Clean Data (Reset Elasticsearch)"
        echo "3. Check System Status"
        echo "4. Copy Simulators to Container"
        echo "5. Toggle Stealth Mode ($( [ "$STEALTH_MODE" = true ] && echo ON || echo OFF ))"
        echo "0. Exit"
        echo
        read -p "Enter choice [0-5]: " choice
        
        case $choice in
            1)
                if check_system_status; then
                    training_menu
                else
                    echo "Press Enter to continue..."
                    read
                fi
                ;;
            2)
                clean_elasticsearch_data
                ;;
            3)
                echo
                check_system_status
                echo
                echo "Press Enter to continue..."
                read
                ;;
            4)
                echo
                copy_simulators_to_container
                echo
                echo "Press Enter to continue..."
                read
                ;;
            5)
                toggle_stealth
                echo
                echo "Press Enter to continue..."
                read
                ;;
            0)
                echo
                log_info "Exiting SOC Training Manager"
                exit 0
                ;;
            *)
                log_error "Invalid choice. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Check requirements
check_requirements() {
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if scenarios directory exists
    if [ ! -d "$SCENARIOS_DIR" ]; then
        log_error "Scenarios directory not found: $SCENARIOS_DIR"
        log_info "Please ensure you're running this script from the project root"
        exit 1
    fi
    
    # Create session log if it doesn't exist
    touch "$SESSION_LOG"
}

# Main function
main() {
    # Parse global flags for the manager
    for arg in "$@"; do
        case "$arg" in
            --stealth) STEALTH_MODE=true ;;
        esac
    done

    check_requirements
    copy_simulators_to_container
    main_menu
}

# Execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
