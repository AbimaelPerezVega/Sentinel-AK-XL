# Wazuh Dashboard Troubleshooting Guide: wazuh-alerts-* Index Pattern Issues

## Problem Description

The Wazuh Dashboard fails to load properly, displaying error messages related to the `wazuh-alerts-*` index pattern. Common error symptoms include:

- **Template Error**: `No template found for the selected index-pattern title [wazuh-alerts-*]`
- **Index Pattern Error**: `No matching indices found: No indices match pattern "wazuh-alerts-*"`
- **Field Data Error**: `Text fields are not optimised for operations that require per-document field data like aggregations and sorting`

## Root Cause Analysis

### Why This Happens

1. **Missing Index Template**: The Wazuh Dashboard requires an index template to define how `wazuh-alerts-*` indices should be structured. This template is normally created automatically by Filebeat running inside the `wazuh-manager` container during initial setup.

2. **Empty Index Pattern**: Even with a template, the dashboard needs at least one actual index (e.g., `wazuh-alerts-4.x-2025.08.29`) to exist before it can read the field structure.

3. **Incorrect Field Mappings**: If an index was created with the wrong field mappings (e.g., `text` instead of `keyword` fields), aggregations and visualizations will fail.

4. **Container State Issues**: In Docker environments, especially with volume management (`docker compose down -v`), the Wazuh Indexer loses all stored templates and data, requiring manual recreation.

### The Bootstrap Problem

This creates a "chicken and egg" scenario:
- Dashboard needs an index to read field structure
- Index needs alerts to be generated
- Alerts need proper Wazuh Manager configuration
- Manager needs to successfully connect to Indexer
- Indexer needs proper templates to accept the data

## Diagnostic Commands

### 1. Check Wazuh Indexer Connection

```bash
# Test basic connectivity to Wazuh Indexer
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_cluster/health?pretty"
```

### 2. List Existing Templates

```bash
# Check if wazuh template exists
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_cat/templates?v"

# Get specific wazuh template details
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_template/wazuh?pretty"
```

### 3. Check Existing Indices

```bash
# List all wazuh-related indices
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_cat/indices/wazuh-*?v"

# Check specific index mapping
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/wazuh-alerts-4.x-*/_mapping?pretty"
```

### 4. Verify Alert Generation

```bash
# Check if Wazuh Manager is generating alerts
docker compose exec wazuh-manager tail -10 /var/ossec/logs/alerts/alerts.json

# Count total alerts generated
docker compose exec wazuh-manager wc -l /var/ossec/logs/alerts/alerts.json
```

### 5. Test Alert Processing

```bash
# Generate a test alert to verify the pipeline
echo 'Aug 29 21:00:00 ubuntu sshd[1234]: Failed password for root from 1.2.3.4 port 12345 ssh2' \
| docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-logtest
```

## Solution Steps

### Step 1: Create the Missing Index Template

```bash
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" -X PUT "https://localhost:9201/_template/wazuh" \
-H 'Content-Type: application/json' -d'{
  "index_patterns": ["wazuh-alerts-4.x-*"],
  "template": {
    "settings": {
      "index.refresh_interval": "5s",
      "index.number_of_shards": "1",
      "index.number_of_replicas": "0"
    },
    "mappings": {
      "dynamic_templates": [
        {
          "strings_as_keyword": {
            "match_mapping_type": "string",
            "mapping": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            }
          }
        }
      ],
      "properties": {
        "timestamp": {"type": "date"},
        "@timestamp": {"type": "date"}
      }
    }
  }
}'
```

### Step 2: Generate Initial Alert

```bash
# Create a test SSH authentication failure alert
echo 'Aug 29 21:00:00 ubuntu sshd[1234]: Failed password for root from 1.2.3.4 port 12345 ssh2' \
| docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-logtest
```

### Step 3: Verify Index Creation

```bash
# Confirm the index was created with correct structure
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_cat/indices" | grep wazuh-alerts
```

### Step 4: Restart Wazuh Dashboard

```bash
docker compose restart wazuh-dashboard
```

## Critical Issue: Existing Incorrect Indices

**Important**: If you previously created indices with incorrect field mappings, the template will NOT fix existing indices. You must delete them first.

### Delete Incorrect Indices

```bash
# List current indices to identify problematic ones
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_cat/indices/wazuh-*?v"

# Delete specific problematic index
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" -X DELETE "https://localhost:9201/wazuh-alerts-4.x-YYYY.MM.DD"

# Or delete all wazuh-alerts indices (WARNING: This removes all alert data)
curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" -X DELETE "https://localhost:9201/wazuh-alerts-*"
```

### Recreate with Correct Template

After deleting incorrect indices:

1. Ensure the correct template exists (Step 1 above)
2. Generate new alerts (Step 2 above)
3. New indices will be created with correct mappings

## Prevention and Automation

### Persistent Volume Management

```bash
# Avoid losing templates and data - don't use -v flag
docker compose down        # ✅ Preserves volumes
docker compose down -v     # ❌ Deletes all data including templates
```

### Automated Template Setup Script

Create `setup-wazuh-template.sh`:

```bash
#!/bin/bash
echo "Setting up Wazuh template..."
sleep 30  # Wait for services

curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" -X PUT "https://localhost:9201/_template/wazuh" \
-H 'Content-Type: application/json' -d'{
  "index_patterns": ["wazuh-alerts-4.x-*"],
  "template": {
    "settings": {
      "index.refresh_interval": "5s",
      "index.number_of_shards": "1",
      "index.number_of_replicas": "0"
    },
    "mappings": {
      "dynamic_templates": [
        {
          "strings_as_keyword": {
            "match_mapping_type": "string",
            "mapping": {
              "type": "text",
              "fields": {
                "keyword": {
                  "type": "keyword",
                  "ignore_above": 256
                }
              }
            }
          }
        }
      ],
      "properties": {
        "timestamp": {"type": "date"},
        "@timestamp": {"type": "date"}
      }
    }
  }
}' && echo "Template created successfully"

# Generate initial alert
echo 'Aug 29 21:00:00 ubuntu sshd[1234]: Failed password for root from 1.2.3.4 port 12345 ssh2' \
| docker compose exec -T wazuh-manager /var/ossec/bin/wazuh-logtest

echo "Setup complete"
```

Run after starting containers:
```bash
docker compose up -d
chmod +x setup-wazuh-template.sh
./setup-wazuh-template.sh
```

## Common Error Messages and Solutions

| Error Message | Cause | Solution |
|---------------|--------|----------|
| `No template found for the selected index-pattern title [wazuh-alerts-*]` | Missing index template | Create template using Step 1 |
| `No matching indices found: No indices match pattern "wazuh-alerts-*"` | No alerts generated yet | Generate test alert using Step 2 |
| `Text fields are not optimised for operations that require per-document field data` | Incorrect field mappings | Delete existing indices and recreate with correct template |
| `search_phase_execution_exception` | Field data type conflicts | Clear cache or delete/recreate indices |

## Verification Steps

After implementing the solution:

1. **Template exists**: `curl -k -u "dWAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_template/wazuh"`
2. **Index created**: `curl -k -u "WAZUH_INDEXER__user:WAZUH_INDEXER_password" "https://localhost:9201/_cat/indices" | grep wazuh-alerts`
3. **Dashboard loads**: Navigate to `https://localhost:8443` and verify no error messages
4. **Data visible**: Check that alerts appear in the dashboard overview

The dashboard should now load successfully with proper field mappings for aggregations and visualizations.
