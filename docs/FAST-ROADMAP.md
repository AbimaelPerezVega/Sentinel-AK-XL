# REALISTIC Roadmap - 2 weeks (based on current data)

## Current Data Assessment
**What you have:**
- Only: FIM (syscheck), VirusTotal, basic GeoIP
- Missing: auth logs, network logs, specific sysmon events

---

## Day 1-2: Simulation Scripts (CRITICAL)

### Script 1: SSH Auth Simulator <--- Done
- Generates SSH failure logs in `/var/log/auth.log`
- Different source IPs with GeoIP
- Required for Authentication Dashboard creation

### Script 2: Network Activity Simulator <-- Done
- Generates simulated TCP/UDP connections
- Port scan patterns
- Required to expand Network Dashboard

### Script 3: Malware Drop Simulator   <--- Done
- Creates files in `/var/ossec/data/fimtest`
- Mix of clean/malicious (EICAR variants)
- Expands VirusTotal dashboard data

---

## Day 3-4: Basic Dashboards

### Dashboard 1: Authentication Monitoring (after script 1)
- Failed login attempts by IP
- Geographic auth failures
- Brute force timeline
- Top attacked usernames

### Dashboard 2: Enhanced Network Analysis (duplicate SOC Overview)
- Keep existing: geo map, countries, IPs
- Add: port scanning detection
- Add: connection patterns

---

## Week 2: Attack Simulation + Refinement

### Attack Scenario Scripts:
- Coordinated brute force
- Port scan → file drop → VirusTotal trigger
- Multi-stage geographic attack
- Persistence simulation

### Dashboard Refinement:
- Add attack correlation views
- Timeline analysis
- Investigation workflows

---

## Project Timeline Alignment

### Current Progress Status:
- Week 1-2: Completed (ELK + Wazuh + agents + GeoIP + VirusTotal)
- Week 3: Pending (simulation scripts + dashboards)
- Week 4: Documentation (1-2 days) + presentation prep

### Week 3 Roadmap Mapping:
- Simulation scripts = "Simulate incidents (port scan, malware execution)"
- Dashboards = part of "trigger alerts" (visualize detected incidents)

### Week 4 Documentation Requirements:
- SOC procedure guide: How to investigate each alert type
- Alert workflows: Specific steps for brute force, port scan, malware
- Analyst playbooks: Decision trees for escalation

### Final Deliverables:
- Dashboards: Authentication + Enhanced Network + Threat Intelligence
- Alert workflows: Investigation procedures
- Simulation scripts: 3 main scripts + attack scenarios
- SOC procedure guide: Operational documentation

---

## Key Consideration
Scripts must generate sufficient alert variety to demonstrate different workflows in documentation. Port scan + malware + brute force provides good coverage of common incident types.

**Conclusion:** Scripts must be created FIRST since you currently have only 4 real events (FIM/VT). Without simulation scripts, meaningful authentication or network analysis dashboards cannot be created.