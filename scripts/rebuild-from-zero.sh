#!/usr/bin/env bash
set -euo pipefail
docker compose down -v
docker compose up -d
echo "[*] Waiting 30s for services..."
sleep 30
./scripts/verify-wazuh.sh
