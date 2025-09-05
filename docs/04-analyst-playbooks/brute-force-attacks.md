# SOC Analyst Playbook: Brute Force Attacks

## Overview
- **Alert Type**: Authentication Brute Force
- **Severity Level**: High (Level 10-12)
- **MITRE ATT&CK Tactic**: Initial Access (T1110)
- **Response Time**: < 15 minutes for critical systems
- **Escalation**: Level 2 if successful authentication detected

## Detection Criteria

### Wazuh Rule Triggers
- **Rule 5716**: SSH authentication failure
- **Rule 5717**: Windows logon failure  
- **Rule 5720**: Multiple authentication failures
- **Custom Rule 100010**: Rapid authentication attempts

### Alert Thresholds
- **SSH**: > 10 failed attempts in 5 minutes from single IP
- **RDP**: > 5 failed attempts in 3 minutes from single IP
- **Web Apps**: > 15 failed attempts in 10 minutes
- **Service Accounts**: Any failed authentication

### Behavioral Indicators
- Multiple usernames attempted from same source
- Sequential password attempts (password spraying)
- Attempts outside business hours
- Geographic anomalies (impossible travel)

## Initial Triage Steps

### 1. Alert Validation (2-3 minutes)
- [ ] **Open alert in Wazuh Dashboard**
  ```
  Navigation: Security Events → Alerts → Filter by Rule ID 5716
  ```
- [ ] **Verify attack details**:
  - Source IP address
  - Target system/service
  - Number of attempts
  - Time span of attack
- [ ] **Check IP reputation**:
  - Review GeoIP location
  - Check against known good IP lists
  - Verify if IP is from expected geographic region

### 2. Context Gathering (5 minutes)
- [ ] **Historical analysis**:
  ```
  Query: srcip:"[ATTACKER_IP]" AND @timestamp:[now-7d TO now]
  ```
- [ ] **Target assessment**:
  - System criticality level
  - Business function
  - Data sensitivity
  - User account privilege level
- [ ] **Pattern identification**:
  - Check for simultaneous attacks on other systems
  - Review similar attacks in past 30 days

### 3. Impact Assessment (3 minutes)
- [ ] **Check for successful authentication**:
  ```
  Query: rule.id:5715 AND srcip:"[ATTACKER_IP]"
  ```
- [ ] **Review account status**:
  - Account lockout status
  - Recent password changes
  - Previous successful logins
- [ ] **System access verification**:
  - Active sessions from attacker IP
  - File access or system changes
  - Lateral movement indicators

## Investigation Workflow

### Phase 1: Immediate Analysis (5-10 minutes)

#### Elasticsearch Queries
```json
# Get all authentication events from attacker IP
GET /wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"data.srcip.keyword": "ATTACKER_IP"}},
        {"terms": {"rule.id": [5715, 5716, 5717, 5720]}},
        {"range": {"@timestamp": {"gte": "now-2h"}}}
      ]
    }
  },
  "sort": [{"@timestamp": {"order": "asc"}}],
  "size": 1000
}
```

```json
# Check for successful logins after failures
GET /wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"data.srcip.keyword": "ATTACKER_IP"}},
        {"term": {"rule.id": 5715}},
        {"range": {"@timestamp": {"gte": "now-1h"}}}
      ]
    }
  }
}
```

#### Kibana Dashboard Analysis
1. **Navigate to Authentication Monitoring Dashboard**
2. **Apply filters**:
   - Time range: Last 2 hours
   - Source IP: Attacker IP
   - Rule groups: Authentication
3. **Review visualizations**:
   - Failed authentication timeline
   - Geographic source mapping
   - Targeted usernames distribution
   - Success/failure ratio

### Phase 2: Threat Intelligence (5 minutes)

#### VirusTotal IP Reputation Check
```bash
# Check if VirusTotal integration is available
Query: rule.groups:"virustotal" AND data.virustotal.source.ip:"ATTACKER_IP"
```

#### Manual Threat Intelligence
- [ ] **Check IP against threat feeds**:
  - AbuseIPDB
  - GreyNoise
  - AlienVault OTX
- [ ] **Review geographic location**:
  - Country of origin
  - ISP information
  - Known malicious infrastructure
- [ ] **Historical context**:
  - Previous attacks from same ASN
  - Campaign attribution
  - Attack methodology patterns

### Phase 3: Lateral Movement Detection (10 minutes)

#### Network Activity Analysis
```json
# Check for other network activity from attacker IP
GET /wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "should": [
        {"term": {"data.srcip.keyword": "ATTACKER_IP"}},
        {"term": {"data.dstip.keyword": "ATTACKER_IP"}}
      ],
      "must_not": [
        {"terms": {"rule.groups": ["authentication"]}}
      ]
    }
  },
  "aggs": {
    "services": {
      "terms": {"field": "data.dstport"}
    }
  }
}
```

#### System Compromise Indicators
- [ ] **Check affected system logs**:
  ```
  Query: agent.name:"TARGET_SYSTEM" AND @timestamp:[now-1h TO now]
  ```
- [ ] **Look for privilege escalation**:
  - sudo attempts
  - Administrator group additions
  - Service account usage
- [ ] **File system activity**:
  - Unusual file creations
  - Configuration changes
  - Binary modifications

## Escalation Criteria

### Escalate to Level 2 Analyst if:
- [ ] **Successful authentication detected** from attacker IP
- [ ] **Multiple systems targeted** simultaneously
- [ ] **Privileged accounts involved** (admin, service accounts)
- [ ] **Attack from known threat actor** infrastructure
- [ ] **Complex attack patterns** (password spraying + lateral movement)

### Escalate to Incident Response if:
- [ ] **Evidence of system compromise** (successful login + file changes)
- [ ] **Data exfiltration suspected** (large data transfers)
- [ ] **Critical system affected** (domain controllers, databases)
- [ ] **Ongoing active compromise** with attacker presence
- [ ] **Multiple authentication vectors** compromised

## Response Actions

### Immediate Actions (< 15 minutes)

#### 1. Block Attacker IP
```bash
# Firewall rule (varies by system)
iptables -A INPUT -s ATTACKER_IP -j DROP

# Or via security appliance
curl -X POST "https://firewall-api/block" -d "ip=ATTACKER_IP"
```

#### 2. Account Protection
- [ ] **If account targeted**:
  - Disable affected user account temporarily
  - Force password reset
  - Revoke active sessions
  - Enable MFA if not configured

#### 3. System Monitoring
- [ ] **Increase monitoring** on affected systems
- [ ] **Deploy additional sensors** if available
- [ ] **Alert system owners** of potential threat

#### 4. Documentation
- [ ] **Create incident ticket** with initial findings
- [ ] **Document IOCs** (IP, timestamps, targeted accounts)
- [ ] **Timeline creation** of attack events

### Short-term Actions (< 1 hour)

#### 1. Enhanced Blocking
```bash
# Block entire subnet if part of botnet
iptables -A INPUT -s ATTACKER_SUBNET/24 -j DROP

# Geographic blocking if appropriate
iptables -A INPUT -m geoip --src-cc COUNTRY_CODE -j DROP
```

#### 2. Threat Hunting
- [ ] **Search for related indicators**:
  - Similar source IPs (same ASN)
  - Common attack patterns
  - Related timestamps
- [ ] **Check other authentication sources**:
  - VPN logs
  - Email authentication
  - Cloud service logins

#### 3. Communication
- [ ] **Notify stakeholders**:
  - IT Operations team
  - System administrators
  - Security team lead
  - Business unit (if critical system)

#### 4. Rule Tuning
- [ ] **Adjust detection thresholds** if needed
- [ ] **Create custom rules** for this attack pattern
- [ ] **Update IP blacklists** and signatures

### Long-term Actions (< 24 hours)

#### 1. Root Cause Analysis
- [ ] **Investigate attack vector**:
  - How attacker discovered target
  - Why this system was targeted
  - Vulnerability assessment needed
- [ ] **Review security controls**:
  - Account lockout policies
  - Password complexity requirements
  - Multi-factor authentication coverage

#### 2. Preventive Measures
- [ ] **Implement account lockout** if not configured
- [ ] **Deploy fail2ban** or similar tools
- [ ] **Enable logging** for all authentication attempts
- [ ] **Review privileged account** security

#### 3. Lessons Learned
- [ ] **Document attack methodology**
- [ ] **Update detection rules** based on findings
- [ ] **Improve response procedures** if gaps identified
- [ ] **Security awareness** notification if needed

## Tools and Commands

### Wazuh Queries
```bash
# View SSH authentication failures
rule.id:5716 AND agent.name:"target-server"

# Check for successful SSH logins after failures
rule.id:5715 AND data.srcip:"attacker-ip"

# Multiple authentication failures pattern
rule.id:5720 AND data.srcip:"attacker-ip"

# Windows authentication failures
rule.id:5717 AND agent.name:"windows-server"
```

### System-Level Investigation
```bash
# On Linux target system
sudo grep "Failed password" /var/log/auth.log | grep "ATTACKER_IP"
sudo grep "Accepted password" /var/log/auth.log | grep "ATTACKER_IP"
sudo last | grep "ATTACKER_IP"
sudo netstat -an | grep "ATTACKER_IP"

# On Windows target system
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625} | Where-Object {$_.Message -like "*SOURCE_IP*"}
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} | Where-Object {$_.Message -like "*SOURCE_IP*"}
```

### Network Analysis
```bash
# Check for active connections
netstat -an | grep ATTACKER_IP
ss -tupln | grep ATTACKER_IP

# Review firewall logs
tail -f /var/log/iptables.log | grep ATTACKER_IP
```

## Evidence Collection

### Log Collection
- [ ] **Export authentication logs** for affected timeframe
- [ ] **Capture network connection logs**
- [ ] **Save system logs** showing any unauthorized access
- [ ] **Document firewall block** confirmation

### Screenshot Documentation
- [ ] **Wazuh alert details** screenshot
- [ ] **Geographic location** of attacker IP
- [ ] **Timeline visualization** from Kibana
- [ ] **System status** after blocking

### Reporting Template
```
Incident Summary:
- Date/Time: [YYYY-MM-DD HH:MM UTC]
- Alert ID: [Wazuh Alert ID]
- Attacker IP: [IP Address]
- Geographic Location: [Country, City]
- Targeted System: [Hostname/IP]
- Targeted Accounts: [Username list]
- Attack Duration: [Start - End time]
- Total Attempts: [Number]
- Successful Logins: [Yes/No - Details]
- Response Actions Taken: [List actions]
- Current Status: [Contained/Ongoing/Resolved]
- Follow-up Required: [Yes/No - Details]
```

## False Positive Handling

### Common False Positive Scenarios
- **Legitimate user** with forgotten password
- **Service account** authentication issues
- **Load balancer** health checks appearing as failures
- **Network connectivity** issues causing repeated attempts

### Validation Steps
- [ ] **Contact user** if attempts during business hours
- [ ] **Check service status** for automated systems
- [ ] **Review recent changes** to authentication systems
- [ ] **Verify network connectivity** issues

### Tuning Recommendations
- **Increase thresholds** for known good IPs
- **Whitelist internal** IP ranges appropriately
- **Adjust time windows** based on normal user behavior
- **Exclude service accounts** from standard rules

## References
- [NIST SP 800-61: Computer Security Incident Handling Guide](https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final)
- [MITRE ATT&CK: Brute Force (T1110)](https://attack.mitre.org/techniques/T1110/)
- [Wazuh Authentication Rules Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/rules-classification.html#authentication)
- [OWASP Authentication Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

---
**Last Updated**: September 2025  
**Version**: 1.0  
**Approved By**: SOC Manager