# ⚡ SOC Project Commands

This document contains all useful commands to manage the ELK + Wazuh stack.  
It is divided into a **Quick Start Cheatsheet** for everyday use and **Advanced Commands** for deeper troubleshooting and configuration.

---

## 🔹 Quick Start Cheatsheet

### Start / Stop Stack
```bash
# Start the full stack
docker compose up -d

# Stop and remove containers, networks, and volumes
docker compose down -v
````

### Logs

```bash
# View Wazuh Manager logs
docker compose logs --tail=50 wazuh-manager
```

### Status

```bash
# Check running containers
docker compose ps
```

---

## 🔹 Advanced Commands

### Network Management

```bash
# Remove unused/stray networks
docker network prune
```

---

### Container Lifecycle & Restart

```bash
# Restart specific services
docker compose restart sentinel-elasticsearch
docker compose restart sentinel-logstash
docker compose restart sentinel-kibana
docker compose restart sentinel-wazuh-indexer
docker compose restart sentinel-wazuh-manager
docker compose restart sentinel-wazuh-dashboard
docker compose restart sentinel-filebeat

# Reload Wazuh Manager after config changes
docker exec -it sentinel-wazuh-manager /var/ossec/bin/wazuh-control restart
```

---

### Images & Containers

```bash
# List installed images
docker images | grep -E 'elasticsearch|kibana|logstash|wazuh|filebeat'

# Check containers
docker compose ps -a
```

---

### Logs Management

```bash
# Save Wazuh Manager logs to a file
docker compose logs wazuh-manager > logs.txt
```

---

### Troubleshooting Wazuh Manager

```bash
# Fix start-script-lock issue
docker compose exec wazuh-manager bash -lc 'rm -rf /var/ossec/var/start-script-lock || true'
```

---

### Health Checks

```bash
# Check Elasticsearch cluster health
curl -s localhost:9200/_cluster/health | jq

# List Logstash pipelines
curl -s localhost:9600/_node/pipelines | jq '.pipelines'

# Count docs in sentinel logs
curl -s "http://localhost:9200/sentinel-logs-*/_count"
```

---

### Filebeat & Alerts

```bash
# Tail Filebeat logs from Wazuh Manager
docker logs -f --tail=200 sentinel-wazuh-manager | grep -i filebeat

# Check if Filebeat is running
docker compose exec -T wazuh-manager sh -lc 'pgrep -a filebeat || echo "filebeat NOT running"'

# Check alerts.json existence
docker compose exec -T wazuh-manager ls -l /var/ossec/logs/alerts
docker compose exec -T wazuh-manager tail -n 2 /var/ossec/logs/alerts/alerts.json

# Test Filebeat output
docker compose exec -T wazuh-manager /usr/bin/filebeat test output
```

---

### Manual Log Injection for Testing

```bash
# Create test directory and file
docker compose exec -T wazuh-manager sh -lc '
  install -d -o wazuh -g wazuh /var/ossec/logs/test &&
  install -m 660 -o wazuh -g wazuh /dev/null /var/ossec/logs/test/sshd.log
'

# Generate fake SSH failed password log
docker compose exec -T wazuh-manager sh -lc '
  echo "<13>Aug 28 10:00:00 test sshd[1234]: Failed password for root from 1.2.3.4 port 22" >> /var/ossec/logs/test/sshd.log
'

# Verify alerts
docker compose exec -T wazuh-manager sh -lc 'tail -n 3 /var/ossec/logs/alerts/alerts.json'
```

---

### Elasticsearch Index Templates

**List templates:**

```bash
curl -s 'http://localhost:9200/_index_template?pretty'
curl -s 'http://localhost:9200/_cat/templates?v'
curl -s 'http://localhost:9200/_cat/templates/sentinel-logs*?v'
```

**View a specific template:**

```bash
curl -s 'http://localhost:9200/_index_template/sentinel-logs?pretty'
```

**Delete a template:**

```bash
curl -s -XDELETE 'http://localhost:9200/_index_template/sentinel-logs'
```

**Recreate/Update template:**

```bash
curl -s -XPUT 'http://localhost:9200/_index_template/sentinel-logs' \
  -H 'Content-Type: application/json' -d '{
    "index_patterns": ["sentinel-logs-*"],
    "template": {
      "mappings": {
        "properties": {
          "agent": {
            "properties": {
              "name": {
                "type": "text",
                "fields": { "keyword": { "type": "keyword", "ignore_above": 256 } }
              }
            }
          },
          "geoip": {
            "properties": {
              "location": { "type": "geo_point" },
              "latitude":  { "type": "float" },
              "longitude": { "type": "float" }
            }
          }
        }
      }
    }
  }'
```

**Simulate template application:**

```bash
curl -s 'http://localhost:9200/_index_template/_simulate_index/sentinel-logs-2099.01.01?pretty'
```

**Export template:**

```bash
curl -s 'http://localhost:9200/_index_template/sentinel-logs' | jq '.' > sentinel-logs-template.json
```

---

### Kibana UI for Templates

In Kibana:
**Stack Management → Index Management → Index Templates**
Here you can view, edit, and simulate templates via the UI.

---

✅ With this structure, you have a **fast reference** for daily use and a **comprehensive guide** for advanced operations.

```