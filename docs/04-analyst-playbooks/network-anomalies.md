# SOC Analyst Playbook: Network Anomalies

## Overview
- **Alert Type**: Network Anomalies / Port Scanning / Traffic Analysis
- **Severity Level**: Medium to High (Level 7-12)
- **MITRE ATT&CK Tactic**: Reconnaissance, Discovery, Command and Control
- **Response Time**: < 20 minutes for high-severity alerts
- **Escalation**: Level 2 if coordinated attack or critical system targeted

## Detection Criteria

### Wazuh Rule Triggers
- **Rule 4101**: IPTABLES DROP events
- **Custom Rule 100111**: Possible port scan detection (10+ dropped connections in 60s)
- **Rule 100003**: Sysmon Network Connection events
- **Firewall Rules**: Various DROP/REJECT events

### Alert Patterns
- **Port Scanning**: Multiple connection attempts to different ports
- **Host Discovery**: ICMP/ping sweeps across IP ranges
- **Service Discovery**: Connection attempts to common service ports
- **Data Exfiltration**: Large outbound data transfers
- **Command & Control**: Unusual outbound connections

### Network Indicators
```
Source Patterns:
- Multiple destinations from single source
- Sequential port scanning patterns
- Geographic anomalies (impossible travel)
- Known malicious IP ranges

Traffic Patterns:
- High frequency connection attempts
- Unusual protocols or ports
- Off-hours network activity
- Bandwidth anomalies
```

## Initial Triage Steps

### 1. Alert Validation (3-5 minutes)
- [ ] **Open alert in Wazuh Dashboard**
  ```
  Navigation: Security Events → Alerts → Filter by rule.groups:firewall_drop
  ```
- [ ] **Verify network event details**:
  - Source IP and geographic location
  - Destination IP and ports
  - Protocol and packet size
  - Frequency and timing patterns

### 2. Geographic Analysis (2 minutes)
- [ ] **Check source IP location**:
  ```
  Query: rule.id:"4101" AND data.srcip:"SOURCE_IP"
  Fields: geoip.country_name, geoip.city_name, geoip.location
  ```
- [ ] **Validate geographic context**:
  - Expected vs unexpected geographic regions
  - VPN/proxy/hosting provider indicators
  - Known malicious IP reputation

### 3. Pattern Recognition (5 minutes)
- [ ] **Analyze attack pattern**:
  ```
  Query: data.srcip:"SOURCE_IP" AND @timestamp:[now-1h TO now]
  Aggregations: data.dstport, data.dstip, data.protocol
  ```
- [ ] **Identify attack type**:
  - Port scan (multiple ports, same destination)
  - Host sweep (multiple hosts, same port)
  - Service discovery (common service ports)
  - Targeted attack (specific service/application)

## Investigation Workflow

### Phase 1: Traffic Pattern Analysis (10 minutes)

#### Elasticsearch Queries
```json
# Get all network events from suspicious source
GET /sentinel-logs-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"data.srcip.keyword": "SUSPICIOUS_IP"}},
        {"terms": {"rule.groups.keyword": ["firewall_drop", "sysmon_network_connection"]}},
        {"range": {"@timestamp": {"gte": "now-2h"}}}
      ]
    }
  },
  "aggs": {
    "ports": {
      "terms": {"field": "data.dstport.keyword", "size": 50}
    },
    "destinations": {
      "terms": {"field": "data.dstip.keyword", "size": 20}
    },
    "timeline": {
      "date_histogram": {
        "field": "@timestamp",
        "interval": "5m"
      }
    }
  }
}
```

```json
# Port scan detection query
GET /sentinel-logs-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"rule.id": "100111"}},
        {"range": {"@timestamp": {"gte": "now-24h"}}}
      ]
    }
  },
  "aggs": {
    "scanners": {
      "terms": {"field": "data.srcip.keyword"}
    }
  }
}
```

#### Traffic Volume Analysis
- [ ] **Assess connection frequency**:
  - Connections per minute/hour
  - Burst patterns vs sustained activity
  - Comparison to baseline traffic
- [ ] **Analyze target diversity**:
  - Number of unique destinations
  - Port range coverage
  - Service targeting patterns

### Phase 2: Threat Intelligence Correlation (10 minutes)

#### IP Reputation Analysis
- [ ] **Check threat intelligence feeds**:
  ```
  Query: geoip.country_name:"COUNTRY" AND rule.level:>=10
  ```
- [ ] **Validate IP reputation**:
  - Known botnet membership
  - Previous attack history
  - Hosting provider reputation
  - Tor exit node status

#### Attack Signature Matching
- [ ] **Compare to known attack patterns**:
  - Mirai botnet scanning patterns
  - APT reconnaissance techniques
  - Vulnerability scanner signatures
  - Penetration testing tools

### Phase 3: Impact Assessment (10 minutes)

#### Internal Network Analysis
```json
# Check for successful connections
GET /wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"data.srcip.keyword": "SUSPICIOUS_IP"}},
        {"terms": {"rule.groups.keyword": ["authentication", "web_access"]}},
        {"range": {"@timestamp": {"gte": "now-24h"}}}
      ]
    }
  }
}
```

#### System Compromise Indicators
- [ ] **Look for successful authentication**:
  - SSH login attempts from scanning IP
  - Web application access
  - Service authentication success
- [ ] **Check for follow-up activity**:
  - File transfers after connection
  - Command execution
  - Lateral movement attempts

## Escalation Criteria

### Escalate to Level 2 Analyst if:
- [ ] **High-volume coordinated scanning** (1000+ attempts/hour)
- [ ] **Critical infrastructure targeted** (SCADA, database servers)
- [ ] **Successful connection established** after scanning
- [ ] **Multiple source IPs** with coordinated patterns
- [ ] **Advanced evasion techniques** detected

### Escalate to Incident Response if:
- [ ] **Evidence of system compromise** following scan
- [ ] **Data exfiltration detected** after reconnaissance
- [ ] **APT-level sophistication** in attack patterns
- [ ] **Critical system availability** impact
- [ ] **Ongoing active breach** indicators

## Response Actions

### Immediate Actions (< 15 minutes)

#### 1. Source IP Blocking
```bash
# Block at firewall level
iptables -A INPUT -s SUSPICIOUS_IP -j DROP
iptables -A FORWARD -s SUSPICIOUS_IP -j DROP

# Block entire subnet if part of coordinated attack
iptables -A INPUT -s SUSPICIOUS_SUBNET/24 -j DROP
```

#### 2. Enhanced Monitoring
- [ ] **Increase logging verbosity** for affected systems
- [ ] **Deploy additional sensors** if available
- [ ] **Monitor for lateral movement** on targeted systems
- [ ] **Alert on any successful connections** from blocked IPs

#### 3. Network Segmentation
- [ ] **Isolate critical systems** if targeted
- [ ] **Increase access controls** on affected network segments
- [ ] **Review firewall rules** for gaps

### Short-term Actions (< 1 hour)

#### 1. Pattern Analysis Enhancement
```bash
# Create custom detection rules
# Alert on similar patterns from different IPs
# Implement dynamic blocking for high-frequency sources
```

#### 2. Threat Intelligence Integration
- [ ] **Submit malicious IPs** to threat feeds
- [ ] **Update blocklists** with confirmed threats
- [ ] **Share IOCs** with security community
- [ ] **Enhance reputation checking**

#### 3. Vulnerability Assessment
- [ ] **Scan targeted systems** for vulnerabilities
- [ ] **Review exposed services** on targeted ports
- [ ] **Validate security controls** effectiveness
- [ ] **Update security policies** if needed

### Long-term Actions (< 24 hours)

#### 1. Infrastructure Hardening
- [ ] **Close unnecessary ports** identified in scan
- [ ] **Update service configurations** to reduce attack surface
- [ ] **Implement rate limiting** on exposed services
- [ ] **Deploy intrusion prevention** systems

#### 2. Detection Improvement
- [ ] **Tune detection thresholds** based on attack patterns
- [ ] **Implement behavioral analysis** for anomaly detection
- [ ] **Create custom signatures** for identified attack tools
- [ ] **Enhance geographic filtering** rules

## Tools and Queries

### Wazuh Network Queries
```bash
# Firewall drop events
rule.groups:"firewall_drop" AND data.srcip:"IP_ADDRESS"

# Port scan detection
rule.id:"100111" AND data.srcip:"SCANNER_IP"

# High-frequency network events
rule.groups:"firewall_drop" AND @timestamp:[now-1h TO now]

# Sysmon network connections
rule.id:"100003" AND win.eventdata.sourceIp:"EXTERNAL_IP"
```

### Network Analysis Commands
```bash
# Analyze firewall logs
grep "IPTABLES-DROP" /var/log/kern.log | grep "SOURCE_IP"

# Check netstat for active connections
netstat -an | grep "SUSPICIOUS_IP"

# Review network traffic patterns
tcpdump -n host SUSPICIOUS_IP

# Check for successful connections in auth logs
grep "Accepted\|Failed" /var/log/auth.log | grep "SUSPICIOUS_IP"
```

### Geographic Analysis
```bash
# GeoIP lookup for source IP
geoiplookup SUSPICIOUS_IP

# Check ASN information
whois -h whois.cymru.com " -v SUSPICIOUS_IP"

# DNS reverse lookup
dig -x SUSPICIOUS_IP
```

## Evidence Collection

### Network Evidence
- [ ] **Capture network traffic** during scanning activity
- [ ] **Export firewall logs** for affected timeframe  
- [ ] **Document connection attempts** and patterns
- [ ] **Screenshot geographic mapping** of attack sources

### System Evidence
- [ ] **Check system logs** on targeted hosts
- [ ] **Review authentication logs** for successful access
- [ ] **Document any file transfers** or system changes
- [ ] **Capture process lists** if compromise suspected

### Threat Intelligence
- [ ] **Research attacking IP** reputation and history
- [ ] **Document attack methodology** and tools used
- [ ] **Correlate with known campaigns** or threat actors
- [ ] **Share IOCs** with appropriate communities

## Common False Positives

### Legitimate Network Scanning
- **Scenario**: Authorized vulnerability scans or security testing
- **Validation**: Check with security team for scheduled scans
- **Tuning**: Whitelist authorized scanning sources

### Network Device Discovery
- **Scenario**: Network management tools discovering devices
- **Validation**: Verify with network operations team
- **Tuning**: Exclude management network ranges

### Application Health Checks
- **Scenario**: Load balancers or monitoring tools checking services
- **Validation**: Confirm with application teams
- **Tuning**: Whitelist monitoring source IPs

### User Behavior Anomalies
- **Scenario**: Users connecting from new locations or devices
- **Validation**: Contact users directly to confirm activity
- **Tuning**: Implement user education on travel notifications

## Integration Points

### With Other Detection Systems
- **SIEM**: Correlate with authentication and application logs
- **IDS/IPS**: Cross-reference with signature-based detections
- **DNS Monitoring**: Check for malicious domain queries
- **Endpoint Detection**: Look for process execution on targets

### With Response Systems
- **Firewall**: Automated blocking of confirmed threats
- **Proxy/WAF**: Enhanced filtering for web-based attacks
- **Email Security**: Block phishing from same source networks
- **Threat Intelligence**: Feed IOCs to enterprise security tools

## Detection Rule Enhancements

### Custom Rules for Enhanced Detection
```xml
<!-- Enhanced port scan detection -->
<rule id="100112" level="10" frequency="20" timeframe="300">
  <if_matched_sid>4101</if_matched_sid>
  <same_source_ip/>
  <description>Intensive port scan detected from $(srcip) - $(frequency) attempts in 5 minutes</description>
  <group>network,portscan,high_frequency</group>
  <mitre><id>T1046</id></mitre>
</rule>

<!-- Geographic anomaly detection -->
<rule id="100113" level="8">
  <if_sid>4101</if_sid>
  <field name="geoip.country_code2">^(CN|RU|KP|IR)$</field>
  <description>Network activity from high-risk country: $(geoip.country_name)</description>
  <group>network,geographic_anomaly</group>
  <mitre><id>T1583</id></mitre>
</rule>
```

## References
- [NIST Cybersecurity Framework - Detect](https://www.nist.gov/cyberframework)
- [MITRE ATT&CK: Discovery](https://attack.mitre.org/tactics/TA0007/)
- [SANS Network Security Monitoring](https://www.sans.org/white-papers/37477/)
- [Wazuh Network Monitoring](https://documentation.wazuh.com/current/user-manual/capabilities/log-data-collection/)
- [OWASP Network Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)

---
**Last Updated**: September 2025  
**Version**: 1.0  
**Approved By**: SOC Manager