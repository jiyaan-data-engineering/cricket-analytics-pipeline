# 🌬️ Apache Airflow (Cloud Composer): Orchestration Guide

**Author**: Satish Mudde  
**Date**: 2026-06-07  
**Status**: Complete Airflow Setup  

Consolidated documentation for Cloud Composer (Apache Airflow 2.7.3) orchestration.

---

## 📋 Quick Navigation

- [Overview](#overview)
- [Architecture](#architecture)
- [DAGs](#dags)
- [Setup](#setup)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## 📊 Overview

**What**: Cloud Composer (Fully Managed Airflow) on GCP  
**Version**: Apache Airflow 2.7.3  
**Environment**: 3 nodes, n1-standard-4 machines  
**Storage**: 30GB per node  
**Purpose**: End-to-end pipeline orchestration with observability

| Component | Details | Status |
|-----------|---------|--------|
| **Environment** | 3 nodes, n1-standard-4 | ✅ |
| **DAGs** | 2 DAGs (main + monitoring) | ✅ |
| **Schedules** | 06:00 & 10:00 UTC | ✅ |
| **Monitoring** | Cloud Logging & Monitoring | ✅ |
| **Encryption** | KMS keys (90-day rotation) | ✅ |
| **Workers** | Automatic scaling | ✅ |

---

## 🏗️ Architecture

```
Cloud Scheduler (06:00 UTC)
    ↓
Cloud Composer Environment
    ├─ Webserver (UI)
    ├─ Scheduler (DAG orchestration)
    └─ Workers (3 nodes)
        ├─ Execute tasks
        ├─ Run Dataflow jobs
        └─ Run SQL queries
    
Logs & Metrics
    ├─ Cloud Logging
    ├─ Cloud Monitoring
    └─ Airflow UI (localhost:8080)
```

---

## 📁 File Structure

```
airflow/
├── dags/
│   ├── cricket_analytics_dag.py          # Main pipeline DAG
│   └── data_quality_monitoring_dag.py    # QA DAG
│
├── composer_config.yaml                  # Composer environment config
└── plugins/
    └── (Custom operators if needed)
```

---

## 🔄 DAGs

### 1. cricket_analytics_dag.py

**Main pipeline DAG** - Orchestrates entire data flow

**Schedule**: `0 6 * * *` (Daily at 06:00 UTC)

**Tasks**:
```
INGESTION_TG
├─ fetch_cricbuzz_api (Cloud Run)
└─ upload_to_gcs

    ↓

PROCESSING_TG
├─ launch_dataflow
└─ wait_for_completion

    ↓

VALIDATION_TG
├─ count_raw_records
├─ validate_record_count
└─ check_data_quality

    ↓

STAGING_TRANSFORMATION_TG
├─ load_dim_player (BigQuery SQL)
├─ load_dim_country
├─ load_dim_format
├─ load_dim_date
└─ load_fact_batting_rankings

    ↓

NOTIFY_COMPLETION
└─ send_success_notification
```

**Code Structure**:
```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.google.cloud.operators.dataflow import DataflowTemplateOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCheckOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'cricket-analytics',
    'depends_on_past': False,
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'cricket_analytics_pipeline',
    default_args=default_args,
    description='Cricket rankings ETL pipeline',
    schedule_interval='0 6 * * *',  # Daily 06:00 UTC
    start_date=datetime(2026, 6, 7),
    catchup=False,
    tags=['cricket', 'analytics', 'etl'],
) as dag:
    
    # TaskGroup 1: Ingestion
    with TaskGroup('ingestion_tg') as ingestion_group:
        # Fetch from Cricbuzz API
        # Upload to GCS
        pass
    
    # TaskGroup 2: Processing
    with TaskGroup('processing_tg') as processing_group:
        # Launch Dataflow
        # Wait for completion
        pass
    
    # ... more task groups
    
    # Task dependencies
    ingestion_group >> processing_group >> validation_group >> \
        staging_transformation_group >> notify_completion
```

**Key Features**:
- ✅ Modular task groups for clarity
- ✅ Retry logic (2 retries, 5-min delay)
- ✅ Email notifications on failure
- ✅ XCom for task communication
- ✅ SLA monitoring (24-hour deadline)
- ✅ Dependency management

### 2. data_quality_monitoring_dag.py

**Monitoring DAG** - Validates data quality

**Schedule**: `0 10 * * *` (Daily at 10:00 UTC, after main DAG)

**Tasks**:
```
FRESHNESS_CHECKS
├─ check_raw_data_freshness (< 48 hrs old)
└─ check_staging_data_freshness

    ↓

COMPLETENESS_CHECKS
├─ check_null_values_per_format
├─ check_minimum_records_per_format
└─ validate_record_counts

    ↓

CONSISTENCY_CHECKS
├─ compare_raw_vs_staging (player_id distinct)
├─ check_dimensional_integrity
└─ validate_fact_record_keys

    ↓

GENERATE_QUALITY_REPORT
└─ compile_metrics_dashboard
```

**Code Structure**:
```python
with DAG(
    'data_quality_monitoring',
    default_args=default_args,
    description='Data quality checks',
    schedule_interval='0 10 * * *',  # Daily 10:00 UTC
    start_date=datetime(2026, 6, 7),
    catchup=False,
    tags=['cricket', 'quality', 'monitoring'],
) as dag:
    
    # Freshness checks
    raw_freshness = BigQueryCheckOperator(
        task_id='check_raw_freshness',
        sql="""
        SELECT COUNT(*) > 0
        FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
        WHERE DATE(ingested_at) = CURRENT_DATE()
        """
    )
    
    # Completeness checks
    null_check = BigQueryCheckOperator(
        task_id='check_nulls',
        sql="""
        SELECT COUNT(*) - COUNT(player_id) < 10
        FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
        WHERE DATE(ingested_at) = CURRENT_DATE()
        """
    )
    
    # Task dependencies with trigger_rule
    raw_freshness >> null_check >> [consistency_checks] >> report
```

**Key Features**:
- ✅ Runs after main pipeline
- ✅ Alerts on data anomalies
- ✅ Captures metrics to XCom
- ✅ trigger_rule=all_done (runs even if main fails)
- ✅ Supports downstream dashboards

---

## ⚙️ Setup

### File: airflow/composer_config.yaml

```yaml
# Google Cloud Composer configuration

composer_environment:
  name: cricket-analytics-composer
  region: us-central1
  node_count: 3
  machine_type: n1-standard-4
  disk_size_gb: 30
  
  airflow_config_overrides:
    # Disable pausing of new DAGs
    core-dags_are_paused_at_creation: 'false'
    # Enable FastAPI for UI
    webserver-expose_config: 'true'
    # Max parallel DAG runs
    core-max_active_runs_per_dag: 1
  
  software_config:
    airflow_version: 2.7.3
    python_version: 3
    
    pypi_packages:
      apache-beam[gcp]: '==2.52.0'
      google-cloud-dataflow: '>=0.8.0'
      google-cloud-bigquery: '>=3.10.0'
  
  encryption:
    kms_key_name: projects/PROJECT_ID/locations/us-central1/keyRings/composer-key-ring/cryptoKeys/composer-key
  
  service_account_email: cricket-composer-sa@PROJECT_ID.iam.gserviceaccount.com
```

### Configuration in Terraform

```hcl
# terraform/cloud_composer.tf

resource "google_composer_environment" "main" {
  name   = "cricket-analytics-composer"
  region = var.gcp_region
  
  config {
    node_count   = 3
    machine_type = "n1-standard-4"
    disk_size_gb = 30
    
    software_config {
      airflow_config_overrides = {
        "core-dags_are_paused_at_creation" = "false"
        "core-max_active_runs_per_dag"    = "1"
      }
      
      pypi_packages = {
        "apache-beam[gcp]"           = "==2.52.0"
        "google-cloud-dataflow"      = ">=0.8.0"
        "google-cloud-bigquery"      = ">=3.10.0"
      }
    }
    
    encryption_config {
      kms_key_name = google_kms_crypto_key.composer_key.id
    }
  }
  
  depends_on = [
    google_project_service.required_apis,
    google_service_account.cloud_composer_sa
  ]
}
```

---

## 🚀 Deployment

### Step 1: Create Environment (via Terraform)

```bash
cd terraform
terraform apply -target=google_composer_environment.main
```

**Time**: 15-20 minutes

**What it creates**:
- 3 Compute Engine nodes
- GCS bucket for DAGs & logs
- Cloud SQL instance for metadata
- KMS encryption keys

### Step 2: Upload DAGs

```bash
# Get Composer bucket path
BUCKET=$(gcloud composer environments describe cricket-analytics-composer \
  --location us-central1 --format='value(config.dag_gcs_prefix)' | sed 's|gs://||')

# Copy DAG files
gsutil cp airflow/dags/*.py gs://$BUCKET/dags/

# Verify upload
gsutil ls gs://$BUCKET/dags/
```

### Step 3: Access Airflow UI

```bash
# Port-forward to Airflow web server
gcloud composer environments run cricket-analytics-composer \
  --location us-central1 \
  web-server exposer

# Access at: http://localhost:8080
# Default user: admin / admin (change password!)
```

### Step 4: Trigger DAG

```bash
# Via CLI
gcloud composer environments run cricket-analytics-composer \
  --location us-central1 \
  dags test cricket_analytics_pipeline

# Via UI
# Navigate to DAGs tab → cricket_analytics_pipeline → Trigger
```

---

## 📊 Monitoring

### Cloud Logging

```bash
# View DAG logs
gcloud logging read "resource.type=cloud_composer_environment" \
  --format json \
  --limit 50

# View specific DAG run
gcloud logging read "resource.type=cloud_composer_environment \
  AND jsonPayload.dag_id=cricket_analytics_pipeline" \
  --format json
```

### Cloud Monitoring Alerts

**File**: terraform/cloud_composer.tf

```hcl
# Alert: DAG task failure
resource "google_monitoring_alert_policy" "dag_failure" {
  display_name = "Composer DAG Task Failure"
  combiner     = "OR"
  
  conditions {
    display_name = "DAG task failure rate"
    
    condition_threshold {
      filter          = "resource.type=\"cloud_composer_environment\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
}

# Alert: Environment health
resource "google_monitoring_alert_policy" "composer_health" {
  display_name = "Composer Environment Health"
  # ... similar structure
}
```

### Metrics to Monitor

- **DAG Success Rate**: Should be > 99%
- **Task Duration**: Should be < expected time
- **Task Failure Rate**: Should be 0%
- **Scheduler Lag**: Should be < 1 minute
- **Worker CPU**: Should be < 80%

---

## 🔧 Common Operations

### Pause/Resume DAG

```bash
# Pause
gcloud composer environments run cricket-analytics-composer \
  --location us-central1 \
  dags pause cricket_analytics_pipeline

# Resume
gcloud composer environments run cricket-analytics-composer \
  --location us-central1 \
  dags unpause cricket_analytics_pipeline
```

### Trigger Manual DAG Run

```bash
gcloud composer environments run cricket-analytics-composer \
  --location us-central1 \
  dags backfill cricket_analytics_pipeline \
  --start_date 2026-06-01 \
  --end_date 2026-06-07
```

### View DAG Code

```bash
# In Airflow UI
# DAGs tab → cricket_analytics_pipeline → Code

# Or via CLI
gcloud composer environments storage dags list \
  --environment cricket-analytics-composer \
  --location us-central1
```

### Scale Environment

```bash
# Increase nodes from 3 to 5
gcloud composer environments update cricket-analytics-composer \
  --location us-central1 \
  --node-count 5
```

---

## ❌ Troubleshooting

### Issue: DAG Not Appearing

**Problem**: New DAG uploaded but not showing in UI

**Solution**:
```bash
# Refresh DAG cache
gcloud composer environments run cricket-analytics-composer \
  --location us-central1 \
  dags refresh

# Check DAG file syntax
python -m py_compile airflow/dags/cricket_analytics_dag.py
```

### Issue: Task Timeout

**Problem**: Task exceeds execution time

**Solution**:
```python
# In DAG default_args
'execution_timeout': timedelta(hours=2)
'sla': timedelta(hours=3)
```

### Issue: Missing Imports

**Problem**: ImportError for Google Cloud libraries

**Solution**:
```bash
# Add to Composer PyPI packages (via Terraform)
pypi_packages = {
  "google-cloud-dataflow": ">=0.8.0"
  "google-cloud-bigquery": ">=3.10.0"
}

# Or via CLI
gcloud composer environments update cricket-analytics-composer \
  --location us-central1 \
  --update-pypi-packages-from-file requirements.txt
```

---

## 📚 Related Files

- [TERRAFORM.md](./TERRAFORM.md) - Cloud Composer infrastructure setup
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall architecture
- [GCP_SETUP_GUIDE.md](../GCP_SETUP_GUIDE.md) - GCP prerequisites

---

## ✅ Checklist

- [ ] Cloud Composer environment created
- [ ] DAG files uploaded to gs://bucket/dags/
- [ ] Airflow UI accessible (http://localhost:8080)
- [ ] DAGs visible in UI
- [ ] First DAG run successful
- [ ] Monitoring alerts configured
- [ ] Email notifications working

---

**Status**: ✅ Complete Cloud Composer Setup  
**Author**: Satish Mudde  
**Last Updated**: 2026-06-07  

Full orchestration with Airflow! 🌬️
