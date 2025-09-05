#!/bin/bash

# crear archivo setup-templates.sh
# For first time set up or
# If you delete the volume of wazuh use this template

curl -k -u "admin:admin" -X PUT "https://localhost:9201/_template/wazuh" -H 'Content-Type: application/json' -d'{
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
}' && echo "Template creado exitosamente"
