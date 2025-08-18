# Troubleshooting Guide

## Quick Diagnostics

### Run Automatic Diagnostics
```bash
./status-elk.sh
```

### Manual Health Checks
```bash
# Docker status
docker ps

# Service connectivity
curl http://localhost:9200
curl http://localhost:5601/api/status

# Resource usage
docker stats --no-stream
```

## Common Issues and Solutions

### 1. Elasticsearch Issues

#### "Elasticsearch not responding"
```bash
# Check if container is running
docker ps | grep elasticsearch

# Check logs for errors
docker compose logs elasticsearch

# Common solutions:
sudo sysctl -w vm.max_map_count=262144  # Linux
docker compose restart elasticsearch
```

#### "Cluster health RED"
```bash
# Check cluster status
curl http://localhost:9200/_cluster/health?pretty

# Reset cluster
docker compose down -v
docker compose up -d
```

### 2. Kibana Issues

#### "Kibana server not ready"
```bash
# Wait for Elasticsearch first
curl http://localhost:9200/_cluster/health

# Check Kibana logs
docker compose logs kibana

# Restart Kibana
docker compose restart kibana
```

#### "Kibana authentication errors"
```bash
# Verify no authentication is configured
grep -E "username|password" configs/elk/kibana/kibana.yml

# Should be empty for development mode
```

### 3. Port Conflicts

#### "Port already in use"
```bash
# Find what's using the port
netstat -tuln | grep :9200
lsof -i :9200

# Stop system services
sudo systemctl stop elasticsearch
sudo systemctl stop kibana

# Kill processes
sudo fuser -k 9200/tcp
```

### 4. Memory Issues

#### "Container keeps restarting"
```bash
# Check memory usage
free -h
docker stats

# Reduce memory allocation in .env
ES_MEM=1g
KIBANA_MEM=512m

# Restart with new settings
docker compose down
docker compose up -d
```

### 5. Permission Issues

#### "Permission denied errors"
```bash
# Fix ownership (Linux)
sudo chown -R $(id -u):$(id -g) data/ logs/

# Set permissions
chmod -R 755 data/ logs/ configs/
```

### 6. Network Issues

#### "Services can't communicate"
```bash
# Check Docker network
docker network ls
docker network inspect sentinel-ak-xl_sentinel

# Restart networking
docker compose down
docker compose up -d
```

## Performance Optimization

### Memory Tuning
```bash
# For 4GB systems
ES_JAVA_OPTS="-Xms1g -Xmx1g"

# For 8GB systems  
ES_JAVA_OPTS="-Xms2g -Xmx2g"

# For 16GB+ systems
ES_JAVA_OPTS="-Xms4g -Xmx4g"
```

### Disk Optimization
```bash
# Check disk usage
df -h
docker system df

# Clean up unused resources
docker system prune -a
docker volume prune
```

## Recovery Procedures

### Complete Reset
```bash
# Stop everything
docker compose down -v

# Remove all data
sudo rm -rf data/ logs/

# Recreate and restart
./start-elk.sh
```

### Partial Reset
```bash
# Reset only Elasticsearch data
docker compose stop elasticsearch
docker volume rm sentinel-ak-xl_elasticsearch-data
docker compose up -d elasticsearch
```

## Getting Help

1. Check the logs: `docker compose logs [service]`
2. Run diagnostics: `./status-elk.sh`
3. Review this troubleshooting guide
4. Create an issue with logs and system info

## System Information Collection
```bash
# Collect system info for support
echo "=== System Information ===" > debug-info.txt
uname -a >> debug-info.txt
docker version >> debug-info.txt
docker compose version >> debug-info.txt
free -h >> debug-info.txt
df -h >> debug-info.txt
echo "=== Container Status ===" >> debug-info.txt
docker ps >> debug-info.txt
echo "=== Service Logs ===" >> debug-info.txt
docker compose logs --tail 50 >> debug-info.txt
```
