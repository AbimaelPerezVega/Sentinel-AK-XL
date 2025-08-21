# 🛡️ Sentinel AK-XL - Virtual Security Operations Center

A comprehensive Virtual SOC environment built with ELK Stack and Wazuh for security training and analysis.

## 🎯 Project Objective

Deploy a complete Security Operations Center environment for centralized monitoring, featuring professional dashboards, attack simulation scripts, and SOC procedures suitable for security analyst training.

**Core Deliverables:**
- ✅ Professional SOC dashboards with real-time monitoring
- ✅ Alert workflows and analyst playbooks
- ✅ Attack simulation scripts for training scenarios
- ✅ Complete SOC procedure guide

## 🏗️ Architecture Overview

### Core Technology Stack
- **ELK Stack 9.1.2**: Centralized logging and visualization (Memory optimized)
- **Wazuh 4.12.0**: SIEM detection engine and endpoint monitoring
- **Sysmon**: Windows endpoint monitoring and process tracking
- **Python Scripts**: Attack simulation and automation

### Data Flow Pipeline
```
Endpoints (Sysmon) → Wazuh Agents → Wazuh Manager → Logstash → Elasticsearch → Kibana Dashboards
                                        ↓
                              Detection Rules → Alerts → Analyst Triage
```

### Network Layout
- **Elasticsearch**: `172.20.0.10:9200`
- **Kibana**: `172.20.0.11:5601`
- **Logstash**: `172.20.0.12:5044`
- **Wazuh Manager**: `172.20.0.13:55000`
- **Wazuh Indexer**: `172.20.0.14:9201`

## 🚀 Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- **Memory**: 8GB RAM (6GB minimum for limited systems)
- **Storage**: 50GB+ free disk space
- **CPU**: 4+ cores recommended

### Installation Commands

#### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd sentinel-ak-xl
```

#### 2. Start ELK Stack
```bash
# Start ELK Stack components
docker compose up -d

# Or use the helper script
./start-elk.sh
```

#### 3. Start Wazuh Stack
```bash
# Start Wazuh SIEM components
docker compose -f docker-compose-wazuh.yml up -d
```

#### 4. Verify Services
```bash
# Check all running containers
docker compose ps

# Check ELK health
curl http://localhost:9200/_cluster/health

# Check Wazuh status
curl http://localhost:55000
```

### Access Points
- **Kibana SOC Dashboards**: http://localhost:5601
- **Elasticsearch API**: http://localhost:9200
- **Wazuh Manager**: http://localhost:55000
- **Wazuh Indexer**: http://localhost:9201

## 🛠️ Management Commands

### Service Control
```bash
# Start all services
docker compose up -d
docker compose -f docker-compose-wazuh.yml up -d

# Stop all services
docker compose down
docker compose -f docker-compose-wazuh.yml down

# Restart specific service
docker compose restart elasticsearch
docker compose -f docker-compose-wazuh.yml restart wazuh-manager

# View real-time logs
docker compose logs -f kibana
docker compose -f docker-compose-wazuh.yml logs -f wazuh-manager

# Check resource usage
docker stats
```

### Clean Up and Reset
```bash
# Stop and remove all containers
docker compose down -v
docker compose -f docker-compose-wazuh.yml down -v

# Clean up unused resources
docker system prune -f

# Remove all project data (⚠️ Data loss warning)
docker volume rm $(docker volume ls -q | grep sentinel)
```

## 📊 SOC Implementation Status

### ✅ Completed Components (85% Overall)
- **Infrastructure**: ████████████████████ 100%
- **ELK Stack**: ████████████████████ 100%
- **SIEM Core**: ███████████████████░ 95%

### 🚧 In Progress
- **SOC Dashboards**: ███████░░░░░░░░░░░░░ 35%
- **Endpoint Monitoring**: █████░░░░░░░░░░░░░░░ 25%
- **Attack Simulation**: ███░░░░░░░░░░░░░░░░░ 15%
- **Documentation**: ██░░░░░░░░░░░░░░░░░░ 10%

## 🎯 School Deliverables Progress

| Deliverable | Status | Implementation |
|-------------|--------|----------------|
| **SOC Dashboards** | 🚧 35% | Professional Kibana dashboards with threat monitoring |
| **Alert Workflows** | 🚧 10% | Analyst playbooks and incident response procedures |
| **Simulation Scripts** | 🚧 15% | Python-based attack scenarios (brute force, malware, port scan) |
| **SOC Procedures** | 🚧 10% | Complete operational documentation and training guides |

## 🔧 Configuration

### Memory Optimization (For Limited Resources)
Edit `.env` file for systems with 6-8GB RAM:
```bash
# Optimized for limited memory
ES_MEM=1g
KIBANA_MEM=512m
LOGSTASH_MEM=512m
WAZUH_MEM=1g
```

For systems with 12GB+ RAM:
```bash
# Performance configuration
ES_MEM=2g
KIBANA_MEM=1g
LOGSTASH_MEM=1g
WAZUH_MEM=2g
```

### Key Configuration Files
```
configs/
├── elk/
│   ├── elasticsearch/elasticsearch.yml  # ES cluster config
│   ├── kibana/kibana.yml               # Kibana dashboard config
│   └── logstash/                       # Log processing pipelines
└── wazuh/
    ├── wazuh.manager.conf             # SIEM rules and alerts
    └── rules/                         # Custom detection rules
```

## 📈 SOC Capabilities

### Current Detection Coverage
- **SIEM Rules**: 8 custom rules active
- **Attack Types**: Brute force, malware, network anomalies
- **Log Sources**: Sysmon, Windows Events, Linux logs
- **Alert Response**: <5 minutes for critical alerts

### Planned Enhancements
- **MITRE ATT&CK Mapping**: Framework-based attack categorization
- **Threat Intelligence**: Real-time IOC enrichment (VirusTotal, AbuseIPDB)
- **Geo-IP Mapping**: Location-based threat analysis
- **Automated Response**: Basic containment and notification

## 🚨 Troubleshooting

### Common Issues

**Services won't start due to memory**
```bash
# Check available memory
free -h

# Reduce memory allocation in .env
ES_MEM=512m
KIBANA_MEM=256m

# Restart with new settings
docker compose down && docker compose up -d
```

**Elasticsearch won't start**
```bash
# Check logs
docker compose logs elasticsearch

# Fix VM max map count (Linux)
sudo sysctl -w vm.max_map_count=262144

# Make persistent
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
```

**Port conflicts**
```bash
# Check what's using ports
netstat -tuln | grep -E ":(9200|5601|55000)"

# Stop conflicting services
sudo systemctl stop elasticsearch kibana
```

**Wazuh agent connection issues**
```bash
# Check Wazuh manager logs
docker compose -f docker-compose-wazuh.yml logs wazuh-manager

# Verify network connectivity
docker network ls | grep sentinel
```

### Health Checks
```bash
# Overall system status
./status-elk.sh

# Elasticsearch health
curl "http://localhost:9200/_cluster/health?pretty"

# Wazuh API health
curl "http://localhost:55000/"

# Check all container status
docker compose ps && docker compose -f docker-compose-wazuh.yml ps
```

## 🔒 Security Notes

**Development Mode**: Basic authentication enabled
**Credentials**:
- Elasticsearch: `elastic:changeme123!`
- Wazuh: `admin:SecretPassword` (change in production)

**Production Deployment**:
- Enable SSL/TLS for all communications
- Change default passwords
- Implement proper access controls
- Enable audit logging

## 📚 SOC Training Scenarios

### Attack Simulation Scripts
```bash
# Located in scenarios/ directory
scenarios/
├── basic/
│   ├── brute-force-attack.py      # SSH/RDP brute force
│   ├── malware-simulation.py      # Malware execution
│   └── port-scan.py              # Network reconnaissance
├── intermediate/
│   ├── lateral-movement.py        # Internal network movement
│   └── data-exfiltration.py      # Data theft simulation
└── advanced/
    └── apt-campaign.py           # Multi-stage attack
```

### Running Simulations
```bash
# Execute basic attack scenario
python3 scenarios/basic/brute-force-attack.py

# Monitor alerts in Kibana
# Navigate to http://localhost:5601 → Discover → Wazuh alerts
```

## 🎓 Educational Outcomes

### Technical Skills Developed
- **SIEM Configuration**: ELK Stack and Wazuh deployment
- **Log Analysis**: Security event correlation and investigation
- **Incident Response**: Alert triage and escalation procedures
- **Attack Simulation**: Understanding adversarial techniques

### Professional Competencies
- **SOC Operations**: Real-world analyst workflows
- **Threat Hunting**: Proactive security monitoring
- **Documentation**: Professional procedure writing
- **Tool Integration**: Multi-platform security orchestration

## 📝 Next Phase Implementation

### Priority Order
1. **Phase 5**: Sysmon integration and endpoint monitoring
2. **Phase 4**: SOC dashboard completion
3. **Phase 6**: Attack simulation engine
4. **Phase 7**: Documentation and procedures

### Timeline
- **Week 1**: Endpoint monitoring deployment
- **Week 2**: Dashboard development
- **Week 3**: Simulation scripts
- **Week 4**: Documentation completion

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/soc-enhancement`)
3. Test thoroughly in development environment
4. Submit pull request with documentation

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- **Issues**: Create GitHub issues for bugs or feature requests
- **Documentation**: Check `/docs` directory for detailed guides
- **Community**: Join our Discord for real-time support

---

**Sentinel AK-XL** - Building the next generation of cybersecurity professionals through hands-on SOC experience.

*Last Updated: August 2025 | Version: 2.0 | School-Aligned Deployment*