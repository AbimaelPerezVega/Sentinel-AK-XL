## 1. Enhanced Network Analysis 📈
**Primary Data Source:** `sentinel-logs-*`

* **Visualization: Port-scan Heatmap (SrcIP × DstPort)**
    * **Type:** Heatmap
    * **X-Axis:** `Top 15` values of the `data.srcip.keyword` field.
    * **Y-Axis:** `Top 25` values of the `data.dstport.keyword` field.
    * **Metric (Value):** `Count` of records.
    * **Applied Filters:**
        * `data.action.keyword` is `IPTABLES-DROP:`
        * `data.protocol.keyword` is `TCP`

* **Visualization: Top destination ports targeted**
    * **Type:** Horizontal Bar Chart
    * **Y-Axis (Categories):** `Top 10` values of `data.dstport.keyword`.
    * **X-Axis (Metric):** `Count` of records.
    * **Breakdown by:** `Top 3` values of `data.protocol.keyword`.
    * **Applied Filters:** None.

* **Visualization: Distinct ports over time (by src IP)**
    * **Type:** Line Chart
    * **X-Axis:** Date histogram on the `@timestamp` field.
    * **Y-Axis (Metric):** `Unique Count` of the `data.dstport.keyword` field.
    * **Breakdown by:** `Top 5` values of `data.srcip.keyword`.
    * **Applied Filters:**
        * `data.action.keyword` is `IPTABLES-DROP:`
        * `data.protocol.keyword` is `TCP`

* **Visualization: Targeted Hosts**
    * **Type:** Heatmap
    * **X-Axis:** `Top 15` values of the `data.srcip.keyword` field.
    * **Y-Axis:** `Top 15` values of the `data.dstip.keyword` field.
    * **Metric (Value):** `Count` of records.
    * **Applied Filters:**
        * `data.action.keyword` is `IPTABLES-DROP:`
        * `data.protocol.keyword` is `TCP`

* **Visualization: Possible Port Scanners (last 15m)**
    * **Type:** Data Table
    * **Column 1 (Group by):** `Top 10` values of `data.srcip.keyword`.
    * **Column 2 (Metric):** `Unique Count` of `data.dstport.keyword`.
    * **Applied Filters:** `data.action.keyword` is `IPTABLES-DROP:`.

* **Visualization: Connections by protocol & action**
    * **Type:** Heatmap
    * **X-Axis:** `Top 5` values of `data.action.keyword`.
    * **Y-Axis:** `Top 10` values of `data.protocol.keyword`.
    * **Metric (Value):** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Source IPs by Country**
    * **Type:** Geographic Map
    * **Layer:** `Top 5` countries based on the `geoip.country_code2.keyword` field.
    * **Metric (Color):** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Top Source IPs**
    * **Type:** Bar Chart
    * **X-Axis:** `Top 10` values of `event_src_ip.keyword`.
    * **Y-Axis (Metric):** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Top Source Countries**
    * **Type:** Data Table
    * **Column 1 (Group by):** `Top 10` values of `geoip.country_name.keyword`.
    * **Column 2 (Metric):** `Count` of records.
    * **Applied Filters:** None.

---
## 2. Authentication Monitoring 🛡️
**Primary Data Source:** `sentinel-logs-*`

* **Visualization: Country → IP drill-down**
    * **Type:** Data Table
    * **Row 1 (Group by):** `Top 7` values of `geoip.country_name.keyword`.
    * **Row 2 (Sub-group by):** `Top 10` values of `data.srcip.keyword`.
    * **Metric:** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Failed login attempts by Source IP**
    * **Type:** Bar Chart
    * **X-Axis:** `Top 10` values of `data.srcip.keyword`.
    * **Y-Axis (Metric):** `Count` of records.
    * **Applied Filters:** `location.keyword` is `/var/ossec/logs/test/sshd.log`.

* **Visualization: Geographic distribution of SSH failures**
    * **Type:** Geographic Map
    * **Layer:** `Top 10` countries based on `geoip.country_code2.keyword`.
    * **Metric (Color):** `Count` of records.
    * **Applied Filters:** `location.keyword` is `/var/ossec/logs/test/sshd.log`.

* **Visualization: Top targeted usernames**
    * **Type:** Horizontal Bar Chart
    * **Y-Axis (Categories):** `Top 10` values of `data.srcuser.keyword`.
    * **X-Axis (Metric):** `Count` of records.
    * **Applied Filters:** `location.keyword` is `/var/ossec/logs/test/sshd.log`.

* **Visualization: Brute-force activity over time (by Source IP)**
    * **Type:** Line Chart
    * **X-Axis:** Date histogram on `@timestamp` (hourly interval).
    * **Y-Axis - Metric 1:** `Count` of records.
    * **Y-Axis - Metric 2:** `Unique Count` of `data.srcip.keyword`.
    * **Applied Filters:** None.

---
## 3. Sentinel SOC Overview 📊
**Primary Data Source:** `sentinel-logs-*`

* **Visualization: (KPI Total Events)**
    * **Type:** Metric
    * **Metric:** `Count` of all records.
    * **Applied Filters:** None.

* **Visualization: Top Source Countries Table**
    * **Type:** Data Table
    * **Row (Group by):** `Top 10` values of `geoip.country_name.keyword`.
    * **Metric:** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Map of IPs**
    * **Type:** Geographic Map
    * **Layer:** `Top 5` countries based on `geoip.country_code2.keyword`.
    * **Metric (Color):** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Alert Severity**
    * **Type:** Pie Chart
    * **Slices (Slice by):** `Top 5` values of `agent.name.keyword`.
    * **Metric (Size):** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Timeline Events**
    * **Type:** Line Chart
    * **X-Axis:** Date histogram on `@timestamp`.
    * **Y-Axis (Metric):** `Count` of records.
    * **Breakdown by:** `Top 3` values of `agent.name.keyword`.
    * **Applied Filters:** None.

* **Visualization: Top Source IPs**
    * **Type:** Bar Chart
    * **X-Axis:** `Top 10` values of `event_src_ip.keyword`.
    * **Y-Axis (Metric):** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Recent Events**
    * **Type:** Data Table
    * **Row 1 (Group by):** `Top 10` values of `geoip.country_name.keyword`.
    * **Row 2 (Sub-group by):** Date histogram on `@timestamp`.
    * **Metric:** `Count` of records.
    * **Applied Filters:** None.

---
## 4. Threat Intelligence Overview 🦠
**Primary Data Source:** `sentinel-logs-*`

* **Visualization: VirusTotal Summary**
    * **Type:** Metric
    * **Metric:** `Count` of the `data.virustotal.found.keyword` field.
    * **Applied Filters:** None.

* **Visualization: Clean vs Malicious**
    * **Type:** Donut Chart
    * **Slices (Slice by):** `Top 1` value + "other" from the `data.virustotal.malicious.keyword` field.
    * **Metric (Size):** `Count` of the `data.virustotal.found.keyword` field.
    * **Applied Filters:** None.

* **Visualization: Recent Threat Detections**
    * **Type:** Data Table
    * **Columns (Group by):**
        * `data.virustotal.source.file.keyword` (Top 10)
        * `data.virustotal.positives.keyword` (Top 10)
        * `data.virustotal.total.keyword` (Top 10)
    * **Metric:** `Count` of records.
    * **Applied Filters:** `data.virustotal.malicious.keyword` is `1`.

* **Visualization: Detection Timeline**
    * **Type:** Area Chart
    * **X-Axis:** Date histogram on `@timestamp`.
    * **Y-Axis (Metric):** `Count` of records.
    * **Breakdown by:** `Top 10` values of `data.virustotal.malicious.keyword`.
    * **Applied Filters:** None.

* **Visualization: Top File Paths Under Scan**
    * **Type:** Horizontal Bar Chart
    * **Y-Axis (Categories):** `Top 10` values of `syscheck.path.keyword`.
    * **X-Axis (Metric):** `Count` of records.
    * **Applied Filters:** None.

* **Visualization: Detection Score Distribution**
    * **Type:** Bar Chart
    * **X-Axis:** `Top 3` values of `data.virustotal.positives.keyword`.
    * **Y-Axis (Metric):** `Count` of records.
    * **Applied Filters:** None.