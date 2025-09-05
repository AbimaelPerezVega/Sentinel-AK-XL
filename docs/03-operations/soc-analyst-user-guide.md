# SOC Analyst User Guide

## Overview

This guide covers daily operations for SOC analysts using the Sentinel AK-XL platform for security monitoring and incident response.

## Getting Started

### Daily Login Checklist
1. **Access Dashboards**
   - Kibana: http://localhost:5601
   - Wazuh Dashboard: https://localhost:443
   - Credentials: See system administrator

2. **Verify System Health**
   - [ ] All services running (green status)
   - [ ] Recent log ingestion (last 5 minutes)
   - [ ] No service alerts or errors

3. **Review Overnight Activity**
   - [ ] Check alert queue for overnight incidents
   - [ ] Review automated responses
   - [ ] Prioritize based on severity

## Primary Workflows

### 1. Alert Triage Process

#### Step 1: Access Alert Queue
```
Wazuh Dashboard → Security Events → Alerts
- Filter by: Last 24 hours
- Sort by: Severity (High to Low)
- Priority: Level 10+ alerts first
```

#### Step 2: Initial Assessment
For each alert:
- [ ] Read alert description and context
- [ ] Check source IP reputation (GeoIP/VirusTotal)
- [ ] Review affected asset criticality
- [ ] Determine if alert is actionable

#### Step 3: Classification
- **True Positive**: Confirmed security incident
- **False Positive**: Benign activity triggering rules
- **Noise**: Low-value recurring alerts
- **Investigation Needed**: Requires deeper analysis

### 2. Incident Investigation

#### Authentication Alerts
```
Navigation: Kibana → SOC Dashboard → Authentication Monitoring
Key Metrics:
- Failed login attempts by IP
- Geographic distribution of logins
- Brute force timeline
- Successful logins after failures
```

**Investigation Steps:**
1. Check source IP reputation
2. Review login patterns (timing, frequency)
3. Verify user activity legitimacy
4. Check for lateral movement

#### Network Anomalies
```
Navigation: Kibana → SOC Dashboard → Network Analysis
Key Metrics:
- Top talking hosts
- Unusual port connections
- Geographic traffic patterns
- Protocol distribution
```

**Investigation Steps:**
1. Identify unusual network patterns
2. Check destination IP reputation
3. Review packet flows and timing
4. Correlate with other security events

#### Malware Detection
```
Navigation: Kibana → SOC Dashboard → Threat Intelligence
Key Metrics:
- VirusTotal detections
- File integrity changes
- Process creation events
- Registry modifications
```

**Investigation Steps:**
1. Review file hash reputation
2. Check file location and permissions
3. Analyze process tree and parent
4. Look for persistence mechanisms

### 3. Response Actions

#### Immediate Actions (< 15 minutes)
- **Block malicious IPs** at firewall
- **Disable compromised accounts** temporarily
- **Isolate affected systems** if necessary
- **Document initial findings** in ticket

#### Short-term Actions (< 1 hour)
- **Collect additional evidence** (logs, files)
- **Notify stakeholders** via established channels
- **Begin containment** measures
- **Update detection rules** if needed

#### Follow-up Actions (< 24 hours)
- **Complete investigation** and documentation
- **Implement permanent fixes**
- **Conduct lessons learned** session
- **Update procedures** based on findings

## Dashboard Navigation

### SOC Overview Dashboard
**Purpose**: High-level security posture monitoring
**Key Widgets**:
- Alert volume trends
- Top attack sources (geographic)
- Service health status
- Recent critical alerts

**Usage**: Start here each shift for situational awareness

### Authentication Monitoring
**Purpose**: Login and access monitoring
**Key Widgets**:
- Failed authentication attempts
- Successful logins by location
- Brute force detection
- Account lockout events

**Usage**: Monitor for credential attacks and insider threats

### Network Analysis
**Purpose**: Network traffic and connection monitoring
**Key Widgets**:
- Top talkers and destinations
- Port scanning detection
- Geographic traffic flow
- Protocol anomalies

**Usage**: Detect network-based attacks and reconnaissance

### Threat Intelligence
**Purpose**: Malware and IOC tracking
**Key Widgets**:
- VirusTotal detections
- File integrity monitoring
- Hash reputation lookup
- IOC timeline

**Usage**: Track malware and file-based threats

## Search and Query Guide

### Common Kibana Queries

#### Find Failed SSH Logins
```
rule.id:5716 AND agent.name:"server-name"
```

#### Search for Specific IP Activity
```
srcip:"192.168.1.100" OR dstip:"192.168.1.100"
```

#### Look for VirusTotal Detections
```
rule.groups:"virustotal" AND rule.level:>=7
```

#### Find File Changes
```
rule.groups:"syscheck" AND syscheck.event:"modified"
```

### Time Range Best Practices
- **Real-time monitoring**: Last 15 minutes
- **Shift review**: Last 8-12 hours
- **Incident investigation**: Custom range around event
- **Trend analysis**: Last 7-30 days

## Alert Management

### Severity Levels
- **Level 15**: Critical - Immediate response required
- **Level 10-14**: High - Response within 1 hour
- **Level 7-9**: Medium - Response within 4 hours
- **Level 0-6**: Low - Daily review sufficient

### Alert Lifecycle
1. **New**: Alert generated, awaiting triage
2. **In Progress**: Analyst investigating
3. **Resolved**: Investigation complete, actions taken
4. **False Positive**: Alert marked as non-actionable
5. **Escalated**: Passed to senior analyst/incident response

### Documentation Requirements
For each alert:
- [ ] Classification (TP/FP/Escalated)
- [ ] Investigation summary
- [ ] Actions taken
- [ ] Recommendations for future
- [ ] Analyst signature and timestamp

## Communication Protocols

### Internal Escalation
- **L1 → L2**: Complex technical analysis needed
- **L2 → L3**: Advanced threat investigation
- **Any Level → IR**: Confirmed breach or major incident

### External Communication
- **IT Operations**: Service impacts and outages
- **Management**: High-severity incidents and trends
- **Legal/HR**: Insider threat or policy violations
- **Vendors**: Product security issues

### Documentation Tools
- **Ticketing System**: Primary incident tracking
- **Knowledge Base**: Procedures and playbooks
- **Chat Platforms**: Real-time team coordination
- **Email**: Formal communications and reporting

## Performance Metrics

### Analyst KPIs
- **Mean Time to Triage (MTTT)**: < 30 minutes
- **Mean Time to Resolution (MTTR)**: < 2 hours
- **False Positive Rate**: < 15%
- **Alert Closure Rate**: > 95% within SLA

### Quality Metrics
- **Documentation Completeness**: 100%
- **Escalation Accuracy**: > 90%
- **Procedure Compliance**: 100%
- **Continuous Learning**: Monthly training completion

## Tips for New Analysts

### Best Practices
1. **Always verify before acting** - Confirm findings independently
2. **Document everything** - Future you will thank you
3. **Ask questions** - Senior analysts are there to help
4. **Stay current** - Read threat intelligence regularly
5. **Practice with simulations** - Use the scenario scripts

### Common Mistakes to Avoid
- Dismissing alerts without proper investigation
- Taking response actions without authorization
- Failing to document investigation steps
- Not escalating when unsure
- Ignoring context and baselines

### Continuous Improvement
- Review closed cases for learning opportunities
- Participate in tabletop exercises
- Stay updated on new attack techniques
- Share knowledge with team members
- Suggest process improvements

---
**Last Updated**: September 2025  
**Version**: 1.0