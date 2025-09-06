# SENTINEL - Virtual SOC Scripts

```
███████╗███████╗███╗   ██╗████████╗██╗███╗   ██╗███████╗██╗     
██╔════╝██╔════╝████╗  ██║╚══██╔══╝██║████╗  ██║██╔════╝██║     
███████╗█████╗  ██╔██╗ ██║   ██║   ██║██╔██╗ ██║█████╗  ██║     
╚════██║██╔══╝  ██║╚██╗██║   ██║   ██║██║╚██╗██║██╔══╝  ██║     
███████║███████╗██║ ╚████║   ██║   ██║██║ ╚████║███████╗███████╗
╚══════╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
```

## Quick Start

1. **Setup** (run once):
   ```bash
   ./scripts/setup/install.sh     # Install Docker
   ./scripts/setup/deploy.sh      # Deploy SOC stack
   ./scripts/setup/configure.sh   # Configure integrations
   ```

2. **Daily Operations**:
   ```bash
   ./scripts/start.sh             # Start SOC
   ./scripts/stop.sh              # Stop SOC
   ```

3. **Monitoring**:
   ```bash
   ./scripts/monitoring/status.sh # Check status
   ./scripts/monitoring/health.sh # Health check
   ./scripts/monitoring/logs.sh   # View logs
   ```

4. **Testing**:
   ```bash
   ./scripts/test/validate.sh     # Validate setup
   ./scripts/test/alerts.sh       # Test alerts
   ./scripts/test/integration.sh  # Test integration
   ```

## Access Points

- **Kibana**: http://localhost:5601
- **Wazuh Dashboard**: https://localhost:8443
- **Elasticsearch**: http://localhost:9200

## Structure

```
scripts/
├── setup/          # Installation & deployment
├── monitoring/     # Status & health checks  
├── test/           # Testing & validation
├── start.sh        # Start all services
├── stop.sh         # Stop all services
└── README.md       # This file
```

**Total: 12 scripts** - Simple, clean, functional.
