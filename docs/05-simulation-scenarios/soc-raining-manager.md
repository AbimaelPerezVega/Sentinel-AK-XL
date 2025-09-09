# SOC Training Manager (`soc-training-manager.sh`)

A menu-driven orchestrator for running SOC training simulations end-to-end on a Wazuh + ELK/Kibana lab. It checks core services, copies scenario scripts into the Wazuh manager container, launches simulations, and helps you reset the environment between exercises.

---

## Features

* **Interactive TUI menu** (no flags to memorize)
* **Dynamic banner** with centered title and **Stealth Mode** indicator
* **Stealth Mode** toggle (suppresses noisy simulator banners/log chatter)
* **Instructor & Student modes**

  * Instructor: pick specific scenarios
  * Student: “Unknown Scenario” with a **session key** for later verification
* **One-click script deployment** into the Wazuh container
* **Environment health checks** (Wazuh, Elasticsearch, Kibana)
* **Data reset util** (deletes `sentinel-logs-*` and `wazuh-alerts-*` indices)
* **Clean, colored logging** and friendly prompts

---



```bash
  /scenario-simulator
  ├── soc-training-manager.sh
  └── scenarios-simulator/
      ├── ssh-auth/ssh-auth-simulator.sh
      ├── network/network-activity-simulator.sh
      └── malware-drop/malware-drop-simulator.sh
```
* Default container names (override in the script if needed):

  * `sentinel-wazuh-manager`
  * `sentinel-elasticsearch`
  * `sentinel-kibana`

---

## Quick Start

```bash
chmod +x soc-training-manager.sh
./soc-training-manager.sh
```

On first run the manager will:

1. Validate prerequisites.
2. **Copy** the three simulators into the Wazuh container (`/usr/local/bin`) and `chmod +x`.
3. Show the main menu.

---

## Main Menu

```
1. Start Training Session
2. Clean Data (Reset Elasticsearch)
3. Check System Status
4. Copy Simulators to Container
5. Toggle Stealth Mode (ON/OFF)
0. Exit
```

### 1) Start Training Session → Scenarios Menu

**Instructor Mode**

* `SSH Brute Force Attack` → runs the SSH auth simulator
* `Network Port Scanning` → runs the network simulator
* `Malware Drop Simulation` → drops clean/EICAR files to FIM path
* `Mixed Attack Scenario` → runs several simulators with offsets

**Student Mode**

* `Unknown Scenario (generates session key)` → picks a random scenario and prints a **Session Key** (e.g., `TRN555`)
* `Verify Session Key` → explain what ran (for grading/review)

Each run prints a reminder to check Kibana: `http://localhost:5601`.

### 2) Clean Data (Reset Elasticsearch)

Deletes all indices that match:

* `sentinel-logs-*`
* `wazuh-alerts-*`

Also clears simulator artifacts inside the Wazuh container:

* `/var/ossec/logs/test/*`
* `/var/ossec/data/fimtest/*`

Prompts for confirmation before proceeding.

### 3) Check System Status

* Verifies the three containers are running
* Checks Elasticsearch cluster health (`green/yellow`)
* Checks Kibana API status

### 4) Copy Simulators to Container

Re-copies and `chmod +x`:

* `ssh-auth/ssh-auth-simulator.sh`
* `network/network-activity-simulator.sh`
* `malware-drop/malware-drop-simulator.sh`

Creates/owns required directories in the container:

* `/var/ossec/logs/test`
* `/var/ossec/data/fimtest` (owned by `wazuh:wazuh`)

### 5) Toggle Stealth Mode

* **OFF (default):** Verbose simulator output (banners + event lines)
* **ON:** Suppresses banners and reduces per-event chatter (manager still tells you what’s being generated).

> If you added the optional persistence patch, the mode is saved in `~/.soc-training.rc`.

---

## What Each Scenario Does

### SSH Authentication Simulator

* Writes SSH failure lines to a log (default `/var/ossec/logs/test/sshd.log`).
* Patterns available: `single_attempt`, `slow_brute`, `fast_brute`, `credential_spray`, `targeted_attack`, `distributed`, `mixed`.
* Simulator log: `/var/log/ssh-auth-simulation.log` (inside container).

### Network Activity Simulator

* Emits iptables/UFW-style lines to `/var/ossec/logs/test/network.log`.
* Patterns: `single_flow`, `udp_probe`, `portscan_fast`, `portscan_slow`, `mixed`.
* Simulator log: `/var/log/network-simulation.log` (inside container).

### Malware Drop Simulator

* Creates a mix of **clean files** and **EICAR** files in `/var/ossec/data/fimtest` for FIM and VirusTotal testing.
* Simulator log: `/var/log/malware-drop-simulation.log` (inside container).

> **Note:** The EICAR string is a standard antivirus test signature; it is **not** malicious code.

---

## Unknown Scenario & Session Keys

* Choosing **Unknown Scenario** generates a `TRN###` key and randomly executes:

  * `ssh_brute`, `network_scan`, `malware_drop`, or `mixed`
* The session is logged on the host at:

  * `/tmp/soc-training-sessions.log`
* Use **Verify Session Key** to reveal the scenario details, event counts, and suggested dashboards.

---

## Typical Workflow

1. **Start services** (docker compose / your stack).
2. Run the manager:

   ```bash
   ./soc-training-manager.sh
   ```
3. **Check System Status** → ensure all green.
4. **Copy Simulators** (first run or after changes).
5. **Start Training Session** → pick a scenario (or Student Mode).
6. Explore in **Kibana** (`http://localhost:5601`).
7. When done: **Clean Data** to reset indices for a fresh run.

---

## Environment & Paths

* Containers:

  * Wazuh: `sentinel-wazuh-manager`
  * Elasticsearch: `sentinel-elasticsearch` (uses `http://localhost:9200`)
  * Kibana: `sentinel-kibana` (checks `http://localhost:5601/api/status`)
* Host log for student sessions:

  * `/tmp/soc-training-sessions.log`
* In-container simulator logs:

  * `/var/log/ssh-auth-simulation.log`
  * `/var/log/network-simulation.log`
  * `/var/log/malware-drop-simulation.log`
* In-container data/log targets:

  * `/var/ossec/logs/test/*.log`
  * `/var/ossec/data/fimtest/*`

---

## Troubleshooting

* **Colors/centering look off**
  Terminal must support ANSI, and `tput` should return a width. If running under non-TTY or narrow windows, centering may adjust. The banner auto-centers using `tput cols`.

* **“Some services are not running”**
  Start your stack (compose or systemd). Confirm container names match those configured at the top of the script.

* **Permission errors writing logs in container**
  The manager ensures dirs exist and sets ownership for FIM. If you changed paths, mirror those changes in your Wazuh agent/manager config.

* **Indices weren’t deleted**
  Ensure Elasticsearch is reachable at `localhost:9200` and your user can `DELETE` indices.

---

## Security Notes

* The simulators emit **synthetic** events and the malware simulator uses the **EICAR** test string, not real malware.
* Only run in **isolated lab environments**.
* Review and version the scripts before using in demos or workshops.

---

## License & Credits

* Internal training tool for Sentinel-style SOC labs.
* ASCII art and structure adapted for clarity in teaching environments.

---

## Shortcuts / One-liners

* Start manager:

  ```bash
  ./soc-training-manager.sh
  ```
* Reset data fast (non-interactive users can adapt `clean_elasticsearch_data()` to skip prompts).
* Re-deploy simulators after edits:

  ```bash
  ./soc-training-manager.sh  # → option 4
  ```

