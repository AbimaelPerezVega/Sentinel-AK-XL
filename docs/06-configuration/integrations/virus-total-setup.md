# Wazuh ↔ VirusTotal Integration Guide (with tests & troubleshooting)

This guide shows how to wire **VirusTotal (VT)** into **Wazuh** using the built-in *integrator* and **File Integrity Monitoring (FIM)**, then trigger both a *benign/negative* and a *malicious/positive* case reliably. Commands are written for a **Docker Compose** Wazuh stack.

---

## Prerequisites

* Wazuh Manager running (e.g., container `wazuh-manager`).
* Wazuh Indexer (OpenSearch/Elasticsearch) reachable from its container.
* A **VirusTotal API key** (free is fine, but note: **4 req/min & 500/day**).
* Shell on the Docker host.

> Paths below are **inside** the `wazuh-manager` container.

---

## 1) Enable FIM and VirusTotal in `ossec.conf`

Edit the Wazuh Manager configuration that is mounted into the container (adjust the path on your host if different):

```bash
sudo nano configs/wazuh/ossec.conf
```

Add (or adapt) these blocks:

```xml
<ossec_config>
  <!-- ...existing config... -->

  <!-- Collect a local test log (optional; not required for VT) -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/ossec/logs/test/sshd.log</location>
  </localfile>

  <!-- VirusTotal integration: triggers on FIM (syscheck) alerts -->
  <integration>
    <name>virustotal</name>
    <api_key>REPLACE_WITH_YOUR_VT_API_KEY</api_key>
    <group>syscheck</group>        <!-- Use FIM alerts as source -->
    <alert_format>json</alert_format>
  </integration>

  <!-- File Integrity Monitoring (FIM) -->
  <syscheck>
    <disabled>no</disabled>
    <scan_on_start>yes</scan_on_start>         <!-- Start with a scan -->
    <frequency>3600</frequency>                <!-- 1h scheduled scans -->
    <directories check_all="yes" realtime="yes">/var/ossec/data/fimtest</directories>
  </syscheck>
</ossec_config>
```

**Notes**

* `check_all="yes"` ensures hashes (`md5/sha1/sha256`) are generated so VT can query by hash.
* `realtime="yes"` gives immediate alerts on changes.
* Avoid non-existent tags like `<run_on_start>` or `<hashes>`.

---

## 2) Restart the Wazuh Manager

```bash
docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-control restart
```

Verify FIM started and is monitoring your directory:

```bash
docker compose exec -T wazuh-manager sh -lc \
'grep -Ei "syscheckd.*(/var/ossec/data/fimtest|realtime|directory|started|monitor)" /var/ossec/logs/ossec.log | tail -n 20'
```

You should see lines similar to:

* `Monitoring path: '/var/ossec/data/fimtest' ... hash_md5 | hash_sha1 | hash_sha256 | realtime`
* `Directory set for real time monitoring`
* `Real-time file integrity monitoring started`

Create the monitored directory and a writable test file, owned by `wazuh`:

```bash
docker compose exec -T wazuh-manager sh -lc \
'install -d -o wazuh -g wazuh /var/ossec/data/fimtest && \
 printf "hello\n" > /var/ossec/data/fimtest/seed.txt && \
 chown wazuh:wazuh /var/ossec/data/fimtest/seed.txt'
```

---

## 3) Negative case (benign / “No records in VirusTotal”)

Create/modify a file with random content (very unlikely to exist in VT):

```bash
docker compose exec -T wazuh-manager sh -lc \
'printf "hola %s\n" "$(date +%s%N)" > /var/ossec/data/fimtest/suspicious-file.txt && \
 chown wazuh:wazuh /var/ossec/data/fimtest/suspicious-file.txt'
```

Check syscheck alerts were produced:

```bash
docker compose exec -T wazuh-manager sh -lc \
'grep -c "\"location\":\"syscheck\"" /var/ossec/logs/alerts/alerts.json'
```

Query Wazuh Indexer for VT results (rule **87103** = “No records in VirusTotal database”):

```bash
docker compose exec -T wazuh-indexer sh -lc \
"curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:87103&size=5&pretty'"
```

You should see a document with:

* `location: "virustotal"`
* `data.virustotal.found: "0"`
* `rule.description: "VirusTotal: Alert - No records in VirusTotal database"`

---

## 4) Positive case (malicious / EICAR test file)

Use **EICAR** (safe test string recognized by AV engines). Use `printf "%s"` with proper escaping so the shell won’t misinterpret characters:

```bash
docker compose exec -T wazuh-manager sh -lc \
'printf "%s" "X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*" \
 > /var/ossec/data/fimtest/eicar.com && \
 chown wazuh:wazuh /var/ossec/data/fimtest/eicar.com'
```

Search Indexer for VT “malicious” detections (rule **87105**):

```bash
docker compose exec -T wazuh-indexer sh -lc \
"curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:87105&size=5&pretty'"
```

You should see:

* `rule.description: "VirusTotal: Alert - /var/ossec/data/fimtest/eicar.com - XX engines detected this file"`
* `data.virustotal.malicious: "1"`
* `data.virustotal.positives`, `total`, `sha1`, and a `permalink` to VT.

---

## 5) Useful queries & log locations

**Inside `wazuh-manager`:**

* Wazuh manager log:
  `/var/ossec/logs/ossec.log`
* JSON alerts (what Indexer ingests):
  `/var/ossec/logs/alerts/alerts.json`
* Integration log (VT wrapper output):
  `/var/ossec/logs/integrations.log`

**VT-related searches (in Indexer container):**

* All VT events:

  ```bash
  docker compose exec -T wazuh-indexer sh -lc \
  "curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=virustotal&size=10&pretty'"
  ```

* VT errors: **87101** (rate limit), **87102** (credentials):

  ```bash
  docker compose exec -T wazuh-indexer sh -lc \
  "curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:(87101%20OR%2087102)&size=10&pretty'"
  ```

* Latest positive detections:

  ```bash
  docker compose exec -T wazuh-indexer sh -lc \
  "curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:87105&sort=@timestamp:desc&size=10&pretty'"
  ```

---

## 6) Troubleshooting

### A. VT integration says “Exception” / no VT alerts

* Confirm config block exists **once** and is valid:

  ```xml
  <integration>
    <name>virustotal</name>
    <api_key>YOUR_KEY</api_key>
    <group>syscheck</group>
    <alert_format>json</alert_format>
  </integration>
  ```
* Restart manager and check for “Enabling integration for: 'virustotal'”:

  ```bash
  docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-control restart
  docker compose exec -T wazuh-manager sh -lc "grep -i virustotal /var/ossec/logs/ossec.log | tail -n 20"
  ```
* Ensure **syscheck alerts exist** and include hashes:

  ```bash
  docker compose exec -T wazuh-manager sh -lc \
  'grep -F "\"location\":\"syscheck\"" /var/ossec/logs/alerts/alerts.json | tail -n 3'
  ```

  If `0`, see **B**.

### B. “File integrity monitoring disabled” / no syscheck alerts

* Verify syscheck block and that the directory exists:

  ```bash
  docker compose exec -T wazuh-manager sh -lc \
  'install -d -o wazuh -g wazuh /var/ossec/data/fimtest'
  ```
* Check `ossec.log` after restart for real-time lines (shown in §2).
* Make a change to a file in the monitored path (owned/readable by `wazuh`) to trigger an alert.

### C. `integrations.log` shows `# Error: Wrong arguments`

* This appears if the VT wrapper is invoked **without arguments** (e.g., you ran it manually). It’s harmless if VT alerts are showing up in Indexer.
* To clear the file:

  ```bash
  docker compose exec -T wazuh-manager sh -lc '> /var/ossec/logs/integrations.log'
  ```

### D. VT Rate Limits / Credentials

* **87101**: “Public API request rate limit reached” → you’re over **4 req/min**. Reduce volume or upgrade VT.
* **87102**: “Error: Check credentials” → wrong API key.
* Query quickly:

  ```bash
  docker compose exec -T wazuh-indexer sh -lc \
  "curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:(87101%20OR%2087102)&size=10&pretty'"
  ```

### E. Lots of Warnings about `audit-keys` / `if_sid`

* Harmless if you’re not using auditd rules. They won’t affect VT/FIM. You can ignore them or prune those rules later.

### F. No VT alerts, but syscheck alerts exist

* Ensure `alert_format` is `json` in the **integration** block.
* Ensure `group` is `syscheck` (VT integration reacts to FIM alerts).
* Confirm the change actually includes a **hash** (use `check_all="yes"` on the directory).

---

## 7) Quick Command Reference

```bash
# Restart Wazuh Manager
docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-control restart

# Verify FIM is running and in realtime
docker compose exec -T wazuh-manager sh -lc \
'grep -Ei "syscheckd.*(/var/ossec/data/fimtest|realtime|monitor)" /var/ossec/logs/ossec.log | tail -n 20'

# Create test directory/file with wazuh ownership
docker compose exec -T wazuh-manager sh -lc \
'install -d -o wazuh -g wazuh /var/ossec/data/fimtest && \
 printf "hello\n" > /var/ossec/data/fimtest/seed.txt && \
 chown wazuh:wazuh /var/ossec/data/fimtest/seed.txt'

# Negative trigger (unlikely in VT)
docker compose exec -T wazuh-manager sh -lc \
'printf "hola %s\n" "$(date +%s%N)" > /var/ossec/data/fimtest/suspicious-file.txt && \
 chown wazuh:wazuh /var/ossec/data/fimtest/suspicious-file.txt'

# Positive trigger (EICAR)
docker compose exec -T wazuh-manager sh -lc \
'printf "%s" "X5O!P%@AP[4\\PZX54(P^)7CC)7}\$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!\$H+H*" \
 > /var/ossec/data/fimtest/eicar.com && \
 chown wazuh:wazuh /var/ossec/data/fimtest/eicar.com'

# Count syscheck alerts in alerts.json
docker compose exec -T wazuh-manager sh -lc \
'grep -c "\"location\":\"syscheck\"" /var/ossec/logs/alerts/alerts.json'

# Search VT "No records" (87103)
docker compose exec -T wazuh-indexer sh -lc \
"curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:87103&size=5&pretty'"

# Search VT "Malicious" (87105)
docker compose exec -T wazuh-indexer sh -lc \
"curl -sk -u admin:admin 'https://localhost:9200/wazuh-alerts-*/_search?q=rule.id:87105&size=5&pretty'"
```

---

## 8) Best practices

* **Scope FIM** to directories where untrusted files may appear to conserve VT quota.
* Consider adding filters (extensions, size) before calling VT to avoid waste.
* For production use, consider **VT Private API** to remove rate-limit constraints.

---

That’s it—VT is now enriching your Wazuh FIM alerts, and you’ve got reliable commands to trigger and validate both paths.
