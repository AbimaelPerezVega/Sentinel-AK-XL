# 🗺️ Sentinel AK-XL - Component Roadmap

## ✅ **Phase 1 & 2: Core Infrastructure (Completed)**

### Core ELK Stack ✅
- **Elasticsearch**: Fully functional and stable.
- **Logstash**: Fully functional, processing data correctly.
- **Kibana**: Fully functional, data view created and ready for dashboards.

### Configuration & Scripts ✅
- **Docker Compose**: Stable, configured, and tested.
- **Configuration Files**: All ELK configs are created and version-compatible.
- **Environment**: Environment variables are set up.
- **Scripts**: Unified setup (`create-perfect-setup.sh`) and management (`start-elk.sh`, `status-elk.sh`) scripts are complete.

---

## 🚧 **What's Next: Future Phases**

### Phase 3: SIEM & Detection (High Priority)
- [ ] **Wazuh Manager**: Integrate the main HIDS.
- [ ] **Wazuh Dashboard**: Set up the Wazuh interface in Kibana.
- [ ] **Detection Rules**: Create custom rules for Wazuh.
- [ ] **Agent Simulation**: Deploy simulated endpoints to generate data.

### Phase 4: Incident Response (Medium Priority)
- [ ] **TheHive**: Set up the case management platform.
- [ ] **Cortex**: Integrate the observable analysis engine.
- [ ] **Case Templates**: Create templates for common incident types.
- [ ] **Playbooks**: Develop standardized response procedures.

### Phase 5: Automation & SOAR (Low Priority)
- [ ] **Shuffle**: Implement the SOAR orchestration tool.
- [ ] **Ansible**: Develop automated response playbooks.
- [ ] **Workflow Templates**: Create automated response workflows.

### Phase 6: Training Scenarios (High Importance)
- [ ] **Scenario Engine**: Build a script to launch and manage scenarios.
- [ ] **Event Generators**: Create scripts to simulate attacks.
- [ ] **Training Data**: Develop realistic synthetic data sets.
- [ ] **Progress Tracking**: Implement a way to track analyst training progress.

---

## 🎯 **Immediate Next Steps**

### 1. Kibana Dashboard Creation (This Week) 📊
- **Task**: Design and create the main SOC dashboards, visualizations, and graphs.
- **Owner**: [Teammate's Name]
- **Action**: Use the Kibana UI to build the dashboards and the `sync-dashboards.sh` script to commit the `.ndjson` file to the repository.

### 2. Wazuh Integration (This Week) 🛡️
- **Task**: Add the Wazuh Manager and Wazuh Dashboard services to `docker-compose.yml`.
- **Action**:
    - Configure the Wazuh Manager (`ossec.conf`).
    - Connect Wazuh to the existing Elasticsearch instance.
    - Verify that Wazuh alerts appear in Kibana.

### 3. Basic Training Scenarios (Next Week) 🎮
- **Task**: Develop the first simple training scenarios.
- **Action**:
    - Simulate basic malware alerts.
    - Generate brute-force attack logs.
    - Simulate lateral movement patterns.

---

## 📊 **Current Project Status**

```
Overall Progress: ███░░░░░░░░░░░ 25%

✅ Core Infrastructure: ████████████ 100%
✅ ELK Stack Setup:   ████████████ 100%
🚧 SIEM (Wazuh):      ░░░░░░░░░░░░   0%
🚧 Incident Response: ░░░░░░░░░░░░   0%
🚧 SOAR:              ░░░░░░░░░░░░   0%
🚧 Training Content:  ░░░░░░░░░░░░   0%
```

## 🎯 **Definition of "Done"**

For the project to be considered ready for its first training simulation:

1.  **Core SOC** ✅
    - [x] Elasticsearch is running.
    - [x] Logstash is processing events.
    - [x] Kibana is 100% functional.
    - [ ] Basic SOC dashboards are configured.

2.  **Detection & Response**
    - [ ] Wazuh is detecting threats from agents.
    - [ ] TheHive is creating cases from alerts.
    - [ ] At least 10+ detection rules are configured.

3.  **Training Environment**
    - [ ] At least 5+ training scenarios are available.
    - [ ] Realistic synthetic data can be generated.
    - [ ] Training guides for analysts are written.

4.  **Ease of Use** ✅
    - [x] Installation is handled by the setup script.
    - [x] The `README.md` provides complete documentation.
    - [x] A troubleshooting guide is available.

