# Network Attacks Simulation Guide

## Overview

The Network Activity Simulator generates syslog-style iptables/UFW-like events to test network monitoring, port scan detection, and geographic threat analysis in your Wazuh → ELK pipeline.

## Quick Setup

### 1. Copy Script to Container
```bash
# Copy simulator to Wazuh manager container
docker cp scenarios-simulator/network/network-activity-simulator.sh \
  sentinel-wazuh-manager:/usr/local/bin/network-activity-simulator

# Make executable
docker exec -it sentinel-wazuh-manager chmod +x /usr/local/bin/network-activity-simulator
```

### 2. Verify Log Directory
```bash
# Check if network log directory exists
docker exec -it sentinel-wazuh-manager ls -la /var/ossec/logs/test/

# Create if needed (should already exist from installation)
docker exec -it sentinel-wazuh-manager mkdir -p /var/ossec/logs/test
```

## Basic Usage

### Single Network Event
```bash
# Generate one network connection attempt
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 1 -p single_flow -d 0-0 -v
```

### Port Scan Simulation
```bash
# Fast port scan (20 ports in rapid succession)
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 1 -p portscan_fast -d 0-0 -v

# Slow port scan (8 ports with delays)
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 1 -p portscan_slow -d 2-5 -v
```

### UDP Probes
```bash
# Generate UDP probe attempts (DNS, SNMP, etc.)
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -p udp_probe -n 5 -d 1-3 -v
```

## Training Scenarios

### Scenario 1: Basic Network Monitoring Test
```bash
# Generate mixed network activity
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 10 -p mixed -v

# Expected: Various firewall drop events from different countries
```

### Scenario 2: Port Scan Detection
```bash
# Trigger port scan detection rule (Rule 100111)
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -p portscan_fast -n 3 -d 1-2 -v

# Expected: Multiple rapid connections should trigger custom rule 100111
```

### Scenario 3: Geographic Threat Analysis
```bash
# Generate events from multiple geographic locations
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 20 -p mixed -d 2-5 -v

# Expected: GeoIP enrichment showing attacks from China, Russia, Netherlands, etc.
```

### Scenario 4: Continuous Background Activity
```bash
# Run continuous simulation for dashboard testing
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -p mixed -c -d 10-30 -v

# Stop with Ctrl+C when ready
```

## Attack Patterns

### single_flow
- **Description**: Individual connection attempts to common services
- **Ports Targeted**: 22 (SSH), 80 (HTTP), 443 (HTTPS), 3306 (MySQL), 9200 (Elasticsearch)
- **Use Case**: Baseline network activity simulation

### portscan_fast
- **Description**: Rapid port scanning (20 ports in ~2 seconds)
- **Behavior**: Sequential port attempts from same source IP
- **Use Case**: Automated scanning tool detection

### portscan_slow
- **Description**: Stealthy port scanning (8 ports with delays)
- **Behavior**: Spread out over time to avoid detection
- **Use Case**: Advanced persistent threat simulation

### udp_probe
- **Description**: UDP service discovery attempts
- **Ports Targeted**: 53 (DNS), 123 (NTP), 161 (SNMP), 500 (IPSec)
- **Use Case**: Network reconnaissance simulation

### mixed
- **Description**: Random combination of all patterns
- **Behavior**: Realistic varied network activity
- **Use Case**: General SOC training scenarios

## Command Examples

### Quick Tests
```bash
# Test each pattern individually
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 1 -p single_flow -v
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 1 -p udp_probe -v
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 1 -p portscan_fast -v
```

### Dashboard Population
```bash
# Generate substantial data for dashboard creation
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -n 50 -p mixed -d 1-5 -v
```

### Real-time Monitoring
```bash
# Background continuous generation
docker exec -d sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -c -p mixed -d 30-120

# Check if running
docker exec -it sentinel-wazuh-manager ps aux | grep network-activity-simulator
```

## Source IPs Used

The simulator uses 13 different source IPs from various geographic locations:

- **103.124.106.4** (China)
- **185.220.101.45** (Russia)  
- **92.63.197.153** (Netherlands)
- **167.99.164.201** (Germany)
- **159.65.153.147** (Singapore)
- **46.101.230.157** (UK)
- **198.211.99.118** (US)
- **161.35.70.249** (Canada)
- **178.62.193.217** (Sweden)
- **142.93.222.179** (Japan)
- **95.217.134.208** (Czech Republic)
- **51.15.228.88** (Romania)
- **64.227.123.199** (Italy)

## Verification Commands

### Check Generated Logs
```bash
# View recent network simulation logs
docker exec -it sentinel-wazuh-manager tail -f /var/ossec/logs/test/network.log

# Count events generated
docker exec -it sentinel-wazuh-manager wc -l /var/ossec/logs/test/network.log
```

### Verify Wazuh Processing
```bash
# Check for firewall drop alerts
curl -s "localhost:9200/wazuh-alerts-*/_search?q=rule.id:4101&size=5&sort=@timestamp:desc" | \
  jq '.hits.hits[]._source | {timestamp: .timestamp, srcip: .data.srcip, dstport: .data.dstport}'

# Check for port scan detection
curl -s "localhost:9200/wazuh-alerts-*/_search?q=rule.id:100111&size=5&sort=@timestamp:desc" | \
  jq '.hits.hits[]._source | {timestamp: .timestamp, srcip: .data.srcip, description: .rule.description}'
```

### Monitor GeoIP Enrichment
```bash
# Check for geographic data in Elasticsearch
curl -s "localhost:9200/sentinel-logs-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {"term": {"rule.groups.keyword": "firewall_drop"}},
    "size": 3,
    "_source": ["data.srcip", "geoip.country_name", "geoip.city_name", "@timestamp"]
  }' | jq '.hits.hits[]._source'
```

## Expected Wazuh Rules Triggered

### Rule 4101: IPTABLES DROP
- **Level**: 5
- **Description**: IPTABLES DROP events
- **Trigger**: Every simulated network event

### Rule 100111: Port Scan Detection  
- **Level**: 10
- **Description**: Possible port scan detection
- **Trigger**: 10+ events from same IP in 60 seconds
- **Pattern**: Fast port scan simulation

## Log Format Examples

### TCP Connection Drop
```
Sep 04 14:23:17 sentinel-755 kernel: IPTABLES-DROP: IN=eth0 OUT= MAC=de:ad:be:ef:00:01 SRC=103.124.106.4 DST=172.20.0.15 LEN=60 TOS=0x00 PREC=0x00 TTL=58 ID=45231 DF PROTO=TCP SPT=54321 DPT=22 SYN URGP=0
```

### UDP Probe
```  
Sep 04 14:24:33 sentinel-432 kernel: IPTABLES-DROP: IN=eth0 OUT= MAC=de:ad:be:ef:00:01 SRC=185.220.101.45 DST=172.20.0.22 LEN=85 TOS=0x00 PREC=0x00 TTL=42 ID=23891 DF PROTO=UDP SPT=34567 DPT=53
```

## Cleanup

### Stop Continuous Simulation
```bash
# Find and stop running simulation
docker exec -it sentinel-wazuh-manager pkill -f network-activity-simulator

# Clear simulation logs
docker exec -it sentinel-wazuh-manager : > /var/ossec/logs/test/network.log
```

### Check Simulation Status
```bash
# View simulation logs
docker exec -it sentinel-wazuh-manager cat /var/log/network-simulation.log
```

## Troubleshooting

### No Network Alerts Appearing
```bash
# Check if Wazuh is monitoring the network log file
docker exec -it sentinel-wazuh-manager grep -A 5 -B 5 "network.log" /var/ossec/etc/ossec.conf

# Verify log file permissions
docker exec -it sentinel-wazuh-manager ls -la /var/ossec/logs/test/network.log
```

### GeoIP Not Working
```bash
# Check Logstash GeoIP filter configuration
curl -s "localhost:9600/_node/pipelines?pretty" | grep -A 10 -B 10 geoip

# Verify GeoIP database
docker exec -it sentinel-logstash ls -la /usr/share/logstash/vendor/geoip/
```

### Port Scan Rule Not Triggering
```bash
# Generate enough events to trigger rule (10+ in 60 seconds)
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator -p portscan_fast -n 5 -d 0-1 -v

# Check rule frequency settings
docker exec -it sentinel-wazuh-manager grep -A 5 -B 5 "100111" /var/ossec/etc/rules/local_rules.xml
```

## Integration with SOC Workflow

### Alert Response Process
1. **Network Drop Event** → Investigate source IP and destination
2. **GeoIP Analysis** → Assess geographic risk factors  
3. **Pattern Recognition** → Identify scanning vs targeted attacks
4. **Threat Intelligence** → Cross-reference with known bad actors

### Dashboard Metrics
- **Geographic Heatmap** → Show attack sources worldwide
- **Port Targeting** → Visualize most attacked services
- **Attack Timeline** → Track scanning activity over time
- **Source IP Reputation** → Monitor repeat offenders

This simulation provides realistic network attack scenarios for training SOC analysts in network security monitoring and response procedures.