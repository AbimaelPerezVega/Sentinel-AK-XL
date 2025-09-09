#!/bin/bash

# ==============================================================================
# SSH Authentication Simulator Script
# Generates realistic SSH failure logs for SOC training and dashboard testing
# Compatible with Wazuh agent monitoring and ELK stack processing
# ==============================================================================

# === First-time setup commands (inside container) ===
# Copy script to Wazuh Manager:
#   docker cp ./scenarios-simulator/ssh-auth/ssh-auth-simulator.sh sentinel-wazuh-manager:/usr/local/bin/ssh-auth-simulator.sh
#
# Make it executable:
#   docker exec -it sentinel-wazuh-manager chmod +x /usr/local/bin/ssh-auth-simulator.sh
#
# Run simulation:
#   docker exec -it sentinel-wazuh-manager bash -lc \
#     'mkdir -p /var/ossec/logs/test && \
#      /usr/local/bin/ssh-auth-simulator.sh -l /var/ossec/logs/test/sshd.log -n 50 -v'

set -euo pipefail

# --- Output control (shared contract) ---
BANNER=true
QUIET=false
STEALTH=false
if [ "${SIM_PARENT:-0}" = "1" ]; then BANNER=false; fi
# Pre-parse minimal flags so we can honor them early
for __arg in "$@"; do
  case "$__arg" in
    --no-banner) BANNER=false ;;
    -q|--quiet)  QUIET=true ;;
    --stealth)   STEALTH=true; QUIET=true ;;
  esac
done

# === Configuration ===
SCRIPT_NAME="ssh-auth-simulator"
LOG_FILE="/var/log/auth.log"
SIMULATION_LOG="/var/log/ssh-auth-simulation.log"
PID_FILE="/tmp/ssh-auth-simulator.pid"
WAZUH_AGENT_LOG="/var/ossec/logs/active-responses.log"

# === Colors ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # Reset / no color

# === Logging helpers ===
log_info()    { $QUIET || $STEALTH || echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }
log_warning() { $QUIET && return 0 || echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }

# === Global arrays for realistic simulation data ===
declare -a SOURCE_IPS=(
    "103.124.106.4" "185.220.101.45" "189.201.241.25" "92.63.197.153"
    "167.99.164.201" "159.65.153.147" "46.101.230.157" "134.209.24.42"
    "198.211.99.118" "161.35.70.249" "178.128.83.165" "68.183.44.143"
    "188.166.83.65" "165.22.203.84" "64.227.123.199" "142.93.222.179"
    "206.189.147.161" "167.172.56.147" "157.230.42.88" "178.62.193.217"
    "159.89.174.23" "46.101.166.19" "95.217.134.208" "51.15.228.88"
    "194.147.32.101"
)

declare -a USERNAMES=(
    "root" "admin" "administrator" "user" "test" "guest" "oracle" "postgres"
    "mysql" "www-data" "apache" "nginx" "ubuntu" "centos" "debian" "redhat"
    "server" "backup" "ftp" "mail" "web" "db" "database" "service"
    "jenkins" "docker" "hadoop" "elastic" "kibana" "logstash" "support"
    "demo" "training" "temp" "public" "student" "teacher" "manager"
    "sales" "marketing" "hr" "finance" "it" "dev" "developer"
    "johnsmith" "mikejohnson" "sarahdavis" "davidwilson" "emilybrown"
    "123456" "password" "qwerty" "letmein" "welcome" "changeme"
)

declare -a SSH_FAILURE_MESSAGES=(
    "Failed password for"
    "Failed password for invalid user"
    "Connection closed by authenticating user"
    "Authentication failure for"
    "Invalid user"
    "Received disconnect from"
    "Failed keyboard-interactive"
    "Failed publickey for"
    "PAM authentication failure for user"
    "Maximum authentication attempts exceeded for"
)

declare -a ATTACK_PATTERNS=(
    "single_attempt"
    "slow_brute"
    "fast_brute"
    "credential_spray"
    "targeted_attack"
    "distributed"
)

# Configuration options
VERBOSE=false
CONTINUOUS=false
MAX_EVENTS=100
DELAY_MIN=1
DELAY_MAX=10
ATTACK_PATTERN="mixed"

# Signal handling for clean exit
cleanup() {
    log_info "Cleaning up SSH Authentication Simulator..."
    [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
    log_success "SSH Authentication Simulator stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Help function
show_help() {
    cat << EOF
${WHITE}SSH Authentication Simulator${NC}
Generates realistic SSH authentication failure logs for SOC training

${YELLOW}Usage:${NC}
    $0 [OPTIONS]

${YELLOW}Options:${NC}
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -c, --continuous        Run continuously (use Ctrl+C to stop)
    -n, --num-events NUM    Number of events to generate (default: 100)
    -d, --delay MIN-MAX     Delay range between events in seconds (default: 1-10)
    -p, --pattern PATTERN   Attack pattern: single_attempt, slow_brute, fast_brute,
                            credential_spray, targeted_attack, distributed, mixed
    -l, --log-file PATH     Custom log file path (default: $LOG_FILE)
    --dry-run               Show what would be generated without writing logs
    --no-banner             Hide header
    -q, --quiet             Reduce output (keeps errors and summaries)
    --stealth               No header, no config dump, no per-event output

${YELLOW}Examples:${NC}
    $0 -n 50
    $0 -c -p fast_brute -d 1-3
    $0 -p targeted_attack -n 25 -v
    $0 --dry-run -n 10
EOF
}

# Generate random timestamp within last 24 hours
generate_timestamp() {
    local random_seconds
    random_seconds=$(shuf -i 1-86400 -n 1)  # Last 24 hours
    local target_time=$(( $(date +%s) - random_seconds ))
    date -d "@$target_time" '+%b %d %H:%M:%S'
}

# Get random element from array
get_random_element() {
    local -n arr=$1
    echo "${arr[RANDOM % ${#arr[@]}]}"
}

# Generate SSH authentication failure log entry
generate_ssh_failure() {
    local pattern="$1"
    local timestamp
    timestamp=$(generate_timestamp)
    local hostname="sentinel-$(shuf -i 100-999 -n 1)"
    local process_id
    process_id=$(shuf -i 1000-9999 -n 1)
    local source_ip
    source_ip=$(get_random_element SOURCE_IPS)
    local port
    port=$(shuf -i 1024-65535 -n 1)
    local username=""
    local failure_type=""
    
    # Adjust generation based on attack pattern
    case "$pattern" in
        "targeted_attack")
            local high_value_users=("root" "admin" "administrator" "oracle" "postgres" "backup")
            username="${high_value_users[RANDOM % ${#high_value_users[@]}]}"
            failure_type="Failed password for"
            ;;
        "credential_spray")
            username=$(get_random_element USERNAMES)
            failure_type="Failed password for"
            ;;
        "fast_brute"|"slow_brute")
            local common_users=("root" "admin" "user" "test" "ubuntu")
            username="${common_users[RANDOM % ${#common_users[@]}]}"
            failure_type="Failed password for"
            ;;
        *)
            username=$(get_random_element USERNAMES)
            failure_type=$(get_random_element SSH_FAILURE_MESSAGES)
            ;;
    esac
    
    # Generate log entry in standard auth.log format
    local log_entry="$timestamp $hostname sshd[$process_id]: $failure_type $username from $source_ip port $port ssh2"
    
    # Add additional context for some failure types
    case "$failure_type" in
        "Invalid user")
            log_entry="$timestamp $hostname sshd[$process_id]: Invalid user $username from $source_ip port $port"
            ;;
        "Connection closed by authenticating user")
            log_entry="$timestamp $hostname sshd[$process_id]: Connection closed by authenticating user $username $source_ip port $port [preauth]"
            ;;
        "Maximum authentication attempts exceeded for")
            log_entry="$timestamp $hostname sshd[$process_id]: Maximum authentication attempts exceeded for $username from $source_ip port $port ssh2 [preauth]"
            ;;
    esac
    
    echo "$log_entry"
}

# Generate coordinated attack sequence
generate_attack_sequence() {
    local pattern="$1"
    local num_events="$2"
    local events_generated=0
    
    log_info "Generating $pattern attack sequence with $num_events events"
    
    case "$pattern" in
        "fast_brute")
            local attack_ip
            attack_ip=$(get_random_element SOURCE_IPS)
            local target_user="root"
            
            for ((i=1; i<=num_events; i++)); do
                local timestamp
                timestamp=$(date '+%b %d %H:%M:%S')
                local hostname="sentinel-web-$(shuf -i 1-3 -n 1)"
                local process_id
                process_id=$(shuf -i 1000-9999 -n 1)
                local port=22
                
                local log_entry="$timestamp $hostname sshd[$process_id]: Failed password for $target_user from $attack_ip port $port ssh2"
                echo "$log_entry" >> "$LOG_FILE"
                
                [ "$VERBOSE" = true ] && ! $STEALTH && echo -e "${CYAN}[FAST_BRUTE]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep "$(shuf -i 1-3 -n 1)"
            done
            ;;
            
        "distributed")
            local target_user="admin"
            local attack_ips=("${SOURCE_IPS[@]:0:5}")  # Use first 5 IPs
            
            for ((i=1; i<=num_events; i++)); do
                local attack_ip="${attack_ips[$((i % ${#attack_ips[@]}))]}"
                local log_entry
                log_entry=$(generate_ssh_failure "targeted_attack")
                
                # Replace IP in generated entry
                log_entry=$(echo "$log_entry" | sed "s/from [0-9.]\+/from $attack_ip/")
                
                echo "$log_entry" >> "$LOG_FILE"
                [ "$VERBOSE" = true ] && ! $STEALTH && echo -e "${PURPLE}[DISTRIBUTED]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep "$(shuf -i 2-8 -n 1)"
            done
            ;;
            
        "credential_spray")
            local attack_ip
            attack_ip=$(get_random_element SOURCE_IPS)
            
            for ((i=1; i<=num_events; i++)); do
                local username
                username=$(get_random_element USERNAMES)
                local timestamp
                timestamp=$(date '+%b %d %H:%M:%S')
                local hostname="sentinel-app-$(shuf -i 1-5 -n 1)"
                local process_id
                process_id=$(shuf -i 1000-9999 -n 1)
                
                local log_entry="$timestamp $hostname sshd[$process_id]: Failed password for $username from $attack_ip port 22 ssh2"
                echo "$log_entry" >> "$LOG_FILE"
                
                [ "$VERBOSE" = true ] && ! $STEALTH && echo -e "${YELLOW}[CRED_SPRAY]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep "$(shuf -i 5-15 -n 1)"
            done
            ;;
            
        *)
            for ((i=1; i<=num_events; i++)); do
                local selected_pattern=${ATTACK_PATTERNS[RANDOM % ${#ATTACK_PATTERNS[@]}]}
                local log_entry
                log_entry=$(generate_ssh_failure "$selected_pattern")
                
                echo "$log_entry" >> "$LOG_FILE"
                [ "$VERBOSE" = true ] && ! $STEALTH && echo -e "${GREEN}[MIXED]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep "$(shuf -i "$DELAY_MIN"-"$DELAY_MAX" -n 1)"
            done
            ;;
    esac
    
    log_success "Generated $events_generated authentication failure events"
}

# Validate requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    if [ ! -w "$(dirname "$LOG_FILE")" ]; then
        log_error "Cannot write to log directory $(dirname "$LOG_FILE")"
        log_info "Suggestion: Run with sudo or change log file path with -l option"
        exit 1
    fi
    
    local required_tools=("shuf" "date" "tee" "sed")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    touch "$SIMULATION_LOG" 2>/dev/null || {
        log_error "Cannot create simulation log file: $SIMULATION_LOG"
        exit 1
    }
    
    log_success "System requirements validated"
}

# Main simulation function
run_simulation() {
    local dry_run="$1"
    
    log_info "Starting SSH Authentication Simulator"
    if ! $STEALTH; then
      log_info "Configuration:"
      log_info "  - Events: $MAX_EVENTS"
      log_info "  - Pattern: $ATTACK_PATTERN"
      log_info "  - Delay: ${DELAY_MIN}-${DELAY_MAX} seconds"
      log_info "  - Continuous: $CONTINUOUS"
      log_info "  - Log File: $LOG_FILE"
      log_info "  - Dry Run: $dry_run"
    fi
    
    echo $$ > "$PID_FILE"
    
    if [ "$dry_run" = true ]; then
        log_info "DRY RUN - Showing sample events that would be generated:"
        for ((i=1; i<=5; i++)); do
            local sample_event
            sample_event=$(generate_ssh_failure "$ATTACK_PATTERN")
            ! $STEALTH && echo -e "${CYAN}[SAMPLE $i]${NC} $sample_event"
        done
        log_info "Dry run completed. Use without --dry-run to generate actual events."
        return
    fi
    
    if [ "$CONTINUOUS" = true ]; then
        log_info "Running in continuous mode. Press Ctrl+C to stop."
        local event_count=0
        
        while true; do
            generate_attack_sequence "$ATTACK_PATTERN" 1
            event_count=$((event_count + 1))
            
            if [ $((event_count % 10)) -eq 0 ]; then
                log_info "Generated $event_count events so far..."
            fi
            
            sleep "$(shuf -i "$DELAY_MIN"-"$DELAY_MAX" -n 1)"
        done
    else
        generate_attack_sequence "$ATTACK_PATTERN" "$MAX_EVENTS"
    fi
    
    log_success "SSH Authentication Simulation completed"
    log_info "Check Wazuh alerts and Kibana dashboards for generated events"
    log_info "Simulation log saved to: $SIMULATION_LOG"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-banner)
                BANNER=false
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --stealth)
                STEALTH=true
                QUIET=true
                VERBOSE=false
                shift
                ;;
            -c|--continuous)
                CONTINUOUS=true
                shift
                ;;
            -n|--num-events)
                MAX_EVENTS="$2"
                if ! [[ "$MAX_EVENTS" =~ ^[0-9]+$ ]] || [ "$MAX_EVENTS" -lt 1 ]; then
                    log_error "Invalid number of events: $MAX_EVENTS"
                    exit 1
                fi
                shift 2
                ;;
            -d|--delay)
                if [[ "$2" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    DELAY_MIN="${BASH_REMATCH[1]}"
                    DELAY_MAX="${BASH_REMATCH[2]}"
                    if [ "$DELAY_MIN" -gt "$DELAY_MAX" ]; then
                        log_error "Invalid delay range: min ($DELAY_MIN) > max ($DELAY_MAX)"
                        exit 1
                    fi
                else
                    log_error "Invalid delay format. Use MIN-MAX (e.g., 1-10)"
                    exit 1
                fi
                shift 2
                ;;
            -p|--pattern)
                ATTACK_PATTERN="$2"
                if [[ ! " ${ATTACK_PATTERNS[*]} mixed " =~ " ${ATTACK_PATTERN} " ]]; then
                    log_error "Invalid attack pattern: $ATTACK_PATTERN"
                    log_info "Available patterns: ${ATTACK_PATTERNS[*]} mixed"
                    exit 1
                fi
                shift 2
                ;;
            -l|--log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                log_info "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    if $BANNER; then
      echo -e "${WHITE}"
      echo "=================================================================="
      echo "           SSH Authentication Simulator"
      echo "       Sentinel SOC Training Environment"
      echo "=================================================================="
      echo -e "${NC}"
    fi
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check requirements
    check_requirements
    
    # Run simulation
    run_simulation "${DRY_RUN:-false}"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
