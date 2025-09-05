#Plantilla de índice

Para que todos los índices diarios mantengan el mismo mapping (sobre todo geoip.location como geo_point) y agent.name.keyword exista para términos exactos:

```bash
curl -s -XPUT 'http://localhost:9200/_index_template/sentinel-logs' -H 'Content-Type: application/json' -d '{
  "index_patterns": ["sentinel-logs-*"],
  "template": {
    "mappings": {
      "properties": {
        "agent": {
          "properties": {
            "name": {
              "type": "text",
              "fields": { "keyword": { "type": "keyword", "ignore_above": 256 } }
            }
          }
        },
        "geoip": {
          "properties": {
            "location": { "type": "geo_point" },
            "latitude":  { "type": "float"   },
            "longitude": { "type": "float"   }
          }
        }
      }
    }
  }
}'

```