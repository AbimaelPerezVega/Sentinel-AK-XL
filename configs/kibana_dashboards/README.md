# Kibana Dashboard Configuration

This directory contains the exported Kibana saved objects for the **Sentinel SOC AK-XL** project. These files include the necessary dashboards, visualizations, and index patterns.

## Current Version

The recommended file for import is:
**`kibana-dashboards-4D-V4.ndjson`**

This file contains the four main dashboards:
1.  Sentinel SOC Overview
2.  Threat Intelligence Overview
3.  Enhanced Network Analysis
4.  Authentication Monitoring

## How to Import into Kibana

To load this configuration into your Kibana instance, follow these steps:

1.  Navigate to your Kibana instance.
2.  Open the main menu (☰) and go to **Stack Management**.
3.  Under the "Kibana" section, click on **Saved Objects**.
4.  Click the **Import** button in the top-right corner.
5.  Select the `kibana-dashboards-4D-V4.ndjson` file from this directory and upload it.
6.  You will be prompted to review the objects before importing. It is recommended to import all objects from the file to ensure the dashboards function correctly.
7.  Click **Import** to finish. The dashboards will now be available in the "Dashboard" section of Kibana.