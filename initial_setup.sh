#!/usr/bin/env bash
# ==============================================================================
# Sentinel AK-XL - initial_setup.sh
# One-shot bootstrap: environment checks, certs, ordered startup, and E2E tests
#
# Usage:
#   ./initial_setup.sh                # defaults banner to "SENTINEL AK-XL"
#   ./initial_setup.sh "SENTINEL SOC" # custom banner title
#
# Covers:
# 1) System preflight (Ubuntu/WSL, RAM >= 9.6 GiB, required binaries)
# 2) .env validation + VirusTotal key check (alias VIRUSTOTAL_API_KEY/VT_API_KEY)
# 3) Local permissions (scripts, configs, certs)
# 4) Wazuh certificates (config.yml + wazuh-certs-tool.sh -A) + presence check
# 5) docker compose pull
# 6) Ordered startup with basic health checks (accept running if no healthcheck)
# 7) Post-templater soft permission fixes
# 8) Index template injection + test alert via wazuh-logtest + indices listing
# 9) Sysmon/agent simulator bootstrap (scripts/setup-sysmon.sh if present)
# 10) E2E pipeline health (cluster, Wazuh API token, ingest/count unique event)
# ==============================================================================
set -euo pipefail

# --- Colors & logging ---
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $(date '+%F %T') - $*"; }
ok(){   echo -e "${GREEN}[OK]${NC}  $(date '+%F %T') - $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $(date '+%F %T') - $*"; }
err(){  echo -e "${RED}[ERR]${NC}  $(date '+%F %T') - $*" >&2; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Banner (Cyberpunk / Metasploit-style) ---
# 256-color neon violet (fallback to magenta)
if command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]; then
  PURPLE=$'\e[38;5;141m'
else
  PURPLE=$'\e[35m'
fi
BOLD=$'\e[1m'; DIM=$'\e[2m'; RESET=$'\e[0m'

banner () {
  local title="${1:-SENTINEL AK-XL}"

  # Header lines
  printf '%b' "${PURPLE}${BOLD}=[ ${title} ]=\n"
  printf '%b' "${PURPLE}+ -- --=[ virtual soc bootstrap\n"
  printf '%b' "${PURPLE}+ -- --=[ wazuh • elk • virustotal\n"
  printf '%b' "${PURPLE}+ -- --=[ mode: cyberpunk\n"
  printf '%b' "${DIM}-----------------------------------------------------------${RESET}\n"

  # ASCII art - Fixed version
  printf '%b' "${PURPLE}${BOLD}"
  cat <<'ART'
   _____ ______ _   _________ _   ________   
  / ___// ____/ | / /_  __/ / | / / ____/ /
  \__ \/ __/ /  |/ / / / / /  |/ / __/ / /
 ___/ / /___/ /|  / / / / / /|  / /___/ /___
/____/_____/_/ |_/ /_/ /_/_/ |_/_____/_____/
                                                             
 ▄▄▄       ██ ▄█▀    ██▓  ██▓    
▒████▄     ██▄█▒    ▓██▒ ▓██▒    
▒██  ▀█▄  ▓███▄░    ▒██░ ▒██░    
░██▄▄▄▄██ ▓██ █▄    ▒██░ ▒██░    
 ▓█   ▓██▒▒██▒ █▄   ░██████▒░██████▒
 ▒▒   ▓▒█░▒ ▒▒ ▓▒   ░ ▒░▓  ░░ ▒░▓  ░
  ▒   ▒▒ ░░ ░▒ ▒░   ░ ░ ▒  ░░ ░ ▒  ░
  ░   ▒   ░ ░░ ░      ░ ░     ░ ░   
      ░  ░░  ░          ░  ░    ░  ░
ART
  printf '%b' "${RESET}"

  printf '%b' "${DIM}-----------------------------------------------------------${RESET}\n"
  printf '%b' "${PURPLE}${BOLD}=~[ bootstrap initializing ]~=${RESET}\n"
}

# -----------------------------
# Helpers
# -----------------------------
is_wsl(){ grep -qi "microsoft" /proc/version 2>/dev/null || [[ -n "${WSL_INTEROP:-}" ]]; }
is_ubuntu(){ [[ -f /etc/os-release ]] && . /etc/os-release && [[ "${ID:-}" == "ubuntu" ]]; }

require_cmd(){
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || { err "Missing required binary: $c"; exit 1; }
}

compose(){
  # Prefer 'docker compose'; fallback to 'docker-compose'
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@" 
  else
    require_cmd docker-compose
    docker-compose "$@"
  fi
}

wait_for_http(){
  # wait_for_http URL [-k] [max_seconds]
  local url="$1"; shift
  local insecure=0
  [[ "${1:-}" == "-k" ]] && { insecure=1; shift; }
  local max="${1:-120}"
  local t=0
  while (( t < max )); do
    if (( insecure==1 )); then
      if curl -sSk --max-time 3 -o /dev/null "$url"; then return 0; fi
    else
      if curl -sS  --max-time 3 -o /dev/null "$url"; then return 0; fi
    fi
    sleep 3; t=$((t+3))
  done
  return 1
}

wait_container_state(){
  # wait_container_state <container_name> <state> [max_seconds]
  # state: "exited0" | "healthy" | "running"
  local cname="$1" state="$2" max="${3:-180}"
  local t=0
  while (( t < max )); do
    if ! docker inspect "$cname" >/dev/null 2>&1; then
      sleep 2; t=$((t+2)); continue
    fi
    case "$state" in
      exited0)
        local st; st="$(docker inspect -f '{{.State.Status}} {{.State.ExitCode}}' "$cname" 2>/dev/null || true)"
        [[ "$st" == "exited 0" ]] && return 0
        ;;
      healthy)
        local h; h="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cname" 2>/dev/null || true)"
        [[ "$h" == "healthy" ]] && return 0
        # If no healthcheck, accept "running"
        local rs; rs="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || true)"
        [[ "$h" == "none" && "$rs" == "running" ]] && return 0
        ;;
      running)
        local rs; rs="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || true)"
        [[ "$rs" == "running" ]] && return 0
        ;;
    esac
    sleep 3; t=$((t+3))
  done
  return 1
}

mem_gib(){ awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo; }

ensure_read_exec(){
  # Soft perms without aggressive chown
  local path="$1"
  if [[ -d "$path" ]]; then
    chmod -R a+rX "$path"
  elif [[ -f "$path" ]]; then
    chmod a+r "$path"
  fi
}

# -----------------------------
# Kickoff (banner)
# -----------------------------
banner "${1:-SENTINEL AK-XL}"

# -----------------------------
# 1) System preflight
# -----------------------------
info "Preflight: detecting platform and verifying requirements…"
is_ubuntu && ok "Ubuntu detected" || warn "Ubuntu not explicitly detected (continuing)"
if is_wsl; then ok "WSL environment detected"; fi

for b in docker curl jq awk; do require_cmd "$b"; done

# Memory check
RAM="$(mem_gib)"
info "Detected memory: ${RAM} GiB"
awk -v r="$RAM" 'BEGIN{ exit !(r+0 >= 9.6) }' || {
  if is_wsl; then
    warn "RAM < 9.6 GiB on WSL. Recommended ~/.wslconfig and WSL restart:"
    cat <<'EOF'
[wsl2]
memory=12GB
processors=4
swap=0
EOF
  else
    warn "RAM < 9.6 GiB. Recommended >= 10 GiB for this stack."
  fi
}

# -----------------------------
# 2) .env validation + VirusTotal
# -----------------------------
ENV_FILE="$ROOT_DIR/.env"
[[ -f "$ENV_FILE" ]] || { err "Missing .env at repo root."; exit 1; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${WAZUH_INDEXER_PASSWORD:?Missing WAZUH_INDEXER_PASSWORD in .env}"
: "${WAZUH_API_PASSWORD:?Missing WAZUH_API_PASSWORD in .env}"

# Alias: support VT_API_KEY as well
if [[ -n "${VT_API_KEY:-}" && -z "${VIRUSTOTAL_API_KEY:-}" ]]; then
  VIRUSTOTAL_API_KEY="$VT_API_KEY"
fi

if [[ -z "${VIRUSTOTAL_API_KEY:-}" ]]; then
  warn "VIRUSTOTAL_API_KEY not set. Skipping VirusTotal validation."
else
  info "Validating VirusTotal API key…"
  code="$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "x-apikey: ${VIRUSTOTAL_API_KEY}" \
    https://www.virustotal.com/api/v3/users/me || true)"
  if [[ "$code" == "200" ]]; then
    ok "VirusTotal API key valid (200)"
  else
    warn "VirusTotal API key not validated (HTTP $code). Check your key."
  fi
fi

# -----------------------------
# 3) Local permissions
# -----------------------------
info "Adjusting local permissions…"
if [[ -d "$ROOT_DIR/scripts" ]]; then
  find "$ROOT_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi
if [[ -d "$ROOT_DIR/scenarios-simulator" ]]; then
  find "$ROOT_DIR/scenarios-simulator" -type f -name "*.sh" -exec chmod +x {} +
fi
ensure_read_exec "$ROOT_DIR/configs"
ensure_read_exec "$ROOT_DIR/wazuh-certificates"
ok "Permissions set (a+rX; +x on scripts)."

# -----------------------------
# 4) Wazuh certificates (idempotent)
# -----------------------------
info "Checking/Generating Wazuh certificates…"

CERTS_DIR="$ROOT_DIR/wazuh-certificates"

# Where to find config.yml for the cert tool
CERT_CONFIG=""
for c in "$ROOT_DIR/config.yml" "$CERTS_DIR/config.yml"; do
  [[ -f "$c" ]] && CERT_CONFIG="$c" && break
done
[[ -n "$CERT_CONFIG" ]] || { err "config.yml for wazuh-certs-tool not found."; exit 1; }

# Where to find the tool
CERT_TOOL=""
for t in "$CERTS_DIR/wazuh-certs-tool.sh" "$ROOT_DIR/wazuh-certs-tool.sh"; do
  [[ -f "$t" ]] && CERT_TOOL="$t" && break
done
[[ -n "$CERT_TOOL" ]] || warn "wazuh-certs-tool.sh not found; will only validate presence."

# Required files
declare -a REQUIRED_CERTS=(
  "admin-key.pem" "admin.pem"
  "root-ca.key" "root-ca.pem"
  "wazuh-dashboard-key.pem" "wazuh-dashboard.pem"
  "wazuh-indexer-key.pem" "wazuh-indexer.pem"
  "wazuh-manager-key.pem" "wazuh-manager.pem"
)

certs_complete() {
  for f in "${REQUIRED_CERTS[@]}"; do
    [[ -f "$CERTS_DIR/$f" ]] || return 1
  done
  return 0
}

generate_certs() {
  [[ -n "$CERT_TOOL" ]] || { err "Cannot generate certs: wazuh-certs-tool.sh not found."; exit 1; }
  info "Running wazuh-certs-tool.sh -A to create fresh certificates…"
  # The tool creates ./wazuh-certificates by itself and refuses if it already exists.
  bash "$CERT_TOOL" -A || { err "wazuh-certs-tool.sh -A failed."; exit 1; }
}

# Decide action
if [[ -d "$CERTS_DIR" ]]; then
  if [[ "${FORCE_REGEN:-0}" == "1" ]]; then
    warn "FORCE_REGEN=1 → backing up existing '$CERTS_DIR' and regenerating."
    mv "$CERTS_DIR" "${CERTS_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
    generate_certs
  else
    if certs_complete; then
      ok "Certificates already present and complete. Skipping generation."
    else
      warn "'$CERTS_DIR' exists but is incomplete. Backing up and regenerating."
      mv "$CERTS_DIR" "${CERTS_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
      generate_certs
    fi
  fi
else
  generate_certs
fi

# Final validation
if certs_complete; then
  ok "All required certificates are present."
else
  err "Certificates missing after generation. Check tool logs and config.yml."
  exit 1
fi

# -----------------------------
# 5) Pull images
# -----------------------------
info "Pulling images (docker compose pull)…"
compose pull
ok "Images updated."

# -----------------------------
# 6) Ordered startup
# -----------------------------
# Container names as defined in docker-compose.yml
C_BOOT="sentinel-wazuh-bootstrap"
C_TMPL="sentinel-wazuh-ossec-templater"
C_IDX="sentinel-wazuh-indexer"
C_MGR="sentinel-wazuh-manager"
C_DASH="sentinel-wazuh-dashboard"
C_LS="sentinel-logstash"
C_ES="sentinel-elasticsearch"
C_KB="sentinel-kibana"

info "Starting bootstrap…"
compose up -d wazuh-bootstrap
wait_container_state "$C_BOOT" exited0 120 || { err "wazuh-bootstrap did not exit 0 in time."; exit 1; }
ok "wazuh-bootstrap completed."

info "Rendering ossec.conf (templater)…"
compose up -d wazuh-ossec-templater
wait_container_state "$C_TMPL" exited0 120 || { err "wazuh-ossec-templater did not exit 0 in time."; exit 1; }
ok "ossec.conf rendered."

info "Starting Wazuh Indexer…"
compose up -d wazuh-indexer
if wait_for_http "https://localhost:9201" -k 240; then
  ok "Wazuh Indexer responds on 9201."
else
  warn "Could not confirm HTTPS 9201; checking 'running' state…"
  wait_container_state "$C_IDX" running 240 || { err "wazuh-indexer not running."; exit 1; }
fi

info "Starting Wazuh Manager…"
compose up -d wazuh-manager
if wait_for_http "https://localhost:55000" -k 240; then
  ok "Wazuh Manager API responds on 55000."
else
  warn "Could not confirm API 55000; checking 'running' state…"
  wait_container_state "$C_MGR" running 240 || { err "wazuh-manager not running."; exit 1; }
fi

info "Starting Elasticsearch + Logstash + Kibana…"
compose up -d elasticsearch logstash kibana
wait_for_http "http://localhost:9200" 240 || warn "Elasticsearch HTTP not confirmed in time."
wait_for_http "http://localhost:9600" 240 || warn "Logstash API not confirmed in time."
wait_for_http "http://localhost:5601" 240 || warn "Kibana not confirmed in time."

info "Starting Wazuh Dashboard…"
compose up -d wazuh-dashboard
wait_for_http "https://localhost:8443" -k 240 || warn "Wazuh Dashboard HTTPS not confirmed (may take time)."
ok "Ordered startup completed."

# -----------------------------
# 7) Post-templater soft perms
# -----------------------------
info "Reapplying soft permissions post-templater…"
ensure_read_exec "$ROOT_DIR/configs"
ensure_read_exec "$ROOT_DIR/wazuh-certificates"
ok "Permissions verified."

# -----------------------------
# 8) Index template + test alert
# -----------------------------
info "Creating/Updating 'wazuh' template in Indexer (OpenSearch)…"
set +e
curl -sS -k -u "admin:${WAZUH_INDEXER_PASSWORD}" \
  -X PUT "https://localhost:9201/_template/wazuh" \
  -H 'Content-Type: application/json' -d '{
    "index_patterns": ["wazuh-alerts-4.x-*"],
    "template": {
      "settings": {
        "index.refresh_interval": "5s",
        "index.number_of_shards": "1",
        "index.number_of_replicas": "0"
      },
      "mappings": {
        "dynamic_templates": [
          {
            "strings_as_keyword": {
              "match_mapping_type": "string",
              "mapping": {
                "type": "text",
                "fields": {
                  "keyword": {
                    "type": "keyword",
                    "ignore_above": 256
                  }
                }
              }
            }
          }
        ],
        "properties": {
          "timestamp":   { "type": "date" },
          "@timestamp":  { "type": "date" }
        }
      }
    }
  }' | jq . >/dev/null 2>&1
rc=$?
set -e
if (( rc==0 )); then ok "Template created/updated."; else warn "Template creation not confirmed. Check Indexer/credentials."; fi

info "Generating a test alert with wazuh-logtest (rules test only; no ingest)…"
echo 'Aug 29 21:00:00 ubuntu sshd[1234]: Failed password for root from 1.2.3.4 port 12345 ssh2' \
  | compose exec -T wazuh-manager /var/ossec/bin/wazuh-logtest || warn "wazuh-logtest reported an error."

info "Listing wazuh-alerts-* indices (if any)…"
set +e
curl -sS -k -u "admin:${WAZUH_INDEXER_PASSWORD}" "https://localhost:9201/_cat/indices" \
  | grep -E 'wazuh-alerts' || true
set -e

# -----------------------------
# 9) Sysmon / simulated agent bootstrap
# -----------------------------
if [[ -x "$ROOT_DIR/scripts/setup-sysmon.sh" ]]; then
  info "Running scripts/setup-sysmon.sh…"
  "$ROOT_DIR/scripts/setup-sysmon.sh" || warn "setup-sysmon.sh finished with warnings/errors."
else
  warn "scripts/setup-sysmon.sh not found/executable. Skipping Sysmon/Agent bootstrap."
  warn "If your flow needs manual manage_agents, see: doc/Sysmon-Agent-Installation/How_to_install_sysmon-agent.md"
fi

# -----------------------------
# 10) Pipeline health (E2E)
# -----------------------------
info "Health: Wazuh Indexer cluster…"
set +e
curl -sS -k -u "admin:${WAZUH_INDEXER_PASSWORD}" "https://localhost:9201/_cluster/health" | jq . || true
set -e

info "Health: Wazuh API authentication (token)…"
WZ_TOKEN="$(curl -sS -k -X POST "https://localhost:55000/security/user/authenticate" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"wazuh\",\"password\":\"${WAZUH_API_PASSWORD}\"}" | jq -r '.data.token' 2>/dev/null || true)"
if [[ -n "$WZ_TOKEN" && "$WZ_TOKEN" != "null" ]]; then
  ok "Wazuh API token obtained."
else
  warn "Could not obtain Wazuh API token. Check credentials/state."
fi

info "E2E: Writing a unique line into /var/ossec/logs/test/network.log and counting it in wazuh-alerts-*…"
UNIQ="AKXL-TEST-$(date +%s)"
compose exec -T wazuh-manager bash -lc "echo \"Aug 29 21:00:00 kernel: IPTABLES-DROP ${UNIQ} SRC=9.9.9.9 DST=1.1.1.1\" >> /var/ossec/logs/test/network.log" \
  || warn "Failed to append test log on manager."
sleep 7

COUNT="$(curl -sS -k -u "admin:${WAZUH_INDEXER_PASSWORD}" \
  -H 'Content-Type: application/json' \
  -d "{\"query\":{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"${UNIQ}\",\"fields\":[\"*.keyword\",\"message\",\"full_log\",\"data*\"]}}]}}}" \
  "https://localhost:9201/wazuh-alerts-*/_count" | jq -r '.count' 2>/dev/null || echo "0")"

if [[ "$COUNT" =~ ^[0-9]+$ ]] && (( COUNT >= 1 )); then
  ok "E2E OK: unique test event found in wazuh-alerts-* (count=${COUNT})."
else
  warn "E2E partial: unique event not found yet (count=${COUNT}). Pipeline (beats/decoders/rules) may still be starting."
fi

ok "Initial setup finished."
