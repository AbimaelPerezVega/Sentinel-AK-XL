# Sysmon Deployment and Endpoint Monitoring

## Overview
This implementation provides comprehensive endpoint monitoring using simulated Windows Sysmon events integrated with our existing Wazuh SIEM infrastructure.

## Architecture

```
Windows Endpoint Simulator → Wazuh Agent → Wazuh Manager → Elasticsearch → Kibana
                ↓
        Sysmon Events (Process, Network, File, Registry)
                ↓
        Detection Rules → Alerts → SOC Analysis
```

## Components Deployed

### 1. Windows Endpoint Simulator
- **Container**: `windows-endpoint-sim-01`
- **Image**: `windows-endpoint-simulator:latest`
- **Function**: Generates realistic Sysmon events
- **Events**: Process creation, network connections, file operations, registry changes

### 2. Wazuh Integration
- **Agent**: Installed in simulator container
- **Manager**: Existing Wazuh manager receives events
- **Rules**: Custom detection rules for Sysmon events (100001-100060)

### 3. Detection Capabilities
- **Process Monitoring**: Suspicious executable detection
- **Network Analysis**: Backdoor port and suspicious IP detection
- **File System**: Malicious file creation alerts
- **Persistence**: Registry modification detection
- **Attack Patterns**: Multi-event correlation

## Usage

### Start Monitoring
```bash
# Check simulator status
docker ps | grep windows-endpoint-sim

# View live events
docker logs -f windows-endpoint-sim-01

# Monitor Wazuh manager
docker exec sentinel-ak-xl-wazuh-manager-1 tail -f /var/ossec/logs/ossec.log
```

### Run Attack Scenarios
```bash
# Run specific attack scenario
./scripts/run-attack-scenarios.sh malware_execution 120

# Available scenarios:
# - brute_force
# - malware_execution  
# - lateral_movement
# - persistence
# - data_exfiltration
```

### Kibana Analysis
1. Open Kibana: http://localhost:5601
2. Go to Discover
3. Select index: `wazuh-alerts-*`
4. Use filters:
   ```
   rule.groups: "sysmon"
   agent.name: "WIN-ENDPOINT-01"
   rule.level: >7
   ```

### Key Sysmon Event IDs
- **Event ID 1**: Process Creation
- **Event ID 3**: Network Connection
- **Event ID 11**: File Created
- **Event ID 13**: Registry Value Set

### Detection Rules
- **100010**: Suspicious process execution
- **100011**: Suspicious command line
- **100020**: Backdoor port connections
- **100030**: Suspicious file creation
- **100040**: Registry persistence
- **100050-100060**: Attack pattern correlation

## Monitoring Scripts

### Health Check
```bash
./scripts/monitor-sysmon.sh
```

### Restart Simulation
```bash
./scripts/restart-sysmon.sh
```

### Attack Testing
```bash
./scripts/run-attack-scenarios.sh [scenario] [duration]
```

## Troubleshooting

### Container Issues
```bash
# Check container logs
docker logs windows-endpoint-sim-01

# Restart container
./scripts/restart-sysmon.sh

# Rebuild image
docker build -t windows-endpoint-simulator:latest docker/windows-endpoint/
```

### Agent Registration Issues
```bash
# Check agent status
docker exec sentinel-ak-xl-wazuh-manager-1 /var/ossec/bin/manage_agents -l

# Restart Wazuh manager
docker exec sentinel-ak-xl-wazuh-manager-1 /var/ossec/bin/wazuh-control restart
```

### No Events in Kibana
```bash
# Check Elasticsearch indices
curl "localhost:9200/_cat/indices/wazuh*?v"

# Check Wazuh indexer
curl "localhost:9201/_cat/indices?v"

# Verify log generation
docker exec windows-endpoint-sim-01 tail /var/log/sysmon-simulator.log
```

## Next Steps (Part 2: Agent Management)
- Automated agent deployment across multiple endpoints
- Centralized configuration management
- Health monitoring dashboards
- Performance optimization

## MITRE ATT&CK Coverage
- **T1059**: Command and Scripting Interpreter
- **T1071**: Application Layer Protocol  
- **T1105**: Ingress Tool Transfer
- **T1547**: Boot or Logon Autostart Execution

---

**Status**: Sysmon Deployment Complete ✅  
**Next**: Part 2 - Agent Management Automation
