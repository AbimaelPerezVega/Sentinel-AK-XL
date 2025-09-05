# Quick Start Guide

## TL;DR - Get SOC Running in 15 Minutes

This guide gets your SOC environment running quickly. For detailed installation, see the [Full Installation Guide](./installation-guide.md).

## Prerequisites Check

```bash
# Verify Docker is installed and running
docker --version && docker compose version

# Check system resources (needs 8GB+ RAM, 20GB+ disk)
free -h && df -h

# Increase Elasticsearch memory limit
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```

## 5-Step Quick Installation

### 1. Clone and Enter Directory
```bash
git clone https://github.com/Xavier308/Sentiniel-soc.git
cd Sentiniel-soc
```

### 2. Configure Memory (Choose Your System)

**8GB RAM System:**
```bash
cat > .env << EOF
ES_MEM=1g
KIBANA_MEM=512m
LOGSTASH_MEM=512m
WAZUH_MEM=1g
COMPOSE_PROJECT_NAME=sentinel-akxl
EOF
```

**16GB+ RAM System:**
```bash
cat > .env << EOF
ES_MEM=2g
KIBANA_MEM=1g
LOGSTASH_MEM=1g
WAZUH_MEM=2g
COMPOSE_PROJECT_NAME=sentinel-akxl
EOF
```

### 3. Start All Services
```bash
# Start everything (takes 3-5 minutes)
docker compose up -d

# Monitor startup progress
docker compose logs -f --tail=50
```

### 4. Wait for Services (3-5 minutes)
```bash
# Check if Elasticsearch is ready
while ! curl -s localhost:9200/_cluster/health; do sleep 10; done

# Check if Kibana is ready  
while ! curl -s localhost:5601/api/status; do sleep 10; done

echo "✅ Services are ready!"
```

### 5. Setup Simulation Scripts
```bash
# Create test directories and copy simulation scripts
docker exec -it sentinel-wazuh-manager bash -c "
  mkdir -p /var/ossec/logs/test /var/ossec/data/fimtest &&
  chown wazuh:wazuh /var/ossec/logs/test /var/ossec/data/fimtest
"

# Copy simulation scripts
docker cp scenarios-simulator/ssh-auth/ssh-auth-simulator.sh sentinel-wazuh-manager:/usr/local/bin/ssh-auth-simulator
docker cp scenarios-simulator/network/network-activity-simulator.sh sentinel-wazuh-manager:/usr/local/bin/network-activity-simulator  
docker cp scenarios-simulator/malware-drop/malware-drop-simulator.sh sentinel-wazuh-manager:/usr/local/bin/malware-drop-simulator

# Make executable
docker exec -it sentinel-wazuh-manager chmod +x /usr/local/bin/*simulator
```

## Access Your SOC

| Service | URL | Credentials |
|---------|-----|-------------|
| **Kibana** | http://localhost:5601 | elastic:changeme123! |
| **Wazuh Dashboard** | https://localhost:443 | admin:SecretPassword |
| **Elasticsearch API** | http://localhost:9200 | elastic:changeme123! |

## Test Your Installation

### Run Quick Simulation Test
```bash
# Generate test alerts (takes 30 seconds)
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator -n 5 -v
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 3 -p single_flow -v
docker exec -it sentinel-wazuh-manager /usr/local/bin/malware-drop-simulator 3 2
```

### Verify Data Ingestion
```bash
# Check if alerts are being generated (wait 2-3 minutes after simulation)
curl -s "localhost:9200/wazuh-alerts-*/_search?size=1&sort=@timestamp:desc" | grep -o '"total":{"value":[0-9]*' | cut -d: -f3

# Check Elasticsearch indices
curl -s "localhost:9200/_cat/indices?v" | grep -E "(wazuh|sentinel)"
```

## Basic Usage

### 1. View Alerts in Kibana
1. Open http://localhost:5601
2. Login with `elastic:changeme123!`
3. Go to **Discover**
4. Select `wazuh-alerts-*` index pattern
5. Set time range to "Last 1 hour"

### 2. View Dashboards in Wazuh
1. Open https://localhost:443 (accept SSL warning)
2. Login with `admin:SecretPassword`
3. Navigate to **Security Events** → **Dashboard**

### 3. Generate More Test Data
```bash
# SSH brute force simulation
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator -p fast_brute -n 20

# Network port scan simulation
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -p portscan_fast -n 10

# Malware drop simulation  
docker exec -it sentinel-wazuh-manager /usr/local/bin/malware-drop-simulator 10 3
```

## Common Quick Fixes

### Services Won't Start
```bash
# Check Docker is running
sudo systemctl start docker

# Free up memory
docker system prune -f

# Restart with more memory
echo 'ES_MEM=512m' >> .env && docker compose restart
```

### No Data Appearing
```bash
# Restart Wazuh manager
docker compose restart wazuh-manager

# Check log processing
docker exec -it sentinel-wazuh-manager tail -f /var/ossec/logs/ossec.log
```

### Can't Access Web Interfaces
```bash
# Check ports are available
sudo netstat -tulpn | grep -E "(5601|9200|443)"

# Wait longer for services to start
sleep 60 && curl -s localhost:5601/api/status
```

### Memory Issues
```bash
# Reduce memory allocation
sed -i 's/ES_MEM=.*/ES_MEM=512m/' .env
sed -i 's/KIBANA_MEM=.*/KIBANA_MEM=256m/' .env
docker compose restart
```

## Next Steps

Once everything is running:

1. **📚 Read Documentation**:
   - [User Guide](./user-guide.md) - Daily SOC operations
   - [Analyst Playbooks](../05-analyst-playbooks/) - Incident response procedures

2. **🎯 Run Training Scenarios**:
   - SSH brute force attacks
   - Network reconnaissance  
   - Malware detection

3. **📊 Explore Dashboards**:
   - Create custom visualizations in Kibana
   - Set up alerting rules in Wazuh

4. **🔧 Customize Configuration**:
   - Add more monitored directories
   - Tune detection rules
   - Configure email notifications

## Getting Help

### Quick Health Check
```bash
# One-liner health check
docker compose ps && curl -s localhost:9200/_cluster/health && curl -s localhost:5601/api/status | grep -o '"status":"[^"]*"'
```

### View Logs for Troubleshooting
```bash
# Service logs
docker compose logs elasticsearch
docker compose logs kibana  
docker compose logs wazuh-manager

# Simulation logs
docker exec -it sentinel-wazuh-manager tail -f /var/log/*simulation*.log
```

### Reset Everything
```bash
# Complete reset (will lose all data)
docker compose down -v
docker system prune -f
docker compose up -d
```

## Resource Management

### Stop Services (Preserve Data)
```bash
docker compose stop
```

### Restart Services
```bash
docker compose start
```

### Remove Everything (Clean Slate)
```bash
docker compose down -v
docker system prune -af
```

---
**🚀 Your SOC is now ready for training and analysis!**

For production deployment, security hardening, and advanced configuration, consult the full [Installation Guide](./installation-guide.md) and [Admin Guide](./admin-guide.md).

---
**Last Updated**: September 2025  
**Version**: 1.0