# GeoIP Configuration & Troubleshooting Report

## Summary

* **Goal:** Enrich incoming Wazuh/Filebeat events with GeoIP and index them in Elasticsearch under `sentinel-logs-*`.
* **Status:** ✅ GeoIP enrichment is active. Documents now contain a valid `geoip.location` `geo_point` (plus `latitude`/`longitude` as floats).
* **Key Fix:** Stop forcing `geoip.location` to a string and provide a compatible Elasticsearch index template that maps `geoip.location` as `geo_point`.

---

## Architecture (current)

* **Input:**

  * `beats` on `:5044` (Filebeat from `wazuh-manager`)
  * `http` on `:8080` (optional)
* **Filter highlights (Logstash):**

  * Parse JSON if needed (`message` or `event.original`).
  * Add `source_type: wazuh` when `[agent][name]` exists.
  * Use event’s `timestamp` for `@timestamp` (if provided).
  * Choose first available source IP (`[data][srcip]`, `[srcip]`, `[client][ip]`, `[source][ip]`) → `event_src_ip`.
  * **GeoIP** on `event_src_ip` *only* if it looks like IPv4.
* **GeoIP DB:** `/usr/share/logstash/geoip/GeoLite2-City.mmdb`
* **Output:** Elasticsearch `sentinel-logs-%{+YYYY.MM.dd}`, ILM disabled.
* **Index Template:** `sentinel-logs` (composable) mapping `geoip.location` as `geo_point` and `agent.name` with a `keyword` subfield.

---

## Effective Config Snippets

**Logstash filter (essentials):**

```conf
filter {
  # If JSON string is in message or event.original, expand it at root
  if [message] and [message] =~ '^\s*\{' {
    json { source => "message" target => "" }
  } else if [event][original] and [event][original] =~ '^\s*\{' {
    json { source => "[event][original]" target => "" }
  }

  if [agent][name] {
    mutate { add_field => { "source_type" => "wazuh" } }
  }

  if [timestamp] {
    date { match => ["timestamp","ISO8601"] target => "@timestamp" }
    mutate { remove_field => ["timestamp"] }
  }

  if ![event_src_ip] {
    if [data][srcip] {
      mutate { add_field => { "event_src_ip" => "%{[data][srcip]}" } }
    } else if [srcip] {
      mutate { add_field => { "event_src_ip" => "%{[srcip]}" } }
    } else if [client][ip] {
      mutate { add_field => { "event_src_ip" => "%{[client][ip]}" } }
    } else if [source][ip] {
      mutate { add_field => { "event_src_ip" => "%{[source][ip]}" } }
    }
  }

  # GeoIP ONLY if it looks like IPv4
  if [event_src_ip] and [event_src_ip] =~ /^(\d{1,3}\.){3}\d{1,3}$/ {
    geoip {
      source => "event_src_ip"
      target => "geoip"
      database => "/usr/share/logstash/geoip/GeoLite2-City.mmdb"
      ecs_compatibility => disabled
    }
    # IMPORTANT: do not "replace" [geoip][location] as string
  }
}
```

**Elasticsearch index template:**

```bash
curl -s -XPUT 'http://localhost:9200/_index_template/sentinel-logs' \
 -H 'Content-Type: application/json' -d '{
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
            "latitude":  { "type": "float" },
            "longitude": { "type": "float" }
          }
        }
      }
    }
  }
}'
```

---

## What was wrong (symptoms & root cause)

* **Symptom:** Elasticsearch rejected events with:

  > `failed to parse field [geoip.location] of type [geo_point] ... latitude must be a number`
* **Root cause:** The pipeline **overwrote** `geoip.location` as a **string**:

  ```
  replace => { "[geoip][location]" => "%{[geoip][longitude]},%{[geoip][latitude]}" }
  ```

  That yields a string literal with unresolved `%{}` when lookup fails, or a string `"lon,lat"` which can conflict with ECS/GeoIP’s default object form.
* **Also:** No index template initially mapping `geoip.location` as `geo_point` on `sentinel-logs-2025.08.29`, causing strict parsing with incompatible shape.

---

## Fixes applied

1. **Removed the `replace` of `[geoip][location]`**
   Let the GeoIP filter produce the ECS-compatible structure:

   ```json
   "geoip": {
     "location": { "lat": 37.751, "lon": -97.822 },
     "latitude": 37.751, "longitude": -97.822, ...
   }
   ```
2. **Created an index template** (`sentinel-logs`) that:

   * Maps `geoip.location` as `geo_point`
   * Ensures `agent.name.keyword` exists for exact term filters
3. **Recreated the daily index** (delete the broken one) so the new template could apply.
4. **Validated** with search queries that `geoip.location` exists and is usable.

---

## Validation (how we confirmed it works)

* Search by message and inspect geo fields:

```bash
curl -s "http://localhost:9200/sentinel-logs-*/_search?q=msg:fb-ts%20smoke&size=3&sort=@timestamp:desc" \
| jq '{total:.hits.total, hits:(.hits.hits | map(._source | {ts:.["@timestamp"], msg:.msg, ip:.event_src_ip, tags, geo:.geoip}))}'
```

* Ensure a document **has** `geoip.location`:

```bash
curl -s 'http://localhost:9200/sentinel-logs-*/_search' \
 -H 'Content-Type: application/json' -d '{
  "size": 1,
  "query": {"exists": {"field": "geoip.location"}},
  "sort": [{"@timestamp":{"order":"desc"}}]
}' | jq '.hits.hits[0]?._source | {ts:.["@timestamp"], ip:.event_src_ip, geo:.geoip, tags}'
```

* Check the index mapping for `geo_point`:

```bash
curl -s 'http://localhost:9200/sentinel-logs-*/_mapping' \
| jq 'to_entries[] | {index: .key, geo_type: .value.mappings.properties.geoip.properties.location.type}'
```

---

## Troubleshooting Playbook

1. **Check pipeline loaded & reloaded**

   * Hash/workers:

     ```bash
     curl -s http://localhost:9600/_node/pipelines?pretty | jq '.pipelines.main | {hash, workers, batch_size}'
     ```
   * Restart Logstash:

     ```bash
     docker compose restart logstash
     ```

2. **Tail Logstash logs for indexing errors**

   ```bash
   docker logs -f sentinel-logstash
   ```

   Look for `Could not index event` and parse exceptions.

3. **Inspect mappings & templates**

   * Templates:

     ```bash
     curl -s 'http://localhost:9200/_cat/templates/sentinel-logs*?v'
     curl -s 'http://localhost:9200/_index_template/sentinel-logs?pretty'
     ```
   * Simulate which template applies:

     ```bash
     curl -s 'http://localhost:9200/_index_template/_simulate_index/sentinel-logs-2099.01.01?pretty'
     ```
   * Current index mapping:

     ```bash
     curl -s 'http://localhost:9200/sentinel-logs-*/_mapping' | jq .
     ```

4. **If mapping is wrong on today’s index**

   * Delete the daily index (not the template):

     ```bash
     curl -s -XDELETE "http://localhost:9200/sentinel-logs-$(date -u +%Y.%m.%d)"
     ```
   * Ingest a new event and `_refresh`:

     ```bash
     curl -s -XPOST 'http://localhost:9200/_refresh' >/dev/null
     ```

5. **Verify GeoIP plugin behavior**

   * Ensure the DB exists in the container:

     ```
     /usr/share/logstash/geoip/GeoLite2-City.mmdb
     ```
   * If you see `_geoip_lookup_failure` tag, common causes:

     * IP missing/invalid (e.g., not IPv4 while filter expects IPv4)
     * DB path wrong or file missing
     * Field name mismatch (GeoIP `source` not found)

6. **Generate a controlled test event (from wazuh-manager)**

   ```bash
   docker compose exec wazuh-manager bash -lc '
   TOK=$(date -u +%Y%m%d%H%M%S);
   printf "{\"timestamp\":\"%s\",\"agent\":{\"name\":\"wazuh-manager\"},\"srcip\":\"8.8.8.8\",\"msg\":\"fb-ts smoke %s\"}\n" \
     "$(date -u +%FT%TZ)" "$TOK" >> /var/ossec/logs/alerts/alerts.json;
   echo $TOK
   '
   ```

7. **Elasticsearch basics**

   * Force refresh:

     ```bash
     curl -s -XPOST 'http://localhost:9200/_refresh' >/dev/null
     ```
   * Count / search:

     ```bash
     curl -s 'http://localhost:9200/sentinel-logs-*/_count?q=msg:"fb-ts smoke"'
     curl -s 'http://localhost:9200/sentinel-logs-*/_search?q=msg:fb-ts%20smoke&size=1&sort=@timestamp:desc'
     ```

---

## Useful Commands (cheat sheet)

**Docker & services**

```bash
docker compose ps
docker compose restart logstash
docker logs -f sentinel-logstash
```

**Elasticsearch indices & mappings**

```bash
curl -s 'http://localhost:9200/_cat/indices/sentinel-logs-*?v'
curl -s 'http://localhost:9200/sentinel-logs-*/_mapping' | jq .
curl -s -XDELETE "http://localhost:9200/sentinel-logs-$(date -u +%Y.%m.%d)"
```

**Templates**

```bash
curl -s 'http://localhost:9200/_cat/templates?v'
curl -s 'http://localhost:9200/_index_template?pretty'
curl -s 'http://localhost:9200/_index_template/sentinel-logs?pretty'
curl -s -XDELETE 'http://localhost:9200/_index_template/sentinel-logs'
curl -s 'http://localhost:9200/_index_template/_simulate_index/sentinel-logs-2099.01.01?pretty'
```

**Search examples**

```bash
curl -s "http://localhost:9200/sentinel-logs-*/_search?q=msg:fb-ts%20smoke&size=3&sort=@timestamp:desc" | jq .
curl -s 'http://localhost:9200/sentinel-logs-*/_search' -H 'Content-Type: application/json' -d '{
  "size": 1,
  "query": { "exists": { "field": "geoip.location" } },
  "sort": [{ "@timestamp": { "order": "desc" } }]
}' | jq .
```

---

## Recommendations / Next Steps

* Keep the **GeoIP block simple**; don’t rewrite `geoip.location`.
* If you need IPv6 enrichment, add a second conditional (or broaden the regex) and ensure your GeoIP DB supports IPv6.
* Consider adding a **Kibana map** visualization using `geoip.location` to verify visually.
* If you change mappings later, update the **template** first, then **recreate** indices to apply it.
