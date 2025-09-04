📘 Network Activity Simulation Playbook
🎯 Objective

Simulate suspicious outbound network traffic.

Validate IDS/IPS detection (Suricata/Snort).

Test Wazuh correlation rules.

⚙️ Step-by-Step Execution

Step 1. Copy the script into the Wazuh Manager container

docker cp .\network-activity-simulator.sh wazuh.manager:/tmp/


Step 2. Make the script executable and run it

docker compose exec wazuh.manager bash -lc "chmod +x /tmp/network-activity-simulator.sh && /tmp/network-activity-simulator.sh"


Step 3. Add realistic traffic tests (optional)

# Simulated IDS-triggering HTTP request
curl http://testmyids.com/ -o /dev/null

# Fake DNS queries
dig suspiciousdomain.com @8.8.8.8

# Burst requests
for i in {1..20}; do curl http://example.com -o /dev/null; done

📊 Expected Results

IDS/IPS logs traffic anomalies.

Wazuh raises alerts for suspicious activity.

SOC correlation rules are validated.

🛡️ SOC Response Workflow

Confirm alerts in Wazuh dashboard.

Cross-check with threat intel feeds.

Escalate if traffic mimics known C2 behavior.

Tune IDS/IPS rules if detection gaps exist.

Document incident with timestamps and IPs.