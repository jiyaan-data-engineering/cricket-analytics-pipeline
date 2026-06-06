# Cloud Composer (Airflow) Quick Start

Deploy Apache Airflow orchestration for your cricket analytics pipeline in 15 minutes.

---

## Prerequisites

- ✅ GCP project with billing enabled
- ✅ Terraform >= 1.0 installed
- ✅ gcloud CLI configured
- ✅ Already deployed: Dataflow, BigQuery, GCS (from main README)

---

## 3-Step Deployment

### Step 1: Enable Cloud Composer in Terraform (2 minutes)

Edit `terraform/terraform.tfvars`:

```hcl
# Add these lines
enable_cloud_composer  = true
composer_machine_type  = "n1-standard-4"
composer_node_count    = 3

# Optional: reduce cost
# composer_machine_type = "n1-standard-2"
# composer_node_count   = 2
```

### Step 2: Deploy Cloud Composer (10 minutes)

```bash
cd terraform

# Plan changes
terraform plan

# Apply (creates Cloud Composer environment)
terraform apply

# Save outputs
terraform output -json > composer_outputs.json
```

This creates:
- ✅ Cloud Composer environment (3 nodes, auto-scales)
- ✅ Airflow UI accessible via web browser
- ✅ DAGs uploaded to GCS
- ✅ Service accounts with IAM roles
- ✅ Monitoring alerts configured

### Step 3: Configure Airflow Variables (3 minutes)

```bash
# Get environment name from Terraform output
COMPOSER_ENV=$(terraform output -raw cloud_composer_environment_name)
PROJECT_ID=$(terraform output -raw gcp_project_id)

# Set Airflow variables
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  variables set -- \
  gcp_project_id "$PROJECT_ID"

gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  variables set -- \
  gcp_region "us-central1"

gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  variables set -- \
  rapidapi_key "YOUR_RAPIDAPI_KEY"
```

---

## Access Airflow UI

```bash
# Get Airflow URL
AIRFLOW_URL=$(terraform output -raw cloud_composer_airflow_uri)

# Open in browser
open "$AIRFLOW_URL"  # macOS
xdg-open "$AIRFLOW_URL"  # Linux
start "$AIRFLOW_URL"  # Windows
```

**Default Login**:
- User: `admin`
- Password: Automatically generated (check GCP Console)

---

## Verify DAGs

### In Airflow UI

1. Go to **DAGs** tab
2. Look for:
   - `cricket_analytics_pipeline` ✅
   - `cricket_data_quality_monitoring` ✅
3. Both should show as "Enabled"

### Via CLI

```bash
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags list
```

---

## Trigger First Run

### Via Airflow UI

1. Click `cricket_analytics_pipeline`
2. Click **Trigger DAG** (play icon)
3. Click **Trigger**
4. Watch task execution in real-time

### Via CLI

```bash
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags trigger cricket_analytics_pipeline
```

---

## Monitor Execution

### In Airflow UI

1. **DAGs** → `cricket_analytics_pipeline`
2. **Tree View** → See task status
3. Click task → View logs
4. **Graph View** → See DAG structure

### Via CLI

```bash
# List all DAG runs
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags list-runs cricket_analytics_pipeline

# View specific task logs
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  tasks logs cricket_analytics_pipeline \
  fetch_cricbuzz_api 2024-06-05
```

---

## What's Running Now

### Main Pipeline (Daily @ 06:00 UTC)

```
Ingestion
  └─ Fetch Cricbuzz API
       └─ Convert to CSV
            └─ Upload to GCS
                 └─ Processing
                     └─ Dataflow job
                          └─ Validation
                               └─ Staging Transforms
                                    └─ Success notification
```

**Duration**: ~20 minutes

### Data Quality Monitoring (Daily @ 10:00 UTC)

```
Freshness Check
  ├─ Completeness Check
  │    └─ Consistency Check
  │         └─ Quality Report
```

**Duration**: ~5 minutes

---

## Verify Data Flow

### Check BigQuery

```bash
# Query raw data
bq query --use_legacy_sql=false \
  "SELECT COUNT(*), FORMAT FROM \`$PROJECT_ID.cricket_raw.batting_rankings\` GROUP BY FORMAT"

# Expected: 3 rows (TEST, ODI, T20I)
```

### Check Task Logs

In Airflow UI:
1. Click task instance
2. View **Log** tab
3. Verify: "Successfully uploaded X records"

---

## Disable Original Cloud Scheduler (Optional)

If you want to **remove** the original Cloud Scheduler trigger:

```bash
# Pause the scheduler
gcloud scheduler jobs pause cricket-daily-ingestion \
  --location us-central1

# Or delete it
gcloud scheduler jobs delete cricket-daily-ingestion \
  --location us-central1
```

**Note**: If using only Airflow, update Terraform to remove:
```hcl
# Comment out or delete these from terraform/main.tf
# - google_cloud_scheduler_job.daily_ingestion
# - google_eventarc_trigger.gcs_to_dataflow
# - google_cloudfunctions2_function.dataflow_trigger
```

Then run: `terraform apply`

---

## Troubleshooting

### DAG Not Appearing

1. Check DAGs uploaded:
   ```bash
   gsutil ls gs://cricket-analytics-composer-dags-$PROJECT_ID/dags/
   ```

2. Wait 3-5 minutes for sync

3. Refresh Airflow UI (Ctrl+R)

4. Check for syntax errors:
   - Airflow UI → DAGs tab
   - Look for red error icons
   - Click to see error details

### DAG Run Failed

1. Click DAG → click failed task instance
2. Click **Log** tab
3. Read error message
4. Fix code if needed
5. Click **Clear** button to retry

### Slow DAG Execution

1. Check Dataflow job in GCP Console
2. Verify BigQuery queries complete
3. Monitor Cloud Composer environment health

### Environment Unhealthy

```bash
# Check status
gcloud composer environments describe $COMPOSER_ENV \
  --location us-central1

# View recent errors
gcloud logging read \
  "resource.type=cloud_composer_environment" \
  --limit 20 \
  --format json
```

---

## Next Steps

### Monitor in Real-Time

```bash
# Watch DAG runs
watch gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags list-runs cricket_analytics_pipeline
```

### Create Custom DAG

1. Create `airflow/dags/my_dag.py`
2. Upload: `gsutil cp airflow/dags/my_dag.py gs://cricket-analytics-composer-dags-$PROJECT_ID/dags/`
3. Refresh Airflow UI
4. DAG appears in UI after 2-3 minutes

### Set Up Email Alerts

1. In Airflow UI → **Admin** → **Connections**
2. Create email connection (gmail, sendgrid, etc.)
3. Update DAG: 
   ```python
   default_args = {
       "email": ["alerts@example.com"],
       "email_on_failure": True,
   }
   ```
4. Redeploy DAG

### Add Data Quality Checks

Already included! `data_quality_monitoring_dag.py` runs daily @ 10:00 UTC

Monitor via Airflow UI:
- View task logs
- Check XCom values
- Set up Slack notifications

---

## Cost Breakdown

### Cloud Composer

| Configuration | Monthly Cost |
|---------------|--------------|
| 3 nodes, n1-standard-4 | ~$500 |
| 2 nodes, n1-standard-2 | ~$250 |
| 1 node, n1-standard-2 | ~$150 |

### Total Pipeline Cost (With Airflow)

```
Cloud Composer (2 nodes):  ~$250
Dataflow (1 job/day):       ~$3
BigQuery (queries):         ~$4
Cloud Storage:              ~$0.02
─────────────────────────────────
Total Monthly:            ~$257
```

### Comparison

- **Without Airflow** (Cloud Scheduler): ~$6/month
- **With Airflow** (Cloud Composer): ~$257/month
- **Premium**: Better monitoring, complex DAGs, team visibility

---

## Useful Commands

### List all Cloud Composer environments

```bash
gcloud composer environments list --locations us-central1
```

### View environment details

```bash
gcloud composer environments describe $COMPOSER_ENV \
  --location us-central1 \
  --format json
```

### Update PyPI packages

```bash
gcloud composer environments update $COMPOSER_ENV \
  --location us-central1 \
  --update-pypi-packages-from-file requirements.txt
```

### Upload file to DAGs folder

```bash
gcloud composer environments storage dags import \
  --environment $COMPOSER_ENV \
  --location us-central1 \
  --source my_dag.py
```

### Clear task cache

```bash
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  tasks clear cricket_analytics_pipeline \
  --start-date 2024-06-05
```

---

## Documentation

- **[AIRFLOW.md](AIRFLOW.md)** — Comprehensive Airflow guide
- [Cloud Composer Docs](https://cloud.google.com/composer/docs)
- [Apache Airflow Docs](https://airflow.apache.org/docs/)

---

## Summary

✅ **Deployed** Apache Airflow (Cloud Composer)
✅ **Running** Main pipeline + Quality monitoring DAGs
✅ **Monitoring** Via Airflow UI + Cloud Logging
✅ **Cost** ~$250/month (scalable based on needs)

**Benefits**:
- Professional-grade orchestration
- Visual DAG monitoring
- Data quality checks built-in
- Complex workflow support
- Team collaboration

**Next**: Open Airflow UI and explore the DAGs! 🚀

---

**Questions?** See [AIRFLOW.md](AIRFLOW.md) for comprehensive documentation.
