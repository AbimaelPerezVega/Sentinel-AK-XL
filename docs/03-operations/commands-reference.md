# 🚀 Useful Commands for SOC Project

This document organizes essential Docker and Elasticsearch/Kibana commands used in the project.  
It covers container lifecycle, log management, troubleshooting, Filebeat/Wazuh tests, and Elasticsearch index template operations.

---

## 🔹 Network Management

Remove unused/stray networks (if you encounter random IP issues):
```bash
docker network prune
````

---

## 🔹 Start / Stop the Stack

Start the ELK + Wazuh stack:

```bash
./start-elk.sh
# or
docker compose up -d
```

Stop and remove containers, networks, and volumes:

```bash
docker compose down -v
```

Start only the Wazuh stack:

```bash
docker compose -f docker-compose-wazuh.yml up -d
```

Stop the Wazuh stack:

```bash
docker compose -f docker-compose-wazuh.yml down
```

---

## 🔹 Container Lifecycle & Restart

Restart a specific service:

```bash
docker compose restart sentinel-elasticsearch
docker compose restart sentinel-logstash
docker compose restart sentinel-kibana
docker compose restart sentinel-wazuh-indexer
docker compose restart sentinel-wazuh-manager
docker compose restart sentinel-wazuh-dashboard
docker compose restart sentinel-filebeat
```

Reload configs inside containers:

* **Wazuh Manager** (after editing `ossec.conf` / rules):

  ```bash
  docker exec -it sentinel-wazuh-manager /var/ossec/bin/wazuh-control restart
  ```
* **Logstash** (after editing pipelines):

  ```bash
  docker compose restart sentinel-logstash
  ```
* **Filebeat** (after editing `filebeat.yml`):

  ```bash
  docker compose restart sentinel-filebeat
  ```

---

## 🔹 Images & Containers

List installed images:

```bash
docker images | grep -E 'elasticsearch|kibana|logstash|wazuh|filebeat'
```

Check container status:

```bash
docker compose ps
docker compose ps -a
```

---

## 🔹 Logs Management

View logs:

```bash
docker compose logs wazuh-manager
docker compose logs --tail=50 wazuh-manager
```

Save logs to file:

```bash
docker compose logs wazuh-manager > logs.txt
```

---

## 🔹 Troubleshooting Wazuh Manager

If you encounter a `start-script-lock` issue:

```bash
docker compose exec wazuh-manager bash -lc 'rm -rf /var/ossec/var/start-script-lock || true'
```

---

## 🔹 Health Checks

Cluster health:

```bash
curl -s localhost:9200/_cluster/health | jq
```

Logstash pipelines:

```bash
curl -s localhost:9600/_node/pipelines | jq '.pipelines'
```

Count logs in index:

```bash
curl -s "http://localhost:9200/sentinel-logs-*/_count"
```

---

## 🔹 Filebeat & Alerts

Check Filebeat in Wazuh Manager logs:

```bash
docker logs -f --tail=200 sentinel-wazuh-manager | grep -i filebeat
```

Is Filebeat running?

```bash
docker compose exec -T wazuh-manager sh -lc 'pgrep -a filebeat || echo "filebeat NOT running"'
```

Check if `alerts.json` is being generated:

```bash
docker compose exec -T wazuh-manager ls -l /var/ossec/logs/alerts
docker compose exec -T wazuh-manager tail -n 2 /var/ossec/logs/alerts/alerts.json
```

Test Filebeat output:

```bash
docker compose exec -T wazuh-manager /usr/bin/filebeat test output
```

---

## 🔹 Manual Log Injection for Testing

Create test log directory and file:

```bash
docker compose exec -T wazuh-manager sh -lc '
  install -d -o wazuh -g wazuh /var/ossec/logs/test &&
  install -m 660 -o wazuh -g wazuh /dev/null /var/ossec/logs/test/sshd.log
'
```

Generate a fake SSH failure:

```bash
docker compose exec -T wazuh-manager sh -lc '
  echo "<13>Aug 28 10:00:00 test sshd[1234]: Failed password for root from 1.2.3.4 port 22" >> /var/ossec/logs/test/sshd.log
'
```

Check alerts:

```bash
docker compose exec -T wazuh-manager sh -lc 'tail -n 3 /var/ossec/logs/alerts/alerts.json'
```

---

## 🔹 Elasticsearch Index Templates

List all templates:

```bash
curl -s 'http://localhost:9200/_index_template?pretty'
```

List in “cat” format:

```bash
curl -s 'http://localhost:9200/_cat/templates?v'
curl -s 'http://localhost:9200/_cat/templates/sentinel-logs*?v'
```

View a specific template:

```bash
curl -s 'http://localhost:9200/_index_template/sentinel-logs?pretty'
```

Delete a template:

```bash
curl -s -XDELETE 'http://localhost:9200/_index_template/sentinel-logs'
```

Recreate/update template:

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

Simulate which template applies to an index:

```bash
curl -s 'http://localhost:9200/_index_template/_simulate_index/sentinel-logs-2099.01.01?pretty'
```

Export template to file:

```bash
curl -s 'http://localhost:9200/_index_template/sentinel-logs' | jq '.' > sentinel-logs-template.json
```

---

## 🔹 Kibana UI for Templates

In Kibana:
**Stack Management → Index Management → Index Templates**
Here you can view, edit, and simulate templates directly.

---

✅ With these commands you can manage your SOC stack lifecycle, debug issues, inject test logs, and maintain Elasticsearch templates effectively.

```

