# Apache Airflow Orchestration - Cricket Analytics Pipeline

## Overview

This document covers the Apache Airflow (Cloud Composer) orchestration layer for the cricket analytics pipeline.

---

## Why Airflow?

### Benefits Over Cloud Scheduler + Cloud Functions

| Feature | Cloud Scheduler | Airflow |
|---------|-----------------|---------|
| **DAG Visualization** | ❌ No | ✅ Yes (UI) |
| **Task Dependencies** | Limited (linear only) | ✅ Complex DAGs |
| **Monitoring** | Basic | ✅ Rich metrics |
| **Retries** | Per-trigger only | ✅ Per-task + exponential backoff |
| **Data Quality Checks** | Manual | ✅ Built-in sensors |
| **SLA Monitoring** | ❌ No | ✅ Yes |
| **Backfill Support** | ❌ No | ✅ Yes |
| **Cost** | $0.10/month | ~$500/month (Cloud Composer) |

---

## Architecture

### New Pipeline with Airflow

```
┌─────────────────────────────────────────────────────────────────┐
│                      Cloud Composer (Airflow)                  │
│                                                                 │
│  DAG: cricket_analytics_pipeline                              │
│  Schedule: Daily @ 06:00 UTC                                  │
│                                                                 │
│  Task Groups:                                                   │
│  1. ingestion → fetch_cricbuzz_api                             │
│  2. processing → launch_dataflow_job                           │
│  3. validation → validate_data + check_table                  │
│  4. staging_transformation → transform_dims + transform_fact  │
│  5. notify_completion                                          │
│                                                                 │
│  DAG: data_quality_monitoring                                  │
│  Schedule: Daily @ 10:00 UTC (after main pipeline)            │
│                                                                 │
│  Tasks:                                                         │
│  - Check table freshness                                       │
│  - Check data completeness                                     │
│  - Check staging consistency                                   │
│  - Generate quality report                                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
            GCS → Dataflow → BigQuery → Looker Studio
```

---

## File Structure

```
airflow/
├── dags/
│   ├── cricket_analytics_dag.py          # Main orchestration DAG
│   └── data_quality_monitoring_dag.py    # Data quality DAG
├── requirements.txt                      # Python dependencies
└── composer_config.yaml                  # Cloud Composer config
```

---

## DAGs

### 1. cricket_analytics_dag.py

**Purpose**: Main data pipeline orchestration

**Schedule**: Daily @ 06:00 UTC
**Duration**: ~20 minutes (end-to-end)

**Task Groups**:

#### Ingestion
```
fetch_cricbuzz_api
├─ Fetches Test/ODI/T20I rankings
├─ Converts JSON → DataFrame
├─ Saves to GCS as CSV
└─ Pushes GCS path to XCom
```

#### Processing
```
launch_dataflow_job
├─ Triggered by ingestion completion
├─ Reads CSV from GCS
├─ Applies schema validation
└─ Writes to BigQuery RAW layer
```

#### Validation
```
validate_data_quality (parallel)
├─ Checks row count
├─ Validates null values
└─ Verifies data types

check_raw_table_exists
└─ Ensures table exists
```

#### Staging Transformation
```
transform_dim_player (parallel)
├─ MERGE upsert dim_player

transform_dim_country (parallel)
├─ MERGE upsert dim_country

transform_fact_batting
├─ Depends on above dims
├─ MERGE upsert fact_batting_rankings
└─ Creates daily snapshot
```

#### Completion
```
notify_completion
└─ Logs success message
```

### 2. data_quality_monitoring_dag.py

**Purpose**: Monitor data quality and pipeline health

**Schedule**: Daily @ 10:00 UTC (2 hours after main pipeline)
**Duration**: ~5 minutes

**Task Groups**:

#### Freshness Checks
```
check_table_freshness
├─ Verifies all tables have recent data
├─ Alerts if data > 48 hours old
└─ Checks: raw, staging tables
```

#### Completeness Checks
```
check_data_completeness
├─ Validates record counts per format
├─ Checks for null values
└─ Alerts if < 50 records per format
```

#### Consistency Checks
```
check_staging_consistency
├─ Compares raw vs staging row counts
├─ Detects data loss
└─ Allows small variance (5 rows)
```

#### Report Generation
```
generate_quality_report
├─ Aggregates all checks
├─ Calculates metrics
└─ Stores in XCom for alerting
```

---

## Cloud Composer Setup

### Prerequisites

- GCP Project with billing enabled
- Terraform >= 1.0
- gcloud CLI configured

### Deployment

#### 1. Update Terraform Variables

Add to `terraform/terraform.tfvars`:

```hcl
enable_cloud_composer = true
composer_machine_type = "n1-standard-4"
composer_node_count   = 3
```

#### 2. Deploy with Terraform

```bash
cd terraform

# Plan
terraform plan

# Apply (creates Cloud Composer environment)
terraform apply
```

This creates:
- ✅ Cloud Composer environment (3 nodes)
- ✅ Service accounts with IAM roles
- ✅ GCS bucket for DAGs
- ✅ KMS encryption keys
- ✅ Monitoring alerts

#### 3. Set Airflow Variables

After deployment, set Airflow variables:

```bash
# Get environment name
COMPOSER_ENV=$(terraform output -raw cloud_composer_environment_name)
PROJECT_ID=$(terraform output -raw gcp_project_id)

# Set variables
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  variables set -- \
  gcp_project_id $PROJECT_ID

gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  variables set -- \
  gcp_region us-central1

gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  variables set -- \
  rapidapi_key "YOUR_RAPIDAPI_KEY"
```

#### 4. Access Airflow UI

```bash
# Get Airflow URL
AIRFLOW_URL=$(terraform output -raw cloud_composer_airflow_uri)

# Open in browser
open $AIRFLOW_URL  # macOS
# or
xdg-open $AIRFLOW_URL  # Linux
# or
start $AIRFLOW_URL  # Windows
```

---

## DAG Development

### Create a New DAG

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

default_args = {
    "owner": "data-engineering",
    "start_date": datetime(2024, 6, 1),
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

dag = DAG(
    "my_new_dag",
    default_args=default_args,
    description="My new DAG",
    schedule_interval="0 12 * * *",  # Daily at noon UTC
    tags=["cricket", "custom"],
)

def my_task(**context):
    print("Hello from Airflow!")

with dag:
    task1 = PythonOperator(
        task_id="my_task",
        python_callable=my_task,
    )
```

### Upload to Cloud Composer

```bash
# Copy DAG to Cloud Composer GCS bucket
gsutil cp my_dag.py gs://cricket-analytics-composer-dags-PROJECT_ID/dags/

# Verify DAG appears in UI (2-3 minutes)
```

---

## Monitoring & Alerting

### Cloud Composer Monitoring

```bash
# View environment status
gcloud composer environments describe $COMPOSER_ENV \
  --location us-central1

# View recent tasks
gcloud composer environments storage dags list \
  --environment $COMPOSER_ENV \
  --location us-central1
```

### Airflow Logs

Access via Airflow UI:
1. DAGs → click DAG name
2. Tree View → click task instance
3. Log → view execution logs

Or via CLI:

```bash
# View logs for specific DAG run
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags list

# View task logs
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  tasks logs cricket_analytics_pipeline fetch_cricbuzz_api 2024-06-05
```

### Set Up Alerting

#### Email Alerts

Enable in DAG:

```python
default_args = {
    "email": ["alerts@example.com"],
    "email_on_failure": True,
    "email_on_retry": False,
}
```

#### Cloud Monitoring Alerts

Already configured in Terraform:
- `Composer DAG Failure Alert` — Triggers on task failure
- `Composer Environment Health Alert` — Triggers on environment issues

To add notification channel:

```bash
# Create notification channel (email)
gcloud alpha monitoring channels create \
  --display-name="Cricket Analytics Alerts" \
  --type=email \
  --channel-labels=email_address=alerts@example.com

# Update alert policy with channel ID
terraform apply -var="notification_channel_id=CHANNEL_ID"
```

---

## Task Orchestration Patterns

### Sequential Tasks

```python
task1 >> task2 >> task3
```

### Parallel Tasks

```python
[task1, task2, task3] >> task4
```

### Task Groups

```python
with TaskGroup("my_group"):
    task1 = PythonOperator(...)
    task2 = PythonOperator(...)
    task1 >> task2
```

### XCom Communication

**Push data**:
```python
context["task_instance"].xcom_push(key="my_key", value="my_value")
```

**Pull data**:
```python
value = context["task_instance"].xcom_pull(
    task_ids="upstream_task",
    key="my_key"
)
```

**Template**:
```python
"{{ task_instance.xcom_pull(task_ids='upstream_task', key='my_key') }}"
```

---

## Common Operations

### Pause/Unpause DAG

```bash
# Pause
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags pause cricket_analytics_pipeline

# Unpause
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags unpause cricket_analytics_pipeline
```

### Trigger DAG Manually

```bash
# Trigger for today's date
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags trigger cricket_analytics_pipeline

# Trigger for specific date
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags trigger cricket_analytics_pipeline \
  --exec-date 2024-06-05
```

### Backfill DAG (Re-run historical dates)

```bash
# Backfill from June 1 to June 5
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  dags backfill cricket_analytics_pipeline \
  --start-date 2024-06-01 \
  --end-date 2024-06-05
```

### Clear Task Instance

```bash
# Clear failed task to retry
gcloud composer environments run $COMPOSER_ENV \
  --location us-central1 \
  tasks clear cricket_analytics_pipeline fetch_cricbuzz_api \
  --start-date 2024-06-05
```

---

## Performance Tuning

### Parallelism Settings

In `airflow_config_overrides`:

```yaml
core:
  parallelism: 32              # Max parallel tasks across all DAGs
  dag_concurrency: 16          # Max parallel tasks per DAG
  max_active_runs_per_dag: 1   # Max simultaneous runs of same DAG
```

### Task Pool Limits

```yaml
core:
  task_pool: "default_pool"
  task_pool_limit: 128
```

### Scheduler Settings

```yaml
scheduler:
  scheduler_heartbeat_interval: 5      # Check for new tasks every 5s
  max_dagruns_to_create_per_loop: 10   # Max DAG runs per loop
```

---

## Troubleshooting

### DAG Won't Run

1. Check if DAG is paused:
   ```bash
   gcloud composer environments run $COMPOSER_ENV \
     --location us-central1 \
     dags list
   ```

2. Check for syntax errors:
   - Open Airflow UI → DAGs
   - Look for warning/error icons
   - Click DAG to see error details

3. Verify environment health:
   ```bash
   gcloud composer environments describe $COMPOSER_ENV \
     --location us-central1
   ```

### Task Fails

1. View task logs in Airflow UI
2. Check Task Instance details
3. Review error message
4. Fix code and redeploy DAG
5. Clear task and re-run

### Slow DAG Execution

1. Check Cloud Composer environment metrics
2. Verify worker nodes have sufficient resources
3. Optimize task parallelism
4. Monitor Dataflow job duration

### Out of Memory

1. Scale up Cloud Composer (increase machine type)
2. Reduce parallelism
3. Split large DAGs into smaller ones

---

## Cost Optimization

### Cloud Composer Costs

**Baseline** (3 nodes, n1-standard-4): ~$500/month

**Reduce Cost**:
1. Downsize nodes: n1-standard-2 (~$250/month)
2. Reduce node count: 2 nodes (~$350/month)
3. Use auto-scaling (when available)

### Dataflow Costs

**Current**: ~$2-3/month (1 job/day, 2-5 workers)

**Optimize**:
1. Reduce workers when possible
2. Use machine type with lower cost
3. Schedule during off-peak hours

---

## Comparison: Cloud Scheduler vs Airflow

| Aspect | Cloud Scheduler | Airflow |
|--------|-----------------|---------|
| **Setup Time** | 5 min | 30 min |
| **Learning Curve** | Low | Moderate |
| **Cost** | $0.10/month | ~$500/month |
| **Complexity** | Simple (linear) | Complex (DAGs) |
| **Best For** | Simple pipelines | Complex workflows |

**Recommendation**:
- Use **Cloud Scheduler** for simple, linear pipelines
- Use **Airflow** when you need:
  - Complex DAG dependencies
  - Data quality monitoring
  - Backfill/catchup support
  - Rich monitoring UI

---

## Migration from Cloud Scheduler to Airflow

### Step 1: Create DAG

Already done! See `cricket_analytics_dag.py`

### Step 2: Deploy to Cloud Composer

```bash
# DAGs are automatically deployed via Terraform
# Or manually:
gsutil cp airflow/dags/*.py \
  gs://cricket-analytics-composer-dags-PROJECT_ID/dags/
```

### Step 3: Disable Cloud Scheduler

```bash
# Set Cloud Scheduler to pause
gcloud scheduler jobs pause cricket-daily-ingestion \
  --location us-central1

# Or delete (if using only Airflow)
gcloud scheduler jobs delete cricket-daily-ingestion \
  --location us-central1
```

### Step 4: Update Terraform

Comment out or remove:
- `google_cloud_scheduler_job`
- `google_eventarc_trigger`
- `google_cloudfunctions2_function`

---

## Advanced Topics

### Custom Operators

Create reusable operators:

```python
from airflow.models import BaseOperator

class CricbuzzAPIOperator(BaseOperator):
    def __init__(self, formats, **kwargs):
        super().__init__(**kwargs)
        self.formats = formats

    def execute(self, context):
        # Custom logic
        return "success"
```

### Sensors

Wait for external conditions:

```python
from airflow.providers.google.cloud.sensors.gcs import GCSObjectSensor

wait_for_file = GCSObjectSensor(
    task_id="wait_for_csv",
    bucket="cricket-raw-data",
    object="batting/*.csv",
    timeout=3600,
)
```

### Hooks

Interact with external systems:

```python
from airflow.providers.google.cloud.hooks.gcs import GCSHook

hook = GCSHook()
files = hook.list(bucket="cricket-raw-data", prefix="batting/")
```

---

## Documentation

- [Apache Airflow Docs](https://airflow.apache.org/docs/)
- [Cloud Composer Docs](https://cloud.google.com/composer/docs)
- [Airflow Providers for Google Cloud](https://airflow.apache.org/docs/apache-airflow-providers-google/)

---

## Summary

**Cloud Composer provides**:
✅ Professional-grade orchestration
✅ Complex DAG support
✅ Rich monitoring UI
✅ Data quality checks
✅ Backfill/catchup support
✅ Team collaboration

**Trade-off**:
⚠️ Higher cost (~$500/month vs $0.10/month for Cloud Scheduler)

**Use Airflow when**:
- You have complex dependencies
- You need data quality monitoring
- You want backfill support
- You need team visibility

**Use Cloud Scheduler when**:
- Simple, linear pipelines
- Minimal cost requirements
- No complex dependencies

---

**Next**: Deploy Cloud Composer with Terraform and enable Airflow orchestration!
