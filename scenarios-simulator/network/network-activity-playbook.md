🌐 Network Activity Simulation Playbook

🚨 Purpose: This simulation generates suspicious network activity to test IDS/IPS detection (Suricata/Snort) and validate Wazuh correlation rules.
📚 It provides analysts with realistic network scenarios to practice detection, triage, and escalation.

🎯 Objectives

✅ Simulate outbound network traffic patterns.

✅ Validate IDS/IPS detection of anomalies.

✅ Ensure Wazuh correlation rules trigger properly.

⚙️ Step-by-Step Execution
📝 Prerequisites

 Wazuh Manager container is running

 docker compose installed

 IDS/IPS (e.g., Suricata/Snort) integrated with SOC

🔽 Step 1. Copy the script into the Wazuh Manager container
docker cp ./network-activity-simulator.sh wazuh.manager:/tmp/

⚡ Step 2. Make the script executable and run it
docker compose exec wazuh.manager bash -lc "chmod +x /tmp/network-activity-simulator.sh && /tmp/network-activity-simulator.sh"


💡 Tip: Running without arguments executes a default set of simulated events.

🌍 Step 3. Add optional realistic traffic tests
# Simulated IDS-triggering HTTP request
curl http://testmyids.com/ -o /dev/null

# Fake DNS queries
dig suspiciousdomain.com @8.8.8.8

# Burst HTTP requests (simulating scanning or beaconing)
for i in {1..20}; do curl http://example.com -o /dev/null; done

📊 Expected Results
Component	Expected Behavior
IDS/IPS (Suricata/Snort)	Logs traffic anomalies such as scans or suspicious HTTP/DNS traffic
Wazuh	Raises alerts for correlated suspicious activity
SOC Dashboard	Displays alerts in Network Activity and SOC Overview panels
🛡️ SOC Response Workflow

🔍 Confirm alerts in the Wazuh dashboard.

🌐 Cross-check suspicious IPs/domains with threat intelligence feeds.

🚩 Escalate incidents if traffic patterns resemble known C2 (command & control) activity.

🛠️ Tune IDS/IPS rules if gaps are identified in detection.

📝 Document the incident including:

Source & destination IPs

Domain names queried

Timestamp of detection

Analyst response

✨ End Result: Analysts gain confidence in detecting abnormal network behavior, validating correlation rules, and improving IDS/IPS detection accuracy.