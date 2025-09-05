# Architecture Overview

## System Architecture

### High-Level Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Endpoints     │    │   SIEM Layer    │    │  Visualization  │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Sysmon    │ │    │ │    Wazuh    │ │    │ │   Kibana    │ │
│ │   Agent     │ │────┼─│   Manager   │ │────┼─│ Dashboard   │ │
│ │             │ │    │ │             │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│                 │    │        │        │    │        │        │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Log Sources │ │    │ │   Indexer   │ │    │ │   ELK       │ │
│ │             │ │    │ │ (OpenSearch)│ │    │ │   Stack     │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Core Components

### 1. Data Collection Layer

#### Wazuh Agents
- **Purpose**: Endpoint monitoring and log collection
- **Location**: Deployed on monitored systems
- **Communication**: Encrypted communication with Wazuh Manager
- **Capabilities**: 
  - File integrity monitoring (FIM)
  - Log collection and forwarding
  - Security configuration assessment (SCA)
  - Vulnerability detection

#### Sysmon Integration
- **Purpose**: Windows endpoint telemetry
- **Events Collected**: Process creation, network connections, file modifications
- **Integration**: Logs forwarded through Wazuh agents
- **Configuration**: Custom rules for SOC-relevant events

### 2. SIEM Processing Layer

#### Wazuh Manager
- **Purpose**: Central SIEM engine
- **Functions**:
  - Rule-based detection
  - Log parsing and normalization
  - Alert generation
  - Threat intelligence enrichment
- **Key Features**:
  - Custom detection rules
  - Decoders for log parsing
  - Integration with external APIs (VirusTotal)

#### Wazuh Indexer (OpenSearch)
- **Purpose**: Data storage and indexing
- **Technology**: OpenSearch (Elasticsearch fork)
- **Indices**: Organized by data type and date
- **Performance**: Optimized for security data patterns

### 3. Analytics and Enrichment

#### Logstash Pipeline
- **Purpose**: Log processing and enrichment
- **Capabilities**:
  - GeoIP enrichment for IP addresses
  - Data transformation and normalization
  - Custom field extraction
  - Output to multiple destinations

#### Threat Intelligence
- **VirusTotal Integration**: File hash reputation lookup
- **GeoIP Database**: Geographic location mapping
- **Custom IOC Lists**: Organization-specific indicators

### 4. Visualization Layer

#### Kibana Dashboards
- **Purpose**: Data visualization and analysis
- **Dashboards**:
  - SOC Overview
  - Authentication Monitoring
  - Network Analysis
  - Threat Intelligence
- **Features**: Real-time data, drill-down capabilities

#### Wazuh Dashboard
- **Purpose**: SIEM-specific interface
- **Features**: Rule management, agent status, compliance monitoring

## Data Flow Architecture

### Primary Data Flow
```
Endpoint Logs → Wazuh Agent → Wazuh Manager → Detection Rules → Alerts
                                     ↓
                               Wazuh Indexer → Wazuh Dashboard
```

### Enrichment Flow
```
Wazuh Manager → Filebeat → Logstash → GeoIP/VirusTotal → Elasticsearch → Kibana
```

## Network Architecture

### Container Network
- **Subnet**: 172.20.0.0/16
- **DNS**: Internal service discovery
- **Security**: Isolated network with controlled access

### Service Endpoints
| Service | Internal IP | External Port | Purpose |
|---------|-------------|---------------|---------|
| Elasticsearch | 172.20.0.10 | 9200 | Data storage |
| Kibana | 172.20.0.11 | 5601 | Visualization |
| Logstash | 172.20.0.12 | 5044 | Log processing |
| Wazuh Manager | 172.20.0.13 | 1514/1515 | SIEM engine |
| Wazuh Indexer | 172.20.0.14 | 9201 | OpenSearch |
| Wazuh Dashboard | 172.20.0.15 | 443 | SIEM interface |

## Security Architecture

### Authentication
- **Wazuh**: Built-in user management
- **ELK Stack**: Basic authentication enabled
- **API Access**: Token-based authentication

### Communication Security
- **Agent-Manager**: Encrypted with pre-shared keys
- **Internal Services**: TLS enabled for production
- **API Calls**: HTTPS with certificate validation

### Data Protection
- **Encryption at Rest**: Available for production deployments
- **Encryption in Transit**: TLS 1.2+ for all communications
- **Access Control**: Role-based permissions

## Scalability Design

### Horizontal Scaling
- **Elasticsearch**: Multi-node clustering support
- **Logstash**: Multiple pipeline instances
- **Wazuh**: Manager clustering capability

### Vertical Scaling
- **Memory**: Configurable heap sizes per service
- **CPU**: Multi-threaded processing
- **Storage**: Configurable retention periods

## High Availability (Future)

### Redundancy Options
- **Elasticsearch Cluster**: Master/data node separation
- **Wazuh Manager**: Active/passive clustering
- **Load Balancing**: Nginx for dashboard access

### Backup Strategy
- **Configuration**: Version controlled in Git
- **Data**: Elasticsearch snapshots
- **Indices**: Automated backup policies

## Monitoring and Health

### Service Health Checks
- Docker health checks for all services
- API endpoint monitoring
- Resource utilization tracking

### Performance Metrics
- **Ingestion Rate**: Events per second
- **Query Performance**: Response times
- **Storage Usage**: Index size and growth

---
**Last Updated**: September 2025  
**Version**: 1.0
