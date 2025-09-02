#!/bin/bash

# ==============================================================================
# SSH Authentication Simulator Script
# Generates realistic SSH failure logs for SOC training and dashboard testing
# Compatible with Wazuh agent monitoring and ELK stack processing
# ==============================================================================

#===============================================================================
# Important commands for the first time running it
#
# docker cp simulator-scripts/ssh-auth-simulator.sh sentinel-wazuh-manager:/usr/local/bin/ssh-auth-simulator
# docker exec -it sentinel-wazuh-manager chmod +x /usr/local/bin/ssh-auth-simulator
# docker exec -it sentinel-wazuh-manager bash -lc \
# 'mkdir -p /var/ossec/logs/test && \
#  ssh-auth-simulator -l /var/ossec/logs/test/sshd.log -n 50 -v'
#===============================================================================
set -euo pipefail

# Configuration
SCRIPT_NAME="ssh-auth-simulator"
LOG_FILE="/var/log/auth.log"
SIMULATION_LOG="/var/log/ssh-auth-simulation.log"
PID_FILE="/tmp/ssh-auth-simulator.pid"
WAZUH_AGENT_LOG="/var/ossec/logs/active-responses.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$SIMULATION_LOG"; }

# Global arrays for realistic simulation data
declare -a SOURCE_IPS=(
    # Suspicious IPs from various countries for GeoIP testing
    "103.124.106.4"      # China - known for brute force
    "185.220.101.45"     # Russia - TOR exit node
    "189.201.241.25"     # Mexico - compromised hosts
    "92.63.197.153"      # Netherlands - VPN services
    "167.99.164.201"     # Germany - cloud hosting
    "159.65.153.147"     # Singapore - cloud hosting
    "46.101.230.157"     # UK - digital ocean
    "134.209.24.42"      # India - compromised systems
    "198.211.99.118"     # US - suspicious activity
    "161.35.70.249"      # Canada - cloud hosting
    "178.128.83.165"     # Australia - hosting provider
    "68.183.44.143"      # France - VPS provider
    "188.166.83.65"      # Spain - digital ocean
    "165.22.203.84"      # Brazil - cloud services
    "64.227.123.199"     # Italy - hosting
    "142.93.222.179"     # Japan - VPS
    "206.189.147.161"    # South Korea - cloud
    "167.172.56.147"     # Turkey - hosting
    "157.230.42.88"      # Poland - digital ocean
    "178.62.193.217"     # Sweden - hosting
    "159.89.174.23"      # Norway - cloud services
    "46.101.166.19"      # Finland - hosting
    "95.217.134.208"     # Czech Republic - hetzner
    "51.15.228.88"       # Romania - OVH hosting
    "194.147.32.101"     # Ukraine - compromised
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
    "single_attempt"     # One-off attempts
    "slow_brute"         # Slow brute force (1-5 attempts per hour)
    "fast_brute"         # Fast brute force (10+ attempts per minute)
    "credential_spray"   # Many users, few passwords
    "targeted_attack"    # Focused on specific accounts
    "distributed"        # Multiple IPs, coordinated
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
    --dry-run              Show what would be generated without writing logs

${YELLOW}Attack Patterns:${NC}
    ${GREEN}single_attempt${NC}   - Individual failed login attempts
    ${GREEN}slow_brute${NC}       - Slow brute force (1-5 attempts/hour)
    ${GREEN}fast_brute${NC}       - Fast brute force (10+ attempts/minute)
    ${GREEN}credential_spray${NC}  - Many users, few passwords
    ${GREEN}targeted_attack${NC}   - Focused on high-value accounts
    ${GREEN}distributed${NC}      - Multiple IPs, coordinated attack
    ${GREEN}mixed${NC}            - Combination of all patterns (default)

${YELLOW}Examples:${NC}
    # Generate 50 mixed authentication failures
    $0 -n 50

    # Run continuous simulation with fast brute force pattern
    $0 -c -p fast_brute -d 1-3

    # Generate targeted attack on admin accounts
    $0 -p targeted_attack -n 25 -v

    # Test run without writing logs
    $0 --dry-run -n 10
EOF
}

# Generate random timestamp within last 24 hours
generate_timestamp() {
    local random_seconds=$(shuf -i 1-86400 -n 1)  # Last 24 hours
    local target_time=$(($(date +%s) - random_seconds))
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
    local timestamp=$(generate_timestamp)
    local hostname="sentinel-$(shuf -i 100-999 -n 1)"
    local process_id=$(shuf -i 1000-9999 -n 1)
    local source_ip=$(get_random_element SOURCE_IPS)
    local port=$(shuf -i 1024-65535 -n 1)
    local username=""
    local failure_type=""
    
    # Adjust generation based on attack pattern
    case "$pattern" in
        "targeted_attack")
            # Focus on high-value accounts
            local high_value_users=("root" "admin" "administrator" "oracle" "postgres" "backup")
            username="${high_value_users[RANDOM % ${#high_value_users[@]}]}"
            failure_type="Failed password for"
            ;;
        "credential_spray")
            # Many users, common passwords pattern
            username=$(get_random_element USERNAMES)
            failure_type="Failed password for"
            ;;
        "fast_brute"|"slow_brute")
            # Brute force on common accounts
            local common_users=("root" "admin" "user" "test" "ubuntu")
            username="${common_users[RANDOM % ${#common_users[@]}]}"
            failure_type="Failed password for"
            ;;
        *)
            # Mixed/random pattern
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
            # Quick succession of attempts from same IP
            local attack_ip=$(get_random_element SOURCE_IPS)
            local target_user="root"
            
            for ((i=1; i<=num_events; i++)); do
                local timestamp=$(date '+%b %d %H:%M:%S')
                local hostname="sentinel-web-$(shuf -i 1-3 -n 1)"
                local process_id=$(shuf -i 1000-9999 -n 1)
                local port=22
                
                local log_entry="$timestamp $hostname sshd[$process_id]: Failed password for $target_user from $attack_ip port $port ssh2"
                echo "$log_entry" >> "$LOG_FILE"
                
                [ "$VERBOSE" = true ] && echo -e "${CYAN}[FAST_BRUTE]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep $(shuf -i 1-3 -n 1)  # Quick succession
            done
            ;;
            
        "distributed")
            # Coordinated attack from multiple IPs
            local target_user="admin"
            local attack_ips=("${SOURCE_IPS[@]:0:5}")  # Use first 5 IPs
            
            for ((i=1; i<=num_events; i++)); do
                local attack_ip="${attack_ips[$((i % ${#attack_ips[@]}))]}"
                local log_entry=$(generate_ssh_failure "targeted_attack")
                
                # Replace IP in generated entry
                log_entry=$(echo "$log_entry" | sed "s/from [0-9.]\+/from $attack_ip/")
                
                echo "$log_entry" >> "$LOG_FILE"
                [ "$VERBOSE" = true ] && echo -e "${PURPLE}[DISTRIBUTED]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep $(shuf -i 2-8 -n 1)  # Moderate delay
            done
            ;;
            
        "credential_spray")
            # Attack many users with common passwords
            local attack_ip=$(get_random_element SOURCE_IPS)
            
            for ((i=1; i<=num_events; i++)); do
                local username=$(get_random_element USERNAMES)
                local timestamp=$(date '+%b %d %H:%M:%S')
                local hostname="sentinel-app-$(shuf -i 1-5 -n 1)"
                local process_id=$(shuf -i 1000-9999 -n 1)
                
                local log_entry="$timestamp $hostname sshd[$process_id]: Failed password for $username from $attack_ip port 22 ssh2"
                echo "$log_entry" >> "$LOG_FILE"
                
                [ "$VERBOSE" = true ] && echo -e "${YELLOW}[CRED_SPRAY]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep $(shuf -i 5-15 -n 1)  # Slower to avoid detection
            done
            ;;
            
        *)
            # Default mixed pattern
            for ((i=1; i<=num_events; i++)); do
                local selected_pattern=${ATTACK_PATTERNS[RANDOM % ${#ATTACK_PATTERNS[@]}]}
                local log_entry=$(generate_ssh_failure "$selected_pattern")
                
                echo "$log_entry" >> "$LOG_FILE"
                [ "$VERBOSE" = true ] && echo -e "${GREEN}[MIXED]${NC} $log_entry"
                
                events_generated=$((events_generated + 1))
                sleep $(shuf -i $DELAY_MIN-$DELAY_MAX -n 1)
            done
            ;;
    esac
    
    log_success "Generated $events_generated authentication failure events"
}

# Validate requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check if we can write to the log file
    if [ ! -w "$(dirname "$LOG_FILE")" ]; then
        log_error "Cannot write to log directory $(dirname "$LOG_FILE")"
        log_info "Suggestion: Run with sudo or change log file path with -l option"
        exit 1
    fi
    
    # Check for required tools
    local required_tools=("shuf" "date" "tee")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    # Create simulation log file
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
    log_info "Configuration:"
    log_info "  - Events: $MAX_EVENTS"
    log_info "  - Pattern: $ATTACK_PATTERN"
    log_info "  - Delay: ${DELAY_MIN}-${DELAY_MAX} seconds"
    log_info "  - Continuous: $CONTINUOUS"
    log_info "  - Log File: $LOG_FILE"
    log_info "  - Dry Run: $dry_run"
    
    # Store PID for cleanup
    echo $$ > "$PID_FILE"
    
    if [ "$dry_run" = true ]; then
        log_info "DRY RUN - Showing sample events that would be generated:"
        for ((i=1; i<=5; i++)); do
            local sample_event=$(generate_ssh_failure "$ATTACK_PATTERN")
            echo -e "${CYAN}[SAMPLE $i]${NC} $sample_event"
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
            
            sleep $(shuf -i $DELAY_MIN-$DELAY_MAX -n 1)
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
    echo -e "${WHITE}"
    echo "=================================================================="
    echo "           SSH Authentication Simulator"
    echo "       Sentinel SOC Training Environment"
    echo "=================================================================="
    echo -e "${NC}"
    
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
