# SSH Authentication Simulation Guide

## Overview

The SSH Authentication Simulator generates realistic SSH authentication failure logs for SOC training and dashboard testing. It creates diverse attack patterns with proper GeoIP data for your Wazuh → ELK pipeline.

## Quick Setup

### 1. Copy Script to Container
```bash
# Copy simulator to Wazuh manager container
docker cp scenarios-simulator/ssh-auth/ssh-auth-simulator.sh \
  sentinel-wazuh-manager:/usr/local/bin/ssh-auth-simulator

# Make executable
docker exec -it sentinel-wazuh-manager chmod +x /usr/local/bin/ssh-auth-simulator
```

### 2. Create Test Directory
```bash
# Create test log directory (should already exist from installation)
docker exec -it sentinel-wazuh-manager mkdir -p /var/ossec/logs/test

# Verify permissions
docker exec -it sentinel-wazuh-manager ls -la /var/ossec/logs/test/
```

## Basic Usage

### Test with Dry Run
```bash
# See what events would be generated without creating them
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator --dry-run -n 5
```

### Generate Basic Authentication Failures
```bash
# Generate 25 mixed authentication failures
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator -n 25 -v

# Use custom log file location
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -l /var/ossec/logs/test/sshd.log -n 50 -v
```

## Attack Patterns for SOC Training

### Pattern 1: Fast Brute Force (High Priority Alert)
```bash
# Generates rapid attempts from single IP - should trigger alerts quickly
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p fast_brute -n 15 -d 1-3 -v

# Expected: High frequency spikes, single IP concentration, root account targeting
```

### Pattern 2: Distributed Attack (APT Simulation)
```bash
# Coordinated attack from multiple IPs across different countries
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p distributed -n 20 -v

# Expected: Multiple source countries, coordinated timing, admin account focus
```

### Pattern 3: Credential Spray (Stealth Attack)
```bash
# Many users, slower pace to avoid detection thresholds
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p credential_spray -n 30 -d 5-15 -v

# Expected: Wide username distribution, lower frequency per account
```

### Pattern 4: Targeted Attack (High-Value Accounts)
```bash
# Focus on privileged accounts (root, admin, oracle, postgres)
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p targeted_attack -n 12 -v

# Expected: Privileged account targeting, persistent attempts
```

### Pattern 5: Slow Brute Force (Under the Radar)
```bash
# Low and slow approach to avoid detection
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p slow_brute -n 20 -d 10-30 -v

# Expected: Extended timeline, harder to detect patterns
```

## Continuous Monitoring Simulation

### Background Service Mode
```bash
# Run continuous simulation (stop with Ctrl+C or container restart)
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -c -p mixed -d 30-300 -v
```

### Scheduled Attack Simulation
```bash
# Run simulation in background for extended testing
docker exec -d sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p mixed -n 100 -d 5-20

# Check if running
docker exec -it sentinel-wazuh-manager ps aux | grep ssh-auth-simulator
```

## Geographic Distribution

The simulator uses 25 source IPs from various countries for realistic GeoIP analysis:

### High-Risk Regions
- **China** (103.124.106.4) - Known for brute force campaigns
- **Russia** (185.220.101.45) - TOR exit nodes, state actors
- **Ukraine** (194.147.32.101) - Compromised infrastructure

### Cloud/VPN Providers
- **Germany** (167.99.164.201) - DigitalOcean hosting
- **Netherlands** (92.63.197.153) - VPN services
- **UK** (46.101.230.157) - Cloud hosting
- **Singapore** (159.65.153.147) - Cloud services

### Other Regions
- **US** (198.211.99.118) - Suspicious activity
- **Canada** (161.35.70.249) - Cloud hosting
- **Japan** (142.93.222.179) - VPS providers

## Verification Commands

### Check Generated Authentication Logs
```bash
# View recent SSH simulation events
docker exec -it sentinel-wazuh-manager tail -f /var/log/auth.log

# Count total events generated  
docker exec -it sentinel-wazuh-manager grep "Failed password" /var/log/auth.log | wc -l

# View simulation-specific logs
docker exec -it sentinel-wazuh-manager tail -f /var/log/ssh-auth-simulation.log
```

### Verify Wazuh Processing
```bash
# Check for SSH authentication failure alerts (Rule 5716)
curl -s "localhost:9200/wazuh-alerts-*/_search?q=rule.id:5716&size=5&sort=@timestamp:desc" | \
  jq '.hits.hits[]._source | {timestamp: .timestamp, srcip: .data.srcip, user: .data.srcuser}'

# Check for multiple authentication failures (Rule 5720)
curl -s "localhost:9200/wazuh-alerts-*/_search?q=rule.id:5720&size=5&sort=@timestamp:desc" | \
  jq '.hits.hits[]._source | {timestamp: .timestamp, description: .rule.description}'
```

### Monitor GeoIP Enrichment
```bash
# Verify geographic enrichment in processed logs
curl -s "localhost:9200/sentinel-logs-*/_search" \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {"match": {"full_log": "Failed password"}},
    "size": 3,
    "_source": ["data.srcip", "geoip.country_name", "geoip.city_name", "@timestamp"]
  }' | jq '.hits.hits[]._source'
```

## Expected Wazuh Rules Triggered

### Rule 5716: SSH Authentication Failure
- **Level**: 5
- **Description**: SSH authentication failure
- **Trigger**: Each failed login attempt

### Rule 5720: Multiple SSH Authentication Failures  
- **Level**: 10
- **Description**: Multiple authentication failures
- **Trigger**: Multiple failures from same source

### Custom Rules (if configured)
- **Rule 100010**: Rapid authentication attempts
- **Geographic filtering rules**: High-risk country alerts

## Log Format Examples

### Standard SSH Failure
```
Sep 04 14:23:17 sentinel-web-2 sshd[8947]: Failed password for admin from 103.124.106.4 port 22 ssh2
```

### Invalid User Attempt
```
Sep 04 14:24:33 sentinel-app-1 sshd[9012]: Invalid user test from 185.220.101.45 port 52341
```

### Authentication Limit Exceeded
```
Sep 04 14:25:01 sentinel-db-3 sshd[9156]: Maximum authentication attempts exceeded for root from 189.201.241.25 port 22 ssh2 [preauth]
```

## Training Scenarios

### Scenario A: SOC Analyst Triage Training
```bash
# Generate evidence of active brute force attack
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p fast_brute -n 25 -d 1-2

# Student Task: Identify attack pattern, source IP, targeted accounts, timeline
# Expected Finding: Single IP, rapid succession, root account targeting
```

### Scenario B: Incident Response Exercise
```bash
# Generate distributed attack over 10 minutes
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p distributed -n 30 -d 2-5

# Student Task: Map attack infrastructure, assess coordination level
# Expected Finding: Multiple countries, synchronized timing patterns
```

### Scenario C: Threat Hunting Practice
```bash
# Generate mixed patterns for hunting exercise
docker exec -d sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -n 100 -p mixed -c

# Let run for 30 minutes, then stop with:
docker exec -it sentinel-wazuh-manager pkill -f ssh-auth-simulator

# Student Task: Hunt for anomalies in authentication logs
# Expected Finding: Various attack techniques, baseline establishment
```

## Dashboard Creation Workflow

### Step 1: Generate Base Dataset
```bash
# Create initial dataset for dashboard development
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -n 50 -p mixed -v

# Wait 2-3 minutes for processing
sleep 180

# Verify events in Elasticsearch
curl -s "localhost:9200/sentinel-logs-*/_search?q=Failed%20password&size=0" | jq '.hits.total'
```

### Step 2: Generate Pattern-Specific Data
```bash
# Fast brute force data
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p fast_brute -n 15 -d 1-2 -v

# Credential spray data
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p credential_spray -n 25 -d 3-8 -v

# Distributed attack data
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p distributed -n 20 -d 2-6 -v
```

## Cleanup and Management

### Stop Running Simulations
```bash
# Find and stop any running SSH simulators
docker exec -it sentinel-wazuh-manager pkill -f ssh-auth-simulator

# Verify no processes running
docker exec -it sentinel-wazuh-manager ps aux | grep ssh-auth-simulator
```

### Clear Simulation Logs
```bash
# Clear SSH simulation logs (keep system auth.log intact)
docker exec -it sentinel-wazuh-manager : > /var/log/ssh-auth-simulation.log

# Clear custom test log if used
docker exec -it sentinel-wazuh-manager : > /var/ossec/logs/test/sshd.log
```

### View Simulation Statistics
```bash
# Check simulation log for statistics
docker exec -it sentinel-wazuh-manager cat /var/log/ssh-auth-simulation.log

# Count events by attack pattern
docker exec -it sentinel-wazuh-manager grep -c "FAST_BRUTE\|DISTRIBUTED\|CRED_SPRAY" /var/log/ssh-auth-simulation.log
```

## Troubleshooting

### No SSH Alerts Appearing
```bash
# Check if Wazuh is monitoring auth.log
docker exec -it sentinel-wazuh-manager grep -A 5 -B 5 "auth.log" /var/ossec/etc/ossec.conf

# Verify log file permissions
docker exec -it sentinel-wazuh-manager ls -la /var/log/auth.log

# Ensure Wazuh can read auth.log
docker exec -it sentinel-wazuh-manager chmod 644 /var/log/auth.log
```

### Events Not Enriched with GeoIP
```bash
# Check Logstash GeoIP processing
curl -s "localhost:9600/_node/pipelines?pretty" | grep -A 10 -B 10 geoip

# Verify Logstash is processing auth logs
docker logs sentinel-logstash | grep -i geoip
```

### Wrong Timestamp Issues
```bash
# Verify system time in container
docker exec -it sentinel-wazuh-manager date

# Check log timestamps format
docker exec -it sentinel-wazuh-manager tail -5 /var/log/auth.log
```

### Script Permission Errors
```bash
# Re-apply executable permissions
docker exec -it sentinel-wazuh-manager chmod +x /usr/local/bin/ssh-auth-simulator

# Check script location
docker exec -it sentinel-wazuh-manager ls -la /usr/local/bin/ssh-auth-simulator
```

## Expected Dashboard Metrics

After generating 100+ events, your authentication dashboard should display:

### Geographic Distribution
- **Top Countries**: China, Russia, Netherlands, Germany, US
- **Heat Map**: Concentrated activity in high-risk regions
- **ISP Analysis**: Cloud providers, hosting services, VPN endpoints

### Attack Pattern Analysis
- **Brute Force**: 10-15 rapid attempts per source IP
- **Credential Spray**: 1-3 attempts per username across many accounts
- **Targeted Attacks**: Focus on admin, root, oracle, postgres accounts

### Temporal Analysis
- **Attack Duration**: Fast brute (minutes), distributed (hours), slow brute (days)
- **Peak Activity**: Varies by pattern and configuration
- **Frequency Distribution**: Mixed patterns create realistic baseline noise

## Integration with SOC Pipeline

### End-to-End Verification
```bash
# Generate test event with unique identifier
TOKEN=$(date +%s)
docker exec -it sentinel-wazuh-manager bash -c "
echo 'Sep 04 $(date +%H:%M:%S) sentinel-test sshd[9999]: Failed password for testuser$TOKEN from 8.8.8.8 port 22 ssh2' >> /var/log/auth.log
"

# Wait for processing (60 seconds)
sleep 60

# Search for the test token in Elasticsearch
curl -s "localhost:9200/sentinel-logs-*/_search?q=testuser$TOKEN" | jq '.hits.total'
```

### Expected Processing Flow
1. **Wazuh Manager** → Processes auth.log changes via syscheck
2. **Rule Engine** → Applies SSH authentication rules (5716, 5720)
3. **Filebeat** → Ships alerts to Logstash for enrichment
4. **Logstash** → Adds GeoIP data and sends to Elasticsearch
5. **Elasticsearch** → Indexes as `sentinel-logs-*` pattern
6. **Kibana** → Visualizes geographic and temporal attack patterns

### Wazuh Rules Integration
- **Rule 5710**: Multiple authentication failures (base rule)
- **Rule 5716**: SSH authentication failure (individual events)
- **Rule 5720**: Multiple SSH authentication failures (correlation)
- **Custom Rules**: Geographic filtering, rapid attempt detection

## Advanced Usage

### Custom Attack Scenarios
```bash
# Simulate APT-style slow burn attack
docker exec -d sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p slow_brute -c -d 300-1800  # 5-30 minute delays

# Simulate weekend attack campaign
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p distributed -n 50 -d 10-60 -v
```

### Combining with Network Simulation
```bash
# Run SSH attacks followed by network reconnaissance
docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
  -p fast_brute -n 20 -v

# Wait 5 minutes, then simulate network scan from same geographic region
sleep 300
docker exec -it sentinel-wazuh-manager /usr/local/bin/network-activity-simulator \
  -p portscan_fast -n 3 -v
```

### Testing Detection Thresholds
```bash
# Test detection threshold tuning
for i in {1..5}; do
  docker exec -it sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator \
    -p fast_brute -n $((i*5)) -d 1-2 -v
  sleep 120  # Wait between batches
done
```

This simulation provides realistic SSH authentication attack scenarios essential for SOC analyst training and system validation. The generated data creates a foundation for building comprehensive authentication monitoring dashboards and response procedures.