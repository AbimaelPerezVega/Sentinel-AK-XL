📘 SSH Authentication Simulation Playbook
🎯 Objective

Test Wazuh detection of brute-force SSH attempts.

Validate correlation rules for repeated login failures.

Train analysts on credential attack response.

⚙️ Step-by-Step Execution

Step 1. Copy the script into the Wazuh Manager container

docker cp .\ssh-auth-simulator.sh wazuh.manager:/tmp/


Step 2. Make the script executable and run it

docker compose exec wazuh.manager bash -lc "chmod +x /tmp/ssh-auth-simulator.sh && /tmp/ssh-auth-simulator.sh"


Step 3. Add brute-force attempts (optional)

for i in {1..10}; do
  sshpass -p "WrongPassword" ssh -o StrictHostKeyChecking=no testuser@localhost "exit" || true
done

📊 Expected Results

Multiple Failed password events appear in /var/log/auth.log.

Wazuh raises brute-force alerts.

Correlation rule groups attempts into one incident.

🛡️ SOC Response Workflow

Verify failed logins in /var/log/auth.log.

Check Wazuh dashboard for alerts.

Escalate if attempts are external or persistent.

Recommend blocking malicious IPs (if real scenario).

Document incident with IP, alert ID, and time window.