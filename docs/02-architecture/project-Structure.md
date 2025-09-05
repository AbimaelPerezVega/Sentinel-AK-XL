# 🛡️ Sentinel AK-XL Project Structure Overview

```bash
.
├── README.md                           # Main project documentation and setup guide
├── VERSION                             # Current project version tracking
├── config.yml                          # Global project configuration settings
├── configs/                            # Core configuration directory
│   ├── elk/                            # ELK Stack configurations
│   │   ├── elasticsearch/              
│   │   │   ├── elasticsearch.yml       # Elasticsearch cluster settings and memory optimization
│   │   │   ├── jvm.options            # Java Virtual Machine tuning for performance
│   │   │   └── templates/
│   │   │       └── wazuh-template.json # Index template for Wazuh alert mapping
│   │   ├── filebeat/
│   │   │   └── filebeat.yml           # Log shipping configuration (Wazuh → ELK)
│   │   ├── kibana/
│   │   │   ├── dashboards/            # SOC visualization configurations
│   │   │   └── kibana.yml             # Kibana web interface settings
│   │   └── logstash/
│   │       ├── conf.d/
│   │       │   └── main.conf          # Log processing pipeline with GeoIP enrichment
│   │       ├── logstash.yml           # Logstash service configuration
│   │       ├── pipelines.yml          # Pipeline orchestration settings
│   │       └── templates/
│   │           └── wazuh-template.json # Elasticsearch mapping for enriched logs
│   └── wazuh/                         # SIEM detection engine configurations
│       ├── agents/                    # Endpoint agent configurations
│       ├── dashboard/
│       │   ├── opensearch_dashboards.yml # Wazuh dashboard interface settings
│       │   └── wazuh.yml              # Wazuh app configuration
│       ├── decoders/
│       │   └── local_decoder.xml      # Custom log parsing rules
│       ├── generated/
│       │   └── ossec.conf             # Auto-generated Wazuh manager configuration
│       ├── geoip/
│       │   └── GeoLite2-City.mmdb     # Geographic IP location database
│       ├── indexer/
│       │   ├── internal_users.yml     # Wazuh indexer user management
│       │   └── wazuh.indexer.yml      # OpenSearch backend configuration
│       ├── manager/
│       │   ├── filebeat.yml           # Wazuh manager log shipping
│       │   └── wazuh_manager.conf     # Core SIEM detection settings
│       ├── ossec.conf.tpl             # Wazuh configuration template
│       ├── rules/
│       │   └── local_rules.xml        # Custom detection rules for SOC scenarios
│       └── ssl_certs/
│           └── root-ca.pem            # SSL/TLS certificates for secure communication
├── docker-compose.yml                 # ELK Stack container orchestration
├── scenarios-simulator/               # Attack simulation toolkit for SOC training
│   ├── README.md                      # Simulation scenarios documentation
│   ├── malware-drop/
│   │   └── malware-drop-simulator.sh  # File integrity monitoring and VirusTotal triggers
│   ├── network/
│   │   └── network-activity-simulator.sh # Port scanning and network anomaly generation
│   └── ssh-auth/
│       └── ssh-auth-simulator.sh      # SSH brute force and authentication attack simulation
└── wazuh-certs-tool.sh               # SSL certificate generation utility for Wazuh stack
```
### Command
```
tree -L 5 -I "logs|data|docs|backup|test|scripts|sysmon|wazuh-certificates|wazuh-indexer|kibana_dashboards" 
```

## 🔧 Key Components Explained

### **Core Infrastructure**
- **`docker-compose.yml`**: Orchestrates ELK Stack containers with optimized memory settings
- **`configs/elk/`**: Contains all Elasticsearch, Logstash, Kibana configurations for centralized logging
- **`configs/wazuh/`**: SIEM detection engine with custom rules and threat intelligence integration

### **Security Operations Center (SOC)**
- **`configs/wazuh/rules/local_rules.xml`**: Custom detection rules for brute force, malware, network anomalies
- **`configs/logstash/conf.d/main.conf`**: Log enrichment pipeline with GeoIP and threat intelligence
- **`configs/kibana/dashboards/`**: Professional SOC visualization dashboards

### **Attack Simulation & Training**
- **`scenarios-simulator/`**: Realistic attack scenarios for SOC analyst training
- **`ssh-auth-simulator.sh`**: Generates authentication attacks with geographic distribution
- **`malware-drop-simulator.sh`**: Triggers file integrity monitoring and VirusTotal integration
- **`network-activity-simulator.sh`**: Simulates port scans and suspicious network behavior

### **Security & Hardening**
- **`configs/wazuh/ssl_certs/`**: Production-grade SSL/TLS certificates
- **`wazuh-certs-tool.sh`**: Automated certificate generation and deployment
- **`configs/wazuh/geoip/`**: Geographic threat intelligence database for IP location tracking