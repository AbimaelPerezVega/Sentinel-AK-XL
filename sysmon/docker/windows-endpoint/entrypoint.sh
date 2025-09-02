#!/bin/bash
set -e

echo "=================================="
echo "Windows Endpoint Simulator Starting"
echo "=================================="

# Configuration
WAZUH_MANAGER=${WAZUH_MANAGER:-172.20.0.13}
HOSTNAME=${HOSTNAME:-$(hostname)}
AGENT_NAME=${AGENT_NAME:-"windows-endpoint-sim-$(hostname)"}

echo "Wazuh Manager: $WAZUH_MANAGER"
echo "Agent Name: $AGENT_NAME"
echo "Hostname: $HOSTNAME"

# Configure Wazuh agent
echo "Configuring Wazuh agent..."

# Update ossec.conf with custom configuration
cat > /var/ossec/etc/ossec.conf << OSSEC_EOF
<ossec_config>
  <client>
    <server>
      <address>$WAZUH_MANAGER</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>ubuntu, ubuntu22, ubuntu22.04</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
  </client>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/sysmon-simulator.log</location>
    <alias>sysmon-windows-events</alias>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/auth.log</location>
  </localfile>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/syslog</location>
  </localfile>
</ossec_config>
OSSEC_EOF

# Wait for Wazuh manager to be ready
echo "Waiting for Wazuh Manager to be ready..."
while ! nc -z $WAZUH_MANAGER 1514; do
    echo "Waiting for $WAZUH_MANAGER:1514..."
    sleep 5
done
echo "Wazuh Manager is ready!"

# Start Wazuh agent
echo "Starting Wazuh agent..."
/var/ossec/bin/wazuh-control start

# Wait for agent to start
sleep 5

# Register the agent with the manager
echo "Registering agent with Wazuh Manager..."
/var/ossec/bin/agent-auth -m $WAZUH_MANAGER -A $AGENT_NAME

# Restart agent to apply registration
/var/ossec/bin/wazuh-control restart

# Wait for agent registration
echo "Waiting for agent registration..."
sleep 15

# Start rsyslog for local logging (ignore errors)
service rsyslog start 2>/dev/null || echo "Rsyslog service not available, continuing..."

# Start Sysmon event generator
echo "Starting Sysmon event generator..."
mkdir -p /opt/sysmon-simulator/logs  # <--- AÑADE ESTA LÍNEA
python3 /opt/sysmon-simulator/scripts/sysmon_event_generator.py $WAZUH_MANAGER 30 0 &

echo "=================================="
echo "Windows Endpoint Simulator Ready!"
echo "Generating Sysmon events every 30 seconds"
echo "=================================="

# Keep container running and show logs
tail -f /var/log/sysmon-simulator.log /var/ossec/logs/ossec.log
