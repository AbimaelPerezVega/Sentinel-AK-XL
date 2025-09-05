#!/bin/bash
# ==============================================================================
# Network Activity Simulator
# Generates syslog-style iptables/UFW-like events for Wazuh -> ELK pipeline
# Patterns: single_flow, portscan_slow, portscan_fast, udp_probe, mixed
# ==============================================================================

# === How to copy the script into the container ===
# docker cp ./scenarios-simulator/network/network-activity-simulator.sh \
#   sentinel-wazuh-manager:/usr/local/bin/network-activity-simulator.sh

# === How to run inside the container ===
# docker exec -it sentinel-wazuh-manager sh -lc \
#   'chmod +x /usr/local/bin/network-activity-simulator.sh && \
#    /usr/local/bin/network-activity-simulator.sh -n 1 -p single_flow -d 0-0 -v'

# === Example ===
# docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator.sh \
#   -n 1 -p portscan_fast -d 0-0 -v

set -euo pipefail

LOG_FILE="/var/ossec/logs/test/network.log"
SIM_LOG="/var/log/network-simulation.log"
PID_FILE="/tmp/network-activity-simulator.pid"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]$(date '+ %F %T')${NC} $*" | tee -a "$SIM_LOG" ; }
ok(){   echo -e "${GREEN}[OK]$(date '+ %F %T')${NC} $*"  | tee -a "$SIM_LOG" ; }
warn(){ echo -e "${YELLOW}[WARN]$(date '+ %F %T')${NC} $*"| tee -a "$SIM_LOG" ; }

VERBOSE=false
CONTINUOUS=false
MAX_EVENTS=100
DELAY_MIN=1
DELAY_MAX=5
PATTERN="mixed"

# External IPs (used for GeoIP testing)
SOURCE_IPS=(103.124.106.4 185.220.101.45 92.63.197.153 167.99.164.201 159.65.153.147 46.101.230.157 198.211.99.118 161.35.70.249 178.62.193.217 142.93.222.179 95.217.134.208 51.15.228.88 64.227.123.199)

# Common ports of interest
COMMON_TCP_PORTS=(22 80 443 3306 5432 9200 5601 3389 139 445 21 25 110 8080)
COMMON_UDP_PORTS=(53 123 161 500 67 68)

rand(){ shuf -i "$1"-"$2" -n 1; }
pick(){ local -n A=$1; echo "${A[$(rand 0 $((${#A[@]}-1)))]}"; }
timestamp(){ date '+%b %d %H:%M:%S'; }

emit_line(){
  local ts host proc src dst proto spt dpt action extra
  ts=$(timestamp)
  host="sentinel-$(rand 100 999)"
  proc="kernel:"

  src="$1"; dst="$2"; proto="$3"; spt="$4"; dpt="$5"; action="$6"; extra="$7"
  # Log line formatted like iptables/UFW
  local line="$ts $host $proc $action IN=eth0 OUT= MAC=de:ad:be:ef:00:01 SRC=$src DST=$dst LEN=$(rand 60 120) TOS=0x00 PREC=0x00 TTL=$(rand 32 64) ID=$(rand 10000 65000) DF PROTO=$proto SPT=$spt DPT=$dpt $extra"
  echo "$line" >> "$LOG_FILE"
  [ "$VERBOSE" = true ] && echo "$line"
}

# === Attack patterns ===
single_flow(){
  local src dst proto spt dpt
  src=$(pick SOURCE_IPS); dst="172.20.0.$(rand 10 30)"
  proto="TCP"; spt=$(rand 1024 65535); dpt=$(pick COMMON_TCP_PORTS)
  emit_line "$src" "$dst" "$proto" "$spt" "$dpt" "IPTABLES-DROP:" "SYN URGP=0"
}

udp_probe(){
  local src dst spt dpt
  src=$(pick SOURCE_IPS); dst="172.20.0.$(rand 10 30)"
  spt=$(rand 1024 65535); dpt=$(pick COMMON_UDP_PORTS)
  emit_line "$src" "$dst" "UDP" "$spt" "$dpt" "IPTABLES-DROP:" ""
}

portscan_fast(){
  local src dst proto spt
  src=$(pick SOURCE_IPS); dst="172.20.0.$(rand 10 30)"; proto="TCP"; spt=$(rand 20000 65000)
  for p in $(seq 20); do
    emit_line "$src" "$dst" "$proto" "$spt" "$(rand 1 1024)" "IPTABLES-DROP:" "SYN URGP=0"
    sleep 0.1
  done
}

portscan_slow(){
  local src dst proto spt
  src=$(pick SOURCE_IPS); dst="172.20.0.$(rand 10 30)"; proto="TCP"; spt=$(rand 10000 65000)
  for p in $(seq 8); do
    emit_line "$src" "$dst" "$proto" "$spt" "$(pick COMMON_TCP_PORTS)" "IPTABLES-DROP:" "SYN URGP=0"
    sleep "$(rand "$DELAY_MIN" "$DELAY_MAX")"
  done
}

# === Execution control ===
run_once(){
  case "$PATTERN" in
    single_flow) single_flow ;;
    udp_probe) udp_probe ;;
    portscan_fast) portscan_fast ;;
    portscan_slow) portscan_slow ;;
    mixed)
      case "$(rand 1 4)" in
        1) single_flow ;;
        2) udp_probe ;;
        3) portscan_fast ;;
        4) portscan_slow ;;
      esac
      ;;
    *) single_flow ;;
  esac
}

usage(){
  cat <<EOF
Network Activity Simulator
Usage: $0 [-n NUM] [-p PATTERN] [-d MIN-MAX] [-c] [-v] [-l LOGFILE]

Patterns:
  single_flow | portscan_fast | portscan_slow | udp_probe | mixed (default)

Examples:
  $0 -n 100 -p mixed -v
  $0 -p portscan_fast -n 60 -d 0-1
EOF
}

# === Argument parsing ===
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--num-events) MAX_EVENTS="$2"; shift 2 ;;
    -p|--pattern) PATTERN="$2"; shift 2 ;;
    -d|--delay)
      [[ "$2" =~ ^([0-9]+)-([0-9]+)$ ]] || { echo "Delay debe ser MIN-MAX"; exit 1; }
      DELAY_MIN="${BASH_REMATCH[1]}"; DELAY_MAX="${BASH_REMATCH[2]}"; shift 2 ;;
    -c|--continuous) CONTINUOUS=true; shift ;;
    -l|--log-file) LOG_FILE="$2"; shift 2 ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción inválida: $1"; usage; exit 1 ;;
  esac
done

# === Pre-checks ===
touch "$SIM_LOG" || true
mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE" || true

info "Log destino: $LOG_FILE"
info "Patrón: $PATTERN | Eventos: $MAX_EVENTS | Delay: ${DELAY_MIN}-${DELAY_MAX}s | Continuous: $CONTINUOUS"

# === Main execution ===
if $CONTINUOUS; then
  i=0
  while true; do
    run_once
    i=$((i+1))
    (( i % 10 == 0 )) && info "Generados $i eventos..."
    sleep "$(rand "$DELAY_MIN" "$DELAY_MAX")"
  done
else
  for ((i=1; i<=MAX_EVENTS; i++)); do
    run_once
    sleep "$(rand "$DELAY_MIN" "$DELAY_MAX")"
  done
  ok "Generados $MAX_EVENTS eventos de red"
fi
