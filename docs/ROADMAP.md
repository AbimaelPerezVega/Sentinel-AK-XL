# 🗺️ Sentinel AK-XL – Updated Project Roadmap (with VirusTotal + GeoIP)

## 📋 Current Status – Major Wins

### Phase 1–2: Core Infrastructure ✅ 100% COMPLETE

* **ELK Stack:** Elasticsearch + Logstash + Kibana fully operational
* **Docker Environment:** Stable container orchestration
* **Network Configuration:** SSL/TLS scaffolding in place
* **Base Configuration:** Core configs validated and working

### Phase 3: SIEM Detection Engine ✅ 100% COMPLETE (was 95%)

* **Wazuh Manager:** Deployed and running (port 55000)
* **Wazuh Indexer:** Running and responding (port 9201)
* **Custom Detection Rules:** 8 rules created and installed
* **API Integration:** Wazuh API responding correctly
* **Log Processing:** Real-time ingestion and parsing active
* **SSL Certificates:** Generated and configured
* **Threat Intel:** **VirusTotal integration enabled** (Wazuh ➜ FIM/syscheck alerts)
* **Enrichment:** **GeoIP enrichment enabled** (Logstash ➜ Elasticsearch `geo_point`)

**Status:** ████████████████████ 100%
Platform is **stable and operational** end-to-end.

* ✅ **Wazuh Dashboard is up** and reachable
* ✅ **Filebeat path fixed** (events arrive via Beats → Logstash)
* ✅ **`wazuh-alerts-*` indices** healthy in Wazuh Indexer
* ✅ **`sentinel-logs-*` indices** enriched with **GeoIP** in ELK
* ✅ **VirusTotal** enrichment working for **FIM** events
* ⚠️ TLS still uses `verification_mode: none` in some paths (to be hardened)

---

## 📊 Overall Project Status

```
Overall Progress: ████████████████░░░ 80%

- ✅ Infrastructure & SIEM: ████████████████████ 100%
- 🚧 SOC Dashboards:        █████████████░░░░░░ 70%
- 🚧 Endpoint Monitoring:   █████████████████░░ 85%
- 🚧 Attack Simulation:     ██████████░░░░░░░░░ 55%
- 🚧 Documentation:         ████████░░░░░░░░░░ 40%
```

*Dashboards bumped: GeoIP & VT unlock better visuals and triage panels.*

---

## 🛰️ New Capabilities

### 1) GeoIP Enrichment ✅ ENABLED

* **Where:** Logstash pipeline (Beats input from `wazuh-manager`)
* **DB:** MaxMind **GeoLite2-City.mmdb** mounted at `/usr/share/logstash/geoip/`
* **Index Template:** `sentinel-logs` enforces `geoip.location` as **`geo_point`**
* **Verified with:** test event (`8.8.8.8`) resolved to `{lat:37.751, lon:-97.822}`

**Quick checks**

```bash
# Mapping shows geo_point
curl -s 'http://localhost:9200/sentinel-logs-*/_mapping' \
| jq 'to_entries[] | {index:.key, geo_type:.value.mappings.properties.geoip.properties.location.type}'

# Last GeoIP’d document
curl -s 'http://localhost:9200/sentinel-logs-*/_search' -H 'Content-Type: application/json' -d '{
  "size": 1, "query": {"exists": {"field": "geoip.location"}},
  "sort": [{"@timestamp": {"order": "desc"}}]
}' | jq '.hits.hits[0]._source | {ts:.["@timestamp"], ip:.event_src_ip, geo:.geoip}'
```

### 2) VirusTotal Integration (Wazuh) ✅ ENABLED

* **Where:** `ossec.conf` `<integration name="virustotal" ...>`
* **Scope:** `group = syscheck` → runs on **FIM** (file integrity) alerts
* **Format:** `alert_format = json` (requires `alerts.json` present)
* **Effect:** Hashes from FIM alerts are looked up in VirusTotal; enrichment is logged and correlated in alerts.

**Smoke test (FIM + VT)**

```bash
# Create/modify a file in the monitored FIM dir inside wazuh-manager
docker compose exec wazuh-manager bash -lc '
echo "vt test $(date -u +%FT%TZ)" > /var/ossec/data/fimtest/vt-test.txt;
/var/ossec/bin/syscheck_control -u   # ask syscheck to rescan
sleep 10;
tail -n 50 /var/ossec/logs/alerts/alerts.json | jq -r "select(.rule.groups[]?==\"syscheck\") | {ts:.timestamp, file:.syscheck.path, sha256:.syscheck.sha256, rule:.rule.id, virustotal:.virustotal}"'

# Optional: check integration log for VT hits
docker compose exec wazuh-manager bash -lc 'tail -n 100 /var/ossec/logs/integrations.log'
```

> **Note:** VT free API has rate limits—plan caching/backoff and consider AbuseIPDB as a complementary source.

---

## 🎯 Next Steps – Immediate Priorities

1. **Scale Endpoints & Agents (Phase 5)**

   * Enroll Windows endpoints with **Sysmon** (SwiftOnSecurity baseline tuned for Wazuh)
   * One-command enrollment script; define agent groups and baselines

2. **Finish SOC Dashboards (Phase 4)**

   * Add **Geo maps** (ECS `geoip.location`) and **VT verdict widgets**
   * Build ATT\&CK board, auth timelines, endpoint health, triage views

3. **Validate & Tune Detection (Phase 6)**

   * Run scenario pack; compare expected vs. actual alerts; tune rules/decoders

4. **Hardening & Reproducibility**

   * Replace `verification_mode: none` with CA-based TLS (Filebeat ↔ Indexer, Beats ↔ Logstash)
   * Pin image tags; commit `filebeat.yml`; add bootstrap & verify scripts

---

## 🚧 Implementation Phases – Updated Notes

### **Phase 4: SOC Dashboards & Visualizations** 🎯 — **70%**

* **GeoIP** maps and VT panels now unblocked
* Ship starter pack (saved searches, index patterns, Wazuh app views)

### **Phase 5: Endpoint Monitoring & Sysmon** 🎯 — **85%**

* Base pipeline + custom Wazuh rules in place; scale agents next

### **Phase 6: Attack Simulation Engine** 🎯 — **55%**

* Scenarios scripted; proceed with validation leveraging new enrichment

### **Phase 7: SOC Ops & Docs** 🎯 — **40%**

* Playbooks + troubleshooting growing (add VT & GeoIP runbooks)

---

## 👥 Team Responsibility Matrix (unchanged focus)

| Phase | Owner           | Focus                            | Dependencies                       |
| ----: | --------------- | -------------------------------- | ---------------------------------- |
|     4 | Abimael & Kryss | Dashboards (& VT/Geo maps)       | Phase 5 baseline                   |
|     5 | Xavier          | Endpoint Monitoring & Enrichment | –                                  |
|     6 | Luis            | Attack Sims & Validation         | Phase 4 visuals + Phase 5 coverage |
|     7 | Team            | Documentation & Procedures       | Consolidates outputs of 4–6        |

---

## 🚀 Technical Architecture (concise)

### Primary Path (Production – Wazuh Stack)

```
Endpoints (Sysmon)
  → Wazuh Agent
  → Wazuh Manager
      ↳ Detection rules → Alerts (JSON)
      ↳ Integration: VirusTotal (FIM hashes)
  → Wazuh Indexer (OpenSearch)
  → Wazuh Dashboard (Ops views)
```

### Parallel ELK Path (Lab / Analytics)

```
Wazuh Manager Filebeat (Beats)
  → Logstash (GeoIP enrichment; template: sentinel-logs)
  → Elasticsearch (sentinel-logs-*)
  → Kibana (maps, triage, analytics)
```

*(The legacy `wazuh-forwarder` script has been removed; Beats is the path.)*

---

## 🧪 Rebuild & Verification (Quick Checklist)

```bash
# Bring stack up
docker compose down -v && docker compose up -d

# Wazuh Indexer & Wazuh app
curl -s http://localhost:9201      # expect OpenSearch banner
# (Log in to Wazuh Dashboard at https://localhost:8443)

# GeoIP (Logstash → ES)
curl -s 'http://localhost:9200/_cat/templates?v' | grep sentinel-logs
curl -s 'http://localhost:9200/sentinel-logs-*/_mapping' \
| jq 'to_entries[] | {index:.key, geo_type:.value.mappings.properties.geoip.properties.location.type}'

# Generate a smoke event to ELK and confirm GeoIP fields exist
# (as used in your tests with "fb-ts smoke <token>")

# VirusTotal (Wazuh)
docker compose exec wazuh-manager bash -lc '
/var/ossec/bin/syscheck_control -u; sleep 5;
tail -n 50 /var/ossec/logs/integrations.log | grep -i virustotal || true'
```

---

## 🔐 Notes & Recommendations

* **Secrets:** Move the VirusTotal API key to a Docker secret or env file (avoid hard-coding)
* **Rate limits:** Add retry/backoff and (optionally) local caching for VT hash lookups
* **Dashboards:** Build a “Threat Intel” board (hash verdicts, query counts, top risky files)
* **Geo maps:** Create Kibana map using `geoip.location` (ECS) with drill-downs to alert detail
* **Hardening:** Enforce TLS cert verification end-to-end (Beats↔Logstash/Indexer, ES/Kibana)

---

> With **VirusTotal** and **GeoIP** live, we’ve moved from “just ingesting” to **context-rich detection & triage**. Next up: scale agents, finish dashboards (geo & VT), then validate/tune detections across your attack scenarios.
