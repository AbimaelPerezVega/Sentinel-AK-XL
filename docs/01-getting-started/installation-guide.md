# Installation Guide

## Overview

This guide provides step-by-step instructions for installing and configuring the Sentinel AK-XL Virtual SOC environment.

## Prerequisites

Before starting the installation, ensure your system meets the requirements outlined in [System Requirements](./system-requirements.md).

### Required Software
- **Docker Engine**: 20.10+
- **Docker Compose**: 2.0+
- **Git**: For cloning the repository
- **Linux/WSL2**: Recommended operating system

### System Verification
```bash
# Check Docker installation
docker --version
docker compose version

# Verify system resources
free -h
df -h
```

## Installation Steps

### 1. Clone Repository
```bash
git clone https://github.com/AbimaelPerezVega/Sentinel-AK-XL.git
cd Sentiniel-soc
```

### 2. Environment Configuration

#### Set Memory Limits
Create or modify `.env` file based on your system:

**For 8GB RAM systems:**
```env
ES_MEM=1g
KIBANA_MEM=512m
LOGSTASH_MEM=512m
WAZUH_MEM=1g
COMPOSE_PROJECT_NAME=sentinel-akxl
```

**For 16GB+ RAM systems:**
```env
ES_MEM=4g
KIBANA_MEM=1g
LOGSTASH_MEM=2g
WAZUH_MEM=3g
COMPOSE_PROJECT_NAME=sentinel-akxl
```

#### Configure System Limits
```bash
# Increase max map count for Elasticsearch
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# For WSL2 users, add to ~/.wslconfig
[wsl2]
memory=8GB
processors=4
```

### 3. Start Services

#### Option A: Quick Start (Recommended)
```bash
# Start all services with automatic setup
docker compose up -d

# Monitor startup process
docker compose logs -f
```

#### Option B: Step-by-Step Start
```bash
# Start Elasticsearch first
docker compose up -d elasticsearch
sleep 30

# Start Kibana
docker compose up -d kibana
sleep 20

# Start remaining ELK services
docker compose up -d logstash

# Start Wazuh stack
docker compose up -d wazuh-manager wazuh-indexer wazuh-dashboard
```

### 4. Verify Installation

#### Check Service Status
```bash
# View all running containers
docker compose ps

# Check service health
curl -X GET "localhost:9200/_cluster/health?pretty"
curl -X GET "localhost:5601/api/status"
```

Expected output should show all services as "running" and health checks returning successful responses.

#### Access Web Interfaces
- **Kibana**: http://localhost:5601
- **Wazuh Dashboard**: https://localhost:443
- **Elasticsearch API**: http://localhost:9200

#### Default Credentials
- **Elasticsearch**: `elastic:changeme123!`
- **Wazuh**: `admin:SecretPassword`

### 5. Initial Configuration

#### Create Test Directories
```bash
# Create directories for simulation scripts
docker exec -it sentinel-wazuh-manager bash -c "
  mkdir -p /var/ossec/logs/test /var/ossec/data/fimtest &&
  chown wazuh:wazuh /var/ossec/logs/test /var/ossec/data/fimtest &&
  : > /var/ossec/logs/test/sshd.log &&
  : > /var/ossec/logs/test/network.log
"
```

#### Copy Simulation Scripts
```bash
# Copy SSH authentication simulator
docker cp scenarios-simulator/ssh-auth/ssh-auth-simulator.sh sentinel-wazuh-manager:/usr/local/bin/ssh-auth-simulator

# Copy network activity simulator
docker cp scenarios-simulator/network/network-activity-simulator.sh sentinel-wazuh-manager:/usr/local/bin/network-activity-simulator

# Copy malware drop simulator
docker cp scenarios-simulator/malware-drop/malware-drop-simulator.sh sentinel-wazuh-manager:/usr/local/bin/malware-drop-simulator

# Make scripts executable
docker exec -it sentinel-wazuh-manager bash -c "
  chmod +x /usr/local/bin/ssh-auth-simulator &&
  chmod +x /usr/local/bin/network-activity-simulator &&
  chmod +x /usr/local/bin/malware-drop-simulator
"
```

### 6. SSL Certificate Setup (Optional)

#### Generate Wazuh Certificates
```bash
# Run certificate generation tool
./wazuh-certs-tool.sh

# Apply certificates to containers
docker compose restart wazuh-manager wazuh-indexer wazuh-dashboard
```

### 7. Import Dashboards and Visualizations

#### Kibana Dashboard Setup
```bash
# Wait for Kibana to be fully ready
sleep 60

# Import saved objects (if available)
curl -X POST "localhost:5601/api/saved_objects/_import" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  --form file=@kibana-dashboards.ndjson
```

#### Create Index Patterns
```bash
# Create Wazuh alerts index pattern
curl -X POST "localhost:5601/api/saved_objects/index-pattern/wazuh-alerts-*" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": {
      "title": "wazuh-alerts-*",
      "timeFieldName": "@timestamp"
    }
  }'

# Create Sentinel logs index pattern
curl -X POST "localhost:5601/api/saved_objects/index-pattern/sentinel-logs-*" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -d '{
    "attributes": {
      "title": "sentinel-logs-*",
      "timeFieldName": "@timestamp"
    }
  }'
```

### 8. Test Installation

#### Run Test Simulations
```bash
# Test SSH authentication simulation
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator -n 10 -v

# Test network activity simulation
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 5 -p single_flow -v

# Test malware drop simulation
docker exec -it sentinel-wazuh-manager /usr/local/bin/malware-drop-simulator 5 3
```

#### Verify Data Ingestion
```bash
# Check Elasticsearch indices
curl -X GET "localhost:9200/_cat/indices?v"

# Check for recent alerts
curl -X GET "localhost:9200/wazuh-alerts-*/_search?q=*&size=1&sort=@timestamp:desc&pretty"
```

## Troubleshooting Common Issues

### Docker Issues

#### Insufficient Memory
**Symptom**: Elasticsearch fails to start
**Solution**:
```bash
# Reduce memory allocation
echo 'ES_MEM=1g' >> .env
docker compose restart elasticsearch
```

#### Port Conflicts
**Symptom**: "Port already in use" errors
**Solution**:
```bash
# Find conflicting processes
sudo netstat -tulpn | grep :5601
sudo lsof -i :5601

# Stop conflicting services
sudo systemctl stop conflicting-service
```

#### Permission Issues
**Symptom**: Container access denied errors
**Solution**:
```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker

# Fix file permissions
sudo chown -R $USER:$USER .
```

### Service Health Issues

#### Elasticsearch Cluster Red
**Symptom**: Cluster health shows red status
**Solution**:
```bash
# Check cluster status
curl -X GET "localhost:9200/_cluster/health?pretty"

# Reset cluster if needed
curl -X DELETE "localhost:9200/_all"
docker compose restart elasticsearch
```

#### Kibana Connection Issues
**Symptom**: Kibana cannot connect to Elasticsearch
**Solution**:
```bash
# Verify Elasticsearch is running
curl -X GET "localhost:9200"

# Check Kibana logs
docker compose logs kibana

# Restart Kibana
docker compose restart kibana
```

#### Wazuh Agent Issues
**Symptom**: No data appearing in Wazuh
**Solution**:
```bash
# Check Wazuh manager status
docker exec -it sentinel-wazuh-manager /var/ossec/bin/wazuh-control status

# Restart Wazuh services
docker exec -it sentinel-wazuh-manager /var/ossec/bin/wazuh-control restart
```

### Performance Issues

#### Slow Query Performance
**Solution**:
```bash
# Increase heap size
echo 'ES_MEM=2g' >> .env
docker compose restart elasticsearch

# Clear cache
curl -X POST "localhost:9200/_cache/clear"
```

#### High Memory Usage
**Solution**:
```bash
# Monitor container resources
docker stats

# Adjust memory limits in .env file
# Restart services with new limits
```

## Post-Installation Tasks

### Security Hardening

#### Change Default Passwords
```bash
# Change Elasticsearch password
curl -X POST "localhost:9200/_security/user/elastic/_password" \
  -H "Content-Type: application/json" \
  -d '{"password": "new_secure_password"}'

# Update .env file with new password
```

#### Enable HTTPS
```bash
# Configure SSL certificates
# Update docker-compose.yml with SSL settings
# Restart services
```

### Backup Configuration
```bash
# Backup configuration files
tar -czf sentinel-backup-$(date +%Y%m%d).tar.gz \
  configs/ .env docker-compose.yml

# Store backup in safe location
```

### Monitoring Setup
```bash
# Set up log rotation
sudo logrotate -d /etc/logrotate.d/docker-containers

# Configure system monitoring
# Set up disk space alerts
# Configure service monitoring
```

## Next Steps

After successful installation:

1. **Read the [User Guide](./user-guide.md)** for daily operations
2. **Review [Admin Guide](./admin-guide.md)** for system management
3. **Study the [Analyst Playbooks](../05-analyst-playbooks/)** for incident response
4. **Run simulation scenarios** to test the system
5. **Customize dashboards** for your environment

## Getting Help

### Log Locations
```bash
# Docker compose logs
docker compose logs [service_name]

# Container logs
docker logs [container_name]

# Wazuh logs
docker exec -it sentinel-wazuh-manager tail -f /var/ossec/logs/ossec.log

# Simulation logs
docker exec -it sentinel-wazuh-manager tail -f /var/log/ssh-auth-simulation.log
```

### Health Check Commands
```bash
# Quick health check script
./scripts/health-check.sh

# Manual service verification
curl -s -o /dev/null -w "%{http_code}" http://localhost:5601/api/status
curl -s -o /dev/null -w "%{http_code}" http://localhost:9200/_cluster/health
```

### Community Support
- **GitHub Issues**: Report bugs and feature requests
- **Documentation**: Check the docs/ directory for detailed guides
- **SOC Team**: Contact internal SOC team for operational issues

---
**Last Updated**: September 2025  
**Version**: 1.0