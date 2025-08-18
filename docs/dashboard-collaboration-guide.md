# Kibana Dashboard Collaboration Guide

This guide explains how to export your dashboards from Kibana and sync them with the project repository so your teammates can access your work.

## Workflow Overview

1.  **Create/Modify Dashboards**: Do your work in the Kibana UI.
2.  **Export Your Work**: Export all relevant dashboards and visualizations as a single `.ndjson` file.
3.  **Run the Sync Script**: Use the provided script to copy the file into the repository.
4.  **Commit to Git**: Use the Git commands provided by the script to share your changes.

---

### Step 1: Exporting from Kibana

When you have finished creating or modifying the SOC dashboards, follow these steps to export them:

1.  Navigate to Kibana in your browser (`http://localhost:5601`).
2.  Click the **main menu** (☰) in the top-left corner, then go to **Stack Management**.
3.  Under the "Kibana" section, click on **Saved Objects**.
4.  Use the search bar and checkboxes to select **all the objects** you want to share (dashboards, visualizations, data views, etc.).
5.  At the top of the list, click the **Export** button.
6.  A single `.ndjson` file will be saved to your computer's **Downloads** folder. Do not rename it.



### Step 2: Syncing with the Repository

Now that you have the exported file, sharing it is simple.

1.  Open your terminal in the `sentinel-soc` project directory.
2.  Run the synchronization script:
    ```bash
    ./sync-dashboards.sh
    ```
3.  The script will automatically find your latest download, copy it to the correct project folder (`configs/kibana_dashboards/`), and give you the exact Git commands you need to run.

4.  Copy and paste the `git add`, `git commit`, and `git push` commands from the script's output into your terminal to finalize the process.

That's it! Your dashboards are now shared with the team.
