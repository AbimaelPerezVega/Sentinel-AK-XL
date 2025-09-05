# Sentinel AK-XL Documentation

## Overview

This documentation provides comprehensive guidance for deploying, operating, and maintaining the Sentinel AK-XL Virtual Security Operations Center (SOC) environment.

## Documentation Structure

### 🚀 Getting Started
Start here for installation and initial setup:

- **[Quick Start Guide](01-getting-started/quick-start.md)** - Get your SOC running in 15 minutes
- **[Installation Guide](01-getting-started/installation-guide.md)** - Complete step-by-step installation
- **[System Requirements](01-getting-started/system-requirements.md)** - Hardware and software prerequisites

### 🏗️ Architecture
Understand the system design and components:

- **[Architecture Overview](02-architecture/architecture.md)** - System design, data flow, and component relationships
- **[Project Structure](02-architecture/project-structure.md)** - File organization and directory layout
- **[Data Flow Guide](02-architecture/data-flow.md)** - Log processing and enrichment pipeline

### 👥 Operations
Daily operations and system management:

- **[User Guide](03-operations/user-guide.md)** - For SOC analysts performing daily monitoring and investigation
- **[Admin Guide](03-operations/admin-guide.md)** - For system administrators managing the infrastructure
- **[Troubleshooting](03-operations/troubleshooting.md)** - Common issues and solutions

### 🚨 Analyst Playbooks
Incident response procedures and investigation workflows:

- **[Brute Force Attacks](04-analyst-playbooks/brute-force-attacks.md)** - Response to authentication attacks
- **[Malware Detection](04-analyst-playbooks/malware-detection.md)** - File integrity monitoring and VirusTotal analysis
- **[Network Anomalies](04-analyst-playbooks/network-anomalies.md)** - Port scanning and network reconnaissance response

### 🔧 Technical Reference
APIs, configurations, and technical details:

- **[API Reference](05-api-reference/api-reference.md)** - Elasticsearch, Wazuh, and Kibana API endpoints
- **[Configuration Guides](06-configuration/)** - Detailed configuration for each component
- **[Simulation Scenarios](07-simulation-scenarios/)** - Attack simulation scripts and usage

### 📚 Appendices
Additional resources and reference materials:

- **[Glossary](99-appendices/glossary.md)** - Terms and definitions
- **[Project Objectives](99-appendices/project-objectives.md)** - Educational goals and deliverables
- **[Roadmap](99-appendices/roadmap.md)** - Development timeline and future enhancements

## Quick Navigation

### New Users
1. Check [System Requirements](01-getting-started/system-requirements.md)
2. Follow [Quick Start Guide](01-getting-started/quick-start.md)
3. Read [User Guide](03-operations/user-guide.md)
4. Study [Analyst Playbooks](04-analyst-playbooks/)

### System Administrators
1. Review [Architecture Overview](02-architecture/architecture.md)
2. Follow [Installation Guide](01-getting-started/installation-guide.md)
3. Study [Admin Guide](03-operations/admin-guide.md)
4. Configure monitoring and alerting

### SOC Analysts
1. Read [User Guide](03-operations/user-guide.md)
2. Master [Analyst Playbooks](04-analyst-playbooks/)
3. Practice with simulation scenarios
4. Learn [API Reference](05-api-reference/api-reference.md) for advanced queries

### Developers
1. Understand [Architecture Overview](02-architecture/architecture.md)
2. Review [API Reference](05-api-reference/api-reference.md)
3. Check configuration files in [Technical Reference](05-api-reference/)
4. Contribute to simulation scenarios

## Training Scenarios

The platform includes realistic attack simulations for hands-on learning:

- **SSH Brute Force** - Authentication attack patterns
- **Network Reconnaissance** - Port scanning and host discovery
- **Malware Detection** - File integrity monitoring with VirusTotal
- **Geographic Threat Analysis** - GeoIP-based attack correlation

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
- Create GitHub issue for incorrect or missing information
- Submit pull requests for improvements
- Contact SOC team for clarification

### Technical Support
- Check [Troubleshooting Guide](03-operations/troubleshooting.md) first
- Review relevant playbooks for incident response
- Consult [API Reference](05-api-reference/api-reference.md) for query help
- Contact system administrators for infrastructure issues

### Training and Education
- Follow hands-on scenarios in simulation guides
- Practice with real data using provided scripts
- Join tabletop exercises and purple team activities
- Attend regular SOC training sessions

## Contributing

### Documentation Contributions
1. Fork the repository
2. Create feature branch for documentation updates
3. Follow existing format and style guidelines
4. Test all commands and procedures
5. Submit pull request with clear description

### Code Contributions
1. Review architecture documentation first
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