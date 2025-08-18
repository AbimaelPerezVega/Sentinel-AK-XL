# Sentinel AK-XL - Quick Start

## 🚀 Simple Usage

### Test ELK Stack
```bash
# Start only Elasticsearch (fastest, no downloads)
./test-elk.sh elasticsearch

# Start Elasticsearch + Kibana
./test-elk.sh kibana

# Start full ELK stack
./test-elk.sh full

# Check status
./test-elk.sh status

# Stop everything
./test-elk.sh stop

# Clean up completely
./test-elk.sh clean
```

### Access Services
- **Elasticsearch**: http://localhost:9200 (elastic/changeme123!)
- **Kibana**: http://localhost:5601 (elastic/changeme123!)
- **Logstash**: http://localhost:9600

### Files Structure
- `test-elk.sh` - Main testing script
- `docker-compose-test.yml` - ELK configuration
- `configs/elk/` - Service configurations
- `backup/` - Old files moved here

### If Something Breaks
```bash
./test-elk.sh clean
./test-elk.sh elasticsearch  # Start simple
```
