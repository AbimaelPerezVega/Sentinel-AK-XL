# 🏗️ Repository Structure

```
sentinel-ak-xl/
├── README.md                     # Main project documentation
├── .gitignore                    # Git ignore file
├── .env.example                  # Environment variables template
├── docker-compose.yml            # Main container orchestration
├── docker-compose-test.yml       # ELK Stack testing configuration
├── setup.sh                      # Initial environment setup script
├── run-scenario.sh               # Scenario management script
├── cleanup.sh                    # Environment reset script
├── health-check.sh               # System health monitoring
│
├── config-patches/               # Configuration management (NEW)
│   ├── README.md                # Config extraction documentation
│   ├── current-working/         # Current working configurations backup
│   ├── github-updates/          # GitHub-ready configuration files
│   ├── original-backup/         # Original configuration backups
│   ├── GITHUB_UPDATE_INSTRUCTIONS.md  # How to update repository
│   ├── CHANGES_ANALYSIS.md      # Analysis of configuration changes
│   ├── extract-working-configs.sh    # Configuration extraction script
│   └── sync-github-configs.sh   # Sync working configs to GitHub
│
├── docs/                         # Documentation directory
│   ├── README.md                # Documentation index
│   ├── user-guide.md            # Analyst training guide
│   ├── admin-guide.md           # Administrative documentation
│   ├── api-reference.md         # API documentation
│   ├── troubleshooting.md       # Common issues and solutions
│   └── architecture.md          # Technical architecture details
│
├── configs/                      # Configuration files
│   ├── elk/                     # ELK stack configurations
│   │   ├── elasticsearch/
│   │   │   ├── elasticsearch.yml  # Fixed for v9.1.2 compatibility
│   │   │   └── jvm.options
│   │   ├── logstash/
│   │   │   ├── logstash.yml
│   │   │   ├── pipelines.yml
│   │   │   └── conf.d/
│   │   │       ├── input.conf
│   │   │       ├── filter.conf
│   │   │       └── output.conf
│   │   └── kibana/
│   │       ├── kibana.yml        # Updated for v9.1.2 compatibility
│   │       └── dashboards/
│   │
│   ├── wazuh/                   # Wazuh rules and settings
│   │   ├── ossec.conf
│   │   ├── rules/
│   │   ├── decoders/
│   │   └── agents/
│   │
│   ├── thehive/                 # TheHive templates and configs
│   │   ├── application.conf
│   │   ├── templates/
│   │   └── analyzers/
│   │
│   ├── cortex/                  # Cortex analyzer configurations
│   │   ├── application.conf
│   │   └── analyzers/
│   │
│   └── shuffle/                 # SOAR workflows and playbooks
│       ├── workflows/
│       └── apps/
│
├── scenarios/                    # Training scenario definitions
│   ├── README.md                # Scenario documentation
│   ├── basic/                   # Entry-level scenarios
│   │   ├── malware-detection/
│   │   ├── failed-logins/
│   │   ├── network-anomalies/
│   │   └── false-positives/
│   ├── intermediate/            # Mid-level complexity
│   │   ├── lateral-movement/
│   │   ├── data-exfiltration/
│   │   ├── privilege-escalation/
│   │   └── multi-stage-attacks/
│   ├── advanced/                # Expert-level scenarios
│   │   ├── apt-campaigns/
│   │   ├── zero-day-exploits/
│   │   ├── supply-chain/
│   │   └── nation-state-ttps/
│   └── templates/               # Scenario templates
│       ├── scenario-template.json
│       └── event-template.json
│
├── agents/                       # Simulated endpoint agents
│   ├── README.md                # Agent documentation
│   ├── linux-agent/            # Linux host simulator
│   │   ├── Dockerfile
│   │   ├── scripts/
│   │   ├── logs/
│   │   └── config/
│   ├── windows-agent/          # Windows host with Sysmon
│   │   ├── Dockerfile
│   │   ├── sysmon/
│   │   ├── scripts/
│   │   └── config/
│   └── network-simulator/      # Network traffic generator
│       ├── Dockerfile
│       ├── traffic-gen/
│       └── pcaps/
│
├── data/                        # Persistent data storage
│   ├── .gitkeep                # Keep directory in git
│   ├── elasticsearch/          # ES data volume
│   ├── wazuh/                  # Wazuh data persistence
│   ├── thehive/                # Case management data
│   ├── cortex/                 # Analysis data
│   └── backups/                # Backup storage
│
├── scripts/                     # Utility scripts
│   ├── install/                # Installation helpers
│   │   ├── check-requirements.sh
│   │   ├── install-docker.sh
│   │   └── setup-firewall.sh
│   ├── management/             # Management utilities
│   │   ├── backup.sh           # Data backup utilities
│   │   ├── restore.sh          # Data restoration
│   │   ├── monitoring.sh       # Health check scripts
│   │   └── logs.sh             # Log management
│   ├── scenarios/              # Scenario management
│   │   ├── load-scenario.sh
│   │   ├── generate-events.sh
│   │   └── reset-environment.sh
│   └── fixes/                  # Configuration fix scripts (NEW)
│       ├── fix-elasticsearch-setting.sh      # Fix ES v9.1.2 settings
│       ├── fix-kibana-authentication.sh      # Fix Kibana auth issues
│       ├── debug-elasticsearch.sh            # ES debugging tool
│       └── elk-stable-fallback.sh            # Fallback to stable version
│
├── tests/                       # Testing framework
│   ├── unit/                   # Unit tests
│   ├── integration/            # Integration tests
│   ├── scenarios/              # Scenario tests
│   └── performance/            # Performance tests
│
└── tools/                       # Additional tools
    ├── data-generators/        # Event generators
    ├── threat-intel/           # Threat intelligence feeds
    └── dashboards/             # Custom dashboards
```