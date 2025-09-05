# Sentinel AK-XL Documentation

## Overview

This documentation provides comprehensive guidance for deploying, operating, and maintaining the Sentinel AK-XL Virtual Security Operations Center (SOC) environment.

## Documentation Structure

### 🚀 Getting Started
Start here for installation and initial setup:

- **[Quick Start Guide](01-getting-started/quick-start-guide.md)** - Get your SOC running in 15 minutes
- **[Quick Start Cheat Sheet](01-getting-started/quick-start-cheat-sheet.md)** - Command reference for rapid deployment
- **[Installation Guide](01-getting-started/installation-guide.md)** - Complete step-by-step installation
- **[System Requirements](01-getting-started/system-requirements.md)** - Hardware and software prerequisites

### 🏗️ Architecture
Understand the system design and components:

- **[Architecture Overview](02-architecture/architecture.md)** - System design, data flow, and component relationships
- **[Project Structure](02-architecture/project-Structure.md)** - File organization and directory layout
- **[Data Flow Guide](02-architecture/data-flow.md)** - Log processing and enrichment pipeline

### 👥 Operations
Daily operations and system management:

- **[SOC Analyst User Guide](03-operations/soc-analyst-user-guide.md)** - For SOC analysts performing daily monitoring and investigation
- **[System Administrator Guide](03-operations/system-administrator-guide.md)** - For system administrators managing the infrastructure
- **[Commands Reference](03-operations/commands-reference.md)** - Essential command-line operations
- **[Troubleshooting](03-operations/troubleshooting.md)** - Common issues and solutions

### 🚨 Analyst Playbooks
Incident response procedures and investigation workflows:

- **[Brute Force Attacks](04-analyst-playbooks/brute-force-attacks.md)** - Response to authentication attacks
- **[Malware Detection](04-analyst-playbooks/malware-detection.md)** - File integrity monitoring and VirusTotal analysis
- **[Network Anomalies](04-analyst-playbooks/network-anomalies.md)** - Port scanning and network reconnaissance response

### 🎯 Simulation Scenarios
Attack simulation scripts and training scenarios:

- **[Scenario Overview](05-simulation-scenarios/scenario-overview.md)** - Training scenarios and objectives
- **[SSH Authentication](05-simulation-scenarios/ssh-authentication/ssh-auth-simulator-guide.md)** - SSH brute force attack simulation
- **[Malware Simulation](05-simulation-scenarios/malware-simulation/malware-drop-simulation-guide.md)** - File integrity monitoring with VirusTotal
- **[Network Attacks](05-simulation-scenarios/network-attacks/network-attacks-simulation-guide.md)** - Port scanning and network reconnaissance

### 🔧 Configuration
System configuration and integration guides:

- **[Integrations](06-configuration/integrations/)**
  - [GeoIP Setup](06-configuration/integrations/geoip-setup.md) - Geographic IP enrichment
  - [VirusTotal Setup](06-configuration/integrations/virus-total-setup.md) - Threat intelligence integration
- **[Kibana Configuration](06-configuration/kibana/)**
  - [Dashboard Collaboration Guide](06-configuration/kibana/Dashboard-Collaboration-Guide.md)
  - [Dashboard Technical Specifications](06-configuration/kibana/Dashboard-Technical-Specifications.md)
  - [Dashboards & Visualizations Guide](06-configuration/kibana/Dashboards-&-Visualizations-Guide.md)
- **[Sysmon Configuration](06-configuration/sysmon/sysmon-agent-installation.md)** - Windows endpoint monitoring
- **[Wazuh Configuration](06-configuration/wazuh/wazuh-dashboard-troubleshooting-guide.md)** - SIEM troubleshooting

### 📚 Appendices
Additional resources and reference materials:

- **[Glossary](99-appendices/glossary.md)** - Terms and definitions
- **[Project Objectives](99-appendices/project-objectives.md)** - Educational goals and deliverables
- **[Roadmap](99-appendices/roadmap.md)** - Development timeline and future enhancements

## Quick Navigation

### New Users
1. Check [System Requirements](01-getting-started/system-requirements.md)
2. Follow [Quick Start Guide](01-getting-started/quick-start-guide.md)
3. Read [SOC Analyst User Guide](03-operations/soc-analyst-user-guide.md)
4. Study [Analyst Playbooks](04-analyst-playbooks/)

### System Administrators
1. Review [Architecture Overview](02-architecture/architecture.md)
2. Follow [Installation Guide](01-getting-started/installation-guide.md)
3. Study [System Administrator Guide](03-operations/system-administrator-guide.md)
4. Configure monitoring and alerting using [Configuration Guides](06-configuration/)

### SOC Analysts
1. Read [SOC Analyst User Guide](03-operations/soc-analyst-user-guide.md)
2. Master [Analyst Playbooks](04-analyst-playbooks/)
3. Practice with [Simulation Scenarios](05-simulation-scenarios/)
4. Use [Commands Reference](03-operations/commands-reference.md) for daily operations

### Developers
1. Understand [Architecture Overview](02-architecture/architecture.md)
2. Review [Data Flow Guide](02-architecture/data-flow.md)
3. Check [Configuration Guides](06-configuration/) for integration details
4. Contribute to [Simulation Scenarios](05-simulation-scenarios/)

## Training Scenarios

The platform includes realistic attack simulations for hands-on learning:

- **SSH Brute Force** - Authentication attack patterns and geographic analysis
- **Network Reconnaissance** - Port scanning and host discovery techniques
- **Malware Detection** - File integrity monitoring with VirusTotal integration
- **Geographic Threat Analysis** - GeoIP-based attack correlation and mapping

## Core Technologies

- **ELK Stack 9.1.2** - Log aggregation and visualization
- **Wazuh 4.12.0** - SIEM detection engine
- **Docker** - Containerized deployment
- **Sysmon** - Windows endpoint monitoring
- **VirusTotal API** - Threat intelligence integration
- **GeoIP** - Geographic enrichment

## Documentation Standards

### Format Guidelines
- All documentation in Markdown format
- English language throughout
- Clear headings and section structure
- Code blocks with appropriate syntax highlighting
- Tables for structured data
- Consistent terminology (see [Glossary](99-appendices/glossary.md))

### Content Standards
- Procedural steps numbered and actionable
- Command examples tested and verified
- Screenshots included where helpful
- Cross-references between related documents
- Regular updates with version tracking

### Maintenance
- Documents reviewed monthly for accuracy
- Version controlled with Git
- Issue tracking for documentation bugs
- Community contributions welcome

## Getting Help

### Documentation Issues
- Create GitHub issue for incorrect or missing information: https://github.com/AbimaelPerezVega/Sentinel-AK-XL/issues
- Submit pull requests for improvements
- Contact SOC team for clarification

### Technical Support
- Check [Troubleshooting Guide](03-operations/troubleshooting.md) first
- Review relevant playbooks for incident response
- Consult [Commands Reference](03-operations/commands-reference.md) for operational help
- Contact system administrators for infrastructure issues

### Training and Education
- Follow hands-on scenarios in [Simulation Scenarios](05-simulation-scenarios/)
- Practice with real data using provided scripts
- Join tabletop exercises and purple team activities
- Attend regular SOC training sessions

## Contributing

### Documentation Contributions
1. Fork the repository: https://github.com/AbimaelPerezVega/Sentinel-AK-XL
2. Create feature branch for documentation updates
3. Follow existing format and style guidelines
4. Test all commands and procedures
5. Submit pull request with clear description

### Code Contributions
1. Review [Architecture Overview](02-architecture/architecture.md) first
2. Test changes in development environment
3. Update relevant documentation
4. Follow security best practices
5. Submit pull request with tests

### Feedback
- Suggest improvements to existing procedures
- Report unclear or confusing sections
- Share lessons learned from real incidents
- Propose new training scenarios

---

**Version**: 1.0  
**Last Updated**: September 2025  
**Maintained By**: Sentinel AK-XL SOC Team  
**Repository**: https://github.com/AbimaelPerezVega/Sentinel-AK-XL