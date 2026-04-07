# Reviewer Access to BigQuery

To explore the final tables and query the data directly:

**Prerequisites:** You must have a Google Account, Google Workspace account, or Cloud Identity account. BigQuery IAM does not support granting access to arbitrary email addresses.

**Steps:**

1. Provide your Google-associated email address to the project owner
2. The owner will grant you:
   - **BigQuery Data Viewer** (read tables)
   - **BigQuery Job User** (run queries)
3. Once access is granted, open the [BigQuery Console](https://console.cloud.google.com/bigquery?project=support-ticket-analytics)
4. Select project `support-ticket-analytics`
5. Browse datasets:
   - `raw` — source CSV data
   - `dbt_staging` — cleaned staging views
   - `dbt_intermediate` — enriched intermediate views
   - `dbt_core` — core fact and dimension tables
   - `dbt_mart` — analyst-friendly denormalized tables

**Alternative:** If you don't have a Google account, sample query outputs and schema documentation are available in the main [README.md](README.md).
