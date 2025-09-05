🔐 SSH Authentication Simulation Playbook

🚨 Purpose: This simulation generates failed SSH login attempts to test Wazuh detection and validate correlation rules for brute-force and credential-stuffing scenarios.
📚 Analysts will practice identifying, validating, and responding to credential-based attacks.

🎯 Objectives

✅ Test Wazuh detection of brute-force SSH attempts.

✅ Validate correlation rules for repeated login failures.

✅ Train SOC analysts on credential attack response.

⚙️ Step-by-Step Execution
📝 Prerequisites

 Wazuh Manager container is running.

 sshpass installed (for brute-force simulation).

 Analyst access to Wazuh dashboard.

🔽 Step 1. Copy the script into the Wazuh Manager container
docker cp ./ssh-auth-simulator.sh wazuh.manager:/tmp/

⚡ Step 2. Make the script executable and run it
docker compose exec wazuh.manager bash -lc "chmod +x /tmp/ssh-auth-simulator.sh && /tmp/ssh-auth-simulator.sh"


💡 Tip: Running the script without arguments simulates a default set of SSH authentication events.

🛠️ Step 3. (Optional) Add custom brute-force attempts
for i in {1..10}; do
  sshpass -p "WrongPassword" ssh -o StrictHostKeyChecking=no testuser@localhost "exit" || true
done

📊 Expected Results
Component	Expected Behavior
/var/log/auth.log	Multiple Failed password and Invalid user entries appear
Wazuh	Raises brute-force alerts based on log patterns
Correlation Rules	Group repeated failures into one incident alert
SOC Dashboard	Displays login failures in Authentication and SOC Overview panels
🛡️ SOC Response Workflow

🔍 Verify failed login events in /var/log/auth.log.

📊 Check Wazuh dashboard for generated brute-force alerts.

🚩 Escalate the incident if:

Attempts originate from external/untrusted IPs.

Activity persists over multiple time windows.

🛠️ Mitigation Recommendations:

Block offending IP addresses (if real-world scenario).

Enforce strong password policies.

Enable multi-factor authentication (MFA).

📝 Document the incident:

Source IP address

Alert ID and rule triggered

Time window of events

Analyst’s response actions

✨ End Result: SOC analysts gain hands-on experience in identifying SSH brute-force attacks, validating correlation rules, and applying effective countermeasures.