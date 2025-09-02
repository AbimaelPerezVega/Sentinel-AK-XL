#!/usr/bin/env bash
set -euo pipefail
ES="https://localhost:9201"    # maps to wazuh-indexer:9200 on the host
AUTH="admin:admin"

echo "[*] Checking ingest pipeline..."
curl -sk -u "$AUTH" "$ES/_ingest/pipeline" | grep -q 'filebeat-7.10.2-wazuh-alerts-pipeline' \
  && echo "OK pipeline" || { echo "Missing pipeline"; exit 1; }

echo "[*] Checking template..."
curl -sk -u "$AUTH" "$ES/_cat/templates" | grep -q '^wazuh\b' \
  && echo "OK template" || { echo "Missing template"; exit 1; }

echo "[*] Checking todays index..."
curl -sk -u "$AUTH" "$ES/_cat/indices/wazuh-alerts-*?v"
echo "✔ All checks passed"
