# SSH Authentication Simulator - Installation & Usage Guide

## 🎯 Overview

The SSH Authentication Simulator generates realistic SSH authentication failure logs for SOC training and dashboard testing. It creates diverse attack patterns with proper GeoIP data that flows through your Wazuh → ELK pipeline.

## 🚀 Quick Start

### 1. Install the Script

```bash
# Download and make executable
chmod +x ssh-auth-simulator.sh

# Copy to appropriate location
sudo cp ssh-auth-simulator.sh /usr/local/bin/ssh-auth-simulator
```

### 2. Test with Dry Run

```bash
# See what events would be generated
sudo ssh-auth-simulator --dry-run -n 5
```

### 3. Generate Test Events

```bash
# Generate 25 mixed authentication failures
sudo ssh-auth-simulator -n 25 -v
```

## 📊 Attack Patterns for Dashboard Testing

### Pattern 1: Fast Brute Force (Immediate Detection)
```bash
# Generates 15 rapid attempts - should trigger alerts quickly
sudo ssh-auth-simulator -p fast_brute -n 15 -d 1-3 -v
```
**Expected Dashboard Impact**: 
- High frequency spikes in authentication failures
- Single IP concentration
- Root account targeting

### Pattern 2: Distributed Attack (Advanced Threat)
```bash
# Coordinated attack from multiple IPs
sudo ssh-auth-simulator -p distributed -n 20 -v
```
**Expected Dashboard Impact**:
- Multiple source countries on geo map
- Coordinated timing patterns
- Admin account focus

### Pattern 3: Credential Spray (Stealth Attack)
```bash
# Many users, slower pace to avoid detection
sudo ssh-auth-simulator -p credential_spray -n 30 -d 5-15 -v
```
**Expected Dashboard Impact**:
- Wide username distribution
- Lower frequency per account
- Single IP, multiple targets

### Pattern 4: Targeted Attack (APT Simulation)
```bash
# Focus on high-value accounts
sudo ssh-auth-simulator -p targeted_attack -n 12 -v
```
**Expected Dashboard Impact**:
- Privileged account targeting (root, admin, oracle)
- Persistent attempts
- Potential for escalation

## 🔄 Continuous Monitoring Simulation

### Background Service Mode
```bash
# Run continuous simulation (stops with Ctrl+C)
sudo ssh-auth-simulator -c -p mixed -d 30-300 -v
```

### Scheduled Attacks (Cron)
```bash
# Add to crontab for regular attack simulation
# Every 2 hours during business hours
0 9-17/2 * * 1-5 /usr/local/bin/ssh-auth-simulator -n 8 -p slow_brute

# Random evening attacks
47 19 * * * /usr/local/bin/ssh-auth-simulator -n 12 -p mixed -d 1-5
```

## 📈 Dashboard Creation Workflow

### Step 1: Generate Base Data
```bash
# Create initial dataset for dashboard development
sudo ssh-auth-simulator -n 50 -p mixed -v

# Wait 2-3 minutes for Wazuh processing
sleep 180

# Verify events in Elasticsearch
curl -s "localhost:9200/sentinel-logs-*/_search?q=msg:Failed&size=0" | jq '.hits.total'
```

### Step 2: Generate Pattern-Specific Data
```bash
# Fast brute force data (15 events)
sudo ssh-auth-simulator -p fast_brute -n 15 -d 1-2 -v

# Credential spray data (25 events)  
sudo ssh-auth-simulator -p credential_spray -n 25 -d 3-8 -v

# Distributed attack data (20 events)
sudo ssh-auth-simulator -p distributed -n 20 -d 2-6 -v
```

### Step 3: Verify GeoIP Enrichment
```bash
# Check that events have geographic data
curl -s 'http://localhost:9200/sentinel-logs-*/_search' \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 1,
    "query": {"match": {"msg": "Failed password"}},
    "sort": [{"@timestamp": {"order": "desc"}}]
  }' | jq '.hits.hits[0]._source | {msg, geoip, agent}'
```

## 🗺️ Geographic Distribution

The simulator uses 25 different source countries:
- **High-risk regions**: China, Russia, Eastern Europe
- **Cloud providers**: AWS, DigitalOcean, OVH regions  
- **VPN/Proxy services**: Netherlands, Germany, UK
- **Compromised hosts**: Mexico, Brazil, India

## 📋 Log Format Examples

### Standard SSH Failure
```
Aug 30 14:23:17 sentinel-web-2 sshd[8947]: Failed password for admin from 103.124.106.4 port 22 ssh2
```

### Invalid User Attempt  
```
Aug 30 14:24:33 sentinel-app-1 sshd[9012]: Invalid user test from 185.220.101.45 port 52341
```

### Brute Force Detection
```
Aug 30 14:25:01 sentinel-db-3 sshd[9156]: Maximum authentication attempts exceeded for root from 189.201.241.25 port 22 ssh2 [preauth]
```

## 🔍 Troubleshooting

### Issue: No events appearing in Elasticsearch

**Check 1: Wazuh agent monitoring**
```bash
# Verify Wazuh is monitoring auth.log
docker exec sentinel-wazuh-manager grep -A 5 -B 5 "auth.log" /var/ossec/etc/ossec.conf
```

**Check 2: Log file permissions**
```bash
# Ensure Wazuh can read the auth log
ls -la /var/log/auth.log
sudo chmod 644 /var/log/auth.log
```

**Check 3: Filebeat shipping**
```bash
# Check if Filebeat is processing logs
docker logs -f sentinel-wazuh-manager | grep -i filebeat
```

### Issue: Events not enriched with GeoIP

**Solution: Verify Logstash GeoIP filter**
```bash
# Check Logstash pipeline includes GeoIP processing
curl -s http://localhost:9600/_node/pipelines?pretty | grep -A 10 -B 10 geoip
```

### Issue: Wrong timestamp format

**Solution: Events use system time**  
The simulator generates recent timestamps (last 24 hours) to ensure proper chronological ordering in dashboards.

## 📊 Expected Kibana Dashboard Metrics

After generating 100+ events, your authentication dashboard should show:

### Geographic Distribution
- **Top Countries**: China, Russia, Netherlands, Germany, US
- **Heat Map**: Concentrated activity in high-risk regions
- **ISP Analysis**: Cloud providers, hosting services, VPNs

### Attack Patterns  
- **Brute Force**: 10-15 rapid attempts per IP
- **Credential Spray**: 1-3 attempts per username
- **Targeted**: Focus on admin, root, oracle accounts

### Temporal Analysis
- **Peak Hours**: Business hours (9-17) if using cron
- **Attack Duration**: Fast brute (minutes), distributed (hours)
- **Frequency**: Mixed pattern creates realistic noise

## 🎓 Training Scenarios

### Scenario A: SOC Analyst Training
```bash
# Generate evidence of active brute force
sudo ssh-auth-simulator -p fast_brute -n 25 -d 1-2

# Student task: Identify attack pattern, source IP, timeline
# Expected finding: Single IP, rapid succession, root targeting
```

### Scenario B: Incident Response Exercise
```bash
# Generate distributed attack over 10 minutes
sudo ssh-auth-simulator -p distributed -n 30 -d 2-5

# Student task: Map attack infrastructure, assess coordination
# Expected finding: Multiple countries, synchronized timing
```

### Scenario C: Threat Hunting Practice
```bash
# Generate mixed patterns for hunting exercise
sudo ssh-auth-simulator -n 100 -p mixed -c &
# Let run for 30 minutes, then stop

# Student task: Hunt for anomalies in authentication logs
# Expected finding: Various attack techniques, baseline establishment
```

## 🔗 Integration with Your SOC Pipeline

### Wazuh Rules (should trigger)
- **5710**: Multiple authentication failures
- **5712**: SSHD authentication success after failed attempts  
- **5720**: Multiple SSHD authentication failures

### ELK Pipeline Processing
1. **Wazuh Manager** → processes auth.log changes
2. **Filebeat** → ships alerts to Logstash  
3. **Logstash** → enriches with GeoIP data
4. **Elasticsearch** → indexes as `sentinel-logs-*`
5. **Kibana** → visualizes geographic and temporal patterns

### Verification Command
```bash
# Check end-to-end pipeline with specific test token
TOKEN=$(date +%s)
echo "Aug 30 $(date +%H:%M:%S) sentinel-test sshd[9999]: Failed password for testuser$TOKEN from 8.8.8.8 port 22 ssh2" | sudo tee -a /var/log/auth.log

# Wait 60 seconds, then search for the token
sleep 60
curl -s "localhost:9200/sentinel-logs-*/_search?q=testuser$TOKEN" | jq '.hits.total'
```

## 🎯 Next Steps

After running this simulator and verifying events appear in your dashboards:

1. **Create Authentication Dashboard** with failed login geo-mapping
2. **Set up Wazuh alerts** for brute force detection  
3. **Build investigation workflows** for each attack pattern
4. **Document SOC procedures** for authentication incidents

The generated data provides a solid foundation for realistic SOC training scenarios and dashboard development.
