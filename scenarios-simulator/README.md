# 🛡️ Sentinel AK-XL SOC - Scenario Simulators

This directory contains a suite of **Bash scripts** designed to generate realistic security event logs for the **Sentinel SOC** environment. These simulators help test the entire data pipeline, from log generation and collection by **Wazuh** to analysis, alerting, and visualization in the SOC dashboards.

**Key Objective:** Populate the SOC dashboards with meaningful data for training, demonstration, and validation of the monitoring and detection rules.

> [!IMPORTANT]   
> All scripts must be executed **inside the wazuh-manager Docker container** to ensure they can write to the correct log files monitored by Wazuh.

---

## 1. 🔐 SSH Authentication Simulator

**File:** `ssh-auth/ssh-auth-simulator.sh`

This script simulates a variety of **SSH authentication failure events**, which are common indicators of brute-force attacks or unauthorized access attempts. The logs are written in a standard format compatible with `/var/log/auth.log`.

### Features

- Generates logs for failed passwords, invalid users, and connection resets.  
- Uses a curated list of international IP addresses to test **GeoIP functionality**.  
- Supports attack patterns: **single_attempt, fast/slow brute force, credential spraying, targeted attacks, distributed, mixed**.  
- Populates the **"Authentication"** and **"SOC Overview"** dashboards.  

### How to Use

Copy the script to the container:

```bash
docker cp ./scenarios-simulator/ssh-auth/ssh-auth-simulator.sh sentinel-wazuh-manager:/usr/local/bin/ssh-auth-simulator.sh
````

Make it executable:

```bash
docker exec sentinel-wazuh-manager chmod +x /usr/local/bin/ssh-auth-simulator.sh
```

Run the simulation:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator.sh [OPTIONS]
```

### Example Usage

* Generate 50 mixed SSH failure events:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator.sh -n 50 -p mixed
```

* Run continuous fast brute-force simulation:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator.sh -c -p fast_brute -d 1-3
```

* Simulate a targeted attack on admin accounts:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator.sh -p targeted_attack -n 25 -v
```

* Dry run (show events without writing logs):

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/ssh-auth-simulator.sh --dry-run -n 10
```

---

## 2. 🌐 Network Activity Simulator

**File:** `network/network-activity-simulator.sh`

This script generates **iptables-style firewall drop logs**, essential for testing network security monitoring rules, including **port scan detection**.

### Features

* Simulates TCP and UDP connections dropped by a firewall.
* Uses international IPs to populate the **GeoIP world map**.
* Includes patterns: **single\_flow, portscan\_fast, portscan\_slow, udp\_probe, mixed**.
* Populates the **"Network"** and **"SOC Overview"** dashboards.

### How to Use

Copy the script to the container:

```bash
docker cp ./scenarios-simulator/network/network-activity-simulator.sh sentinel-wazuh-manager:/usr/local/bin/network-activity-simulator.sh
```

Make it executable:

```bash
docker exec sentinel-wazuh-manager chmod +x /usr/local/bin/network-activity-simulator.sh
```

Run the simulation:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/network-activity-simulator.sh [OPTIONS]
```

### Example Usage

* Generate 30 mixed firewall drop events:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/network-activity-simulator.sh -n 30 -p mixed
```

* Simulate a fast port scan:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/network-activity-simulator.sh -p portscan_fast
```

* Run continuous UDP probe simulation:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/network-activity-simulator.sh -c -p udp_probe -d 0-1
```

---

## 3. 🦠 Malware Drop Simulator

**File:** `malware-drop/malware-drop-simulator.sh`

This script tests the **File Integrity Monitoring (FIM)** capabilities of Wazuh (`syscheck`) and the **VirusTotal integration**.

### Features

* Creates files in a directory monitored by Wazuh FIM (`/var/ossec/data/fimtest`).
* Generates FIM alerts for *"file added"*.
* Triggers the **VirusTotal integration**, scanning the hash of new files.
* Generates high-severity alerts when an **EICAR test file** (simulated malware) is detected.
* Populates the **"Threat Intelligence"** and **"FIM"** dashboards.

### How to Use

Copy the script to the container:

```bash
docker cp ./scenarios-simulator/malware-drop/malware-drop-simulator.sh sentinel-wazuh-manager:/usr/local/bin/malware-drop-simulator.sh
```

Make it executable:

```bash
docker exec sentinel-wazuh-manager chmod +x /usr/local/bin/malware-drop-simulator.sh
```

Run the simulation (arguments: `[number_of_files] [malicious_ratio]`):

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/malware-drop-simulator.sh 10 3
```

### Example Usage

* Create 10 files, 1 in every 3 malicious:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/malware-drop-simulator.sh 10 3
```

* Create 20 files, 1 in every 5 malicious:

```bash
docker exec sentinel-wazuh-manager /usr/local/bin/malware-drop-simulator.sh 20 5
```

* Clean up generated files:

```bash
docker exec sentinel-wazuh-manager rm -f /var/ossec/data/fimtest/*
```

---

## 📊 Simulator Comparison

| Simulator        | Purpose                                           | Log Path                                               | Example Pattern        |
| ---------------- | ------------------------------------------------- | ------------------------------------------------------ | ---------------------- |
| **SSH Auth**     | Brute-force, credential spraying, targeted logins | `/var/log/auth.log` or `/var/ossec/logs/test/sshd.log` | `-p fast_brute`        |
| **Network**      | Firewall drops, TCP/UDP scans                     | `/var/ossec/logs/test/network.log`                     | `-p portscan_fast`     |
| **Malware Drop** | File changes + VirusTotal integration             | `/var/ossec/data/fimtest`                              | `10 3` (files + ratio) |

---

✅ With these simulators, you can populate your SOC dashboards with **realistic attack scenarios**, train analysts, and validate detection rules in a controlled environment.

```

---
