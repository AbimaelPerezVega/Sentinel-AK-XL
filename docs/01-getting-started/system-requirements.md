# System Requirements

## Minimum Hardware Requirements

### RAM
- **Minimum**: 8GB RAM
- **Recommended**: 12GB+ RAM for optimal performance
- **Production**: 16GB+ RAM for full-scale deployment

### Storage
- **Minimum**: 20GB free disk space
- **Recommended**: 50GB+ for logs and data retention
- **Production**: 100GB+ with SSD for better I/O performance

### CPU
- **Minimum**: 4 CPU cores
- **Recommended**: 6+ CPU cores
- **Production**: 8+ CPU cores for concurrent analysis

### Network
- **Internet Connection**: Required for threat intelligence feeds (VirusTotal, GeoIP)
- **Bandwidth**: 10Mbps+ for real-time log processing
- **Ports**: See [Port Requirements](#port-requirements) section

## Software Requirements

### Operating System
- **Linux**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **Windows**: Windows 10/11 with WSL2
- **macOS**: macOS 11+ with Docker Desktop

### Container Runtime
- **Docker Engine**: 20.10+ (required)
- **Docker Compose**: 2.0+ (required)

### Optional Tools
- **Git**: For version control and updates
- **curl/wget**: For downloading components
- **Python 3.8+**: For simulation scripts

## Port Requirements

### Core Services
| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Elasticsearch | 9200 | HTTP | API and web interface |
| Kibana | 5601 | HTTP | Web dashboard |
| Logstash | 5044 | TCP | Beats input |
| Wazuh Manager | 1514 | UDP | Agent communication |
| Wazuh Manager | 1515 | TCP | Agent enrollment |
| Wazuh Indexer | 9201 | HTTP | OpenSearch API |
| Wazuh Dashboard | 443 | HTTPS | Web interface |

### Additional Services
| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Wazuh API | 55000 | HTTP | Management API |
| Logstash Monitoring | 9600 | HTTP | Monitoring endpoint |

## Memory Configuration by System

### 8GB RAM Systems
```env
ES_MEM=1g
KIBANA_MEM=512m
LOGSTASH_MEM=512m
WAZUH_MEM=1g
```

### 12GB+ RAM Systems
```env
ES_MEM=2g
KIBANA_MEM=1g
LOGSTASH_MEM=1g
WAZUH_MEM=2g
```

### 16GB+ RAM Systems (Production)
```env
ES_MEM=4g
KIBANA_MEM=1g
LOGSTASH_MEM=2g
WAZUH_MEM=3g
```

## Supported Agent Operating Systems

### Windows
- Windows 10/11 (x64)
- Windows Server 2016/2019/2022
- **Sysmon**: Required for enhanced logging

### Linux
- Ubuntu 18.04+
- CentOS 7+
- Red Hat Enterprise Linux 7+
- Debian 9+

### Network Devices
- Syslog-compatible devices
- Firewall logs (pfSense, Fortinet, etc.)
- Switch/Router logs

## Pre-installation Checklist

- [ ] System meets minimum hardware requirements
- [ ] Docker and Docker Compose installed
- [ ] Required ports are available (not in use)
- [ ] Internet connectivity for downloads
- [ ] Administrative/sudo privileges
- [ ] Firewall configured to allow required ports
- [ ] At least 20GB free disk space
- [ ] WSL2 configured (Windows only)

## Performance Tuning Notes

### For Limited Resources (< 8GB)
1. Reduce heap sizes in configuration
2. Disable unnecessary Wazuh modules
3. Limit log retention period
4. Use basic dashboards only

### For Production Environments
1. Use dedicated hardware or VM
2. Configure log rotation and retention
3. Set up monitoring and alerting
4. Implement backup strategies
5. Use external storage for logs

## Troubleshooting Common Issues

### Docker Memory Issues
```bash
# Increase Docker memory limit (Docker Desktop)
# Settings → Resources → Memory → 8GB+
```

### Port Conflicts
```bash
# Check port usage
sudo netstat -tulpn | grep :5601
# Stop conflicting services before starting
```

### WSL2 Performance (Windows)
```bash
# Add to ~/.wslconfig
[wsl2]
memory=8GB
processors=4
```

---
**Last Updated**: September 2025  
**Version**: 1.0