# 🚀 GCP End-to-End Project Setup Guide

**Cricket Analytics Pipeline - Complete Infrastructure Setup**

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Resource Naming Convention](#resource-naming-convention)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Setup](#step-by-step-setup)
5. [Verification Checklist](#verification-checklist)
6. [Deployment & Testing](#deployment--testing)

---

## 🎯 Project Overview

This document provides complete instructions to set up a production-ready GCP project for the Cricket Analytics Pipeline.

**Project Goal**: Ingest ICC cricket rankings → Process → Store → Visualize

---

## 📝 Resource Naming Convention

### Naming Strategy
```
Format: cricket-analytics-{environment}-{resource-type}
Environment: dev (development), prod (production)
```

### Complete Resource Names

| Resource | Type | Name | Abbreviation |
|----------|------|------|--------------|
| **GCP Project** | Project | `cricket-analytics-dev` | N/A |
| **GCS Bucket - Raw Data** | Storage | `cricket-raw-data` (from config.yaml) | raw-bucket |
| **GCS Bucket - Dataflow Templates** | Storage | `cricket-dataflow-templates` (from config.yaml) | template-bucket |
| **GCS Bucket - Dataflow Temp** | Storage | `cricket-dataflow-temp` (from config.yaml) | temp-bucket |
| **BigQuery Dataset - Raw** | Dataset | `cricket_raw` | N/A |
| **BigQuery Dataset - Staging** | Dataset | `cricket_staging` | N/A |
| **BigQuery Dataset - Curated** | Dataset | `cricket_curated` | N/A |
| **Cloud Function** | Function | `cricket-gcs-dataflow-trigger` | gcs-trigger |
| **Dataflow Pipeline** | Pipeline | `cricket-batting-rankings-pipeline` | dataflow-pipeline |
| **Cloud Scheduler** | Job | `cricket-daily-ingestion` | scheduler |
| **Cloud Composer** | Airflow | `cricket-analytics-composer` | composer |
| **Looker Studio Dashboard** | Dashboard | `Cricket Batting Rankings Analytics` | dashboard |

---

## 📋 Prerequisites

Before starting, ensure you have:

- ✅ Google Cloud Account (free trial or paid)
- ✅ gcloud CLI installed
- ✅ `gcloud` authenticated with your account
- ✅ Project billing enabled
- ✅ RapidAPI key for Cricbuzz API
- ✅ Python 3.11+ installed locally

### Check Prerequisites

```bash
# Verify gcloud is installed
gcloud --version

# Verify authenticated
gcloud auth list

# Verify Python
python --version
```

---

## 🛠️ Step-by-Step Setup

### Phase 1: GCP Project & Authentication (5 minutes)

#### 1.1 Create GCP Project

**Option A: Via gcloud CLI**
```bash
# Create project
gcloud projects create cricket-analytics-dev \
  --name="Cricket Analytics Pipeline" \
  --set-as-default

# Get project ID
gcloud config get-value project
# Output: cricket-analytics-dev
```

**Option B: Via Google Cloud Console**
1. Go to: https://console.cloud.google.com/projectcreate
2. Project name: `Cricket Analytics Pipeline`
3. Project ID: `cricket-analytics-dev`
4. Click **Create**

#### 1.2 Set Project as Default

```bash
gcloud config set project cricket-analytics-dev
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```

#### 1.3 Enable Billing

```bash
# Link billing account
gcloud billing projects link cricket-analytics-dev \
  --billing-account=YOUR_BILLING_ACCOUNT_ID
```

Or via Console: https://console.cloud.google.com/billing/projects

#### 1.4 Setup Application Default Credentials

```bash
# Login for application use
gcloud auth application-default login

# This creates credentials at:
# ~/.config/gcloud/application_default_credentials.json
```

---

### Phase 2: Enable Required APIs (5 minutes)

```bash
# Enable all required APIs
gcloud services enable \
  storage.googleapis.com \
  bigquery.googleapis.com \
  dataflow.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudscheduler.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  eventarc.googleapis.com \
  logging.googleapis.com \
  compute.googleapis.com \
  composer.googleapis.com

# Verify all enabled
gcloud services list --enabled | grep -E "storage|bigquery|dataflow|functions|scheduler"
```

---

### Phase 3: Create Google Cloud Storage Buckets (5 minutes)

#### 3.1 Create Raw Data Bucket

```bash
# Create bucket for raw data ingestion
gsutil mb \
  -p cricket-analytics-dev \
  -l us-central1 \
  gs://cricket-analytics-raw-data

# Set lifecycle (keep 90 days)
gsutil lifecycle set - gs://cricket-analytics-raw-data <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}
EOF

# Create folder structure
gsutil -m mkdir gs://cricket-analytics-raw-data/batting/
```

#### 3.2 Create Dataflow Templates Bucket

```bash
# Bucket for Flex Templates
gsutil mb \
  -p cricket-analytics-dev \
  -l us-central1 \
  gs://cricket-analytics-dataflow-templates

# Create folder
gsutil -m mkdir gs://cricket-analytics-dataflow-templates/batting-pipeline/
```

#### 3.3 Create Dataflow Temp Bucket

```bash
# Temporary storage for Dataflow jobs
gsutil mb \
  -p cricket-analytics-dev \
  -l us-central1 \
  gs://cricket-analytics-dataflow-temp
```

#### 3.4 Verify Buckets

```bash
gsutil ls
# Output should show:
# gs://cricket-analytics-raw-data/
# gs://cricket-analytics-dataflow-templates/
# gs://cricket-analytics-dataflow-temp/
```

---

### Phase 4: Create BigQuery Datasets (5 minutes)

#### 4.1 Create Raw Dataset

```bash
bq mk \
  --dataset \
  --location=us-central1 \
  --description="Raw cricket data layer - exact copy from API" \
  --default_table_expiration=7776000 \
  cricket_raw
```

#### 4.2 Create Staging Dataset

```bash
bq mk \
  --dataset \
  --location=us-central1 \
  --description="Staging layer with star schema and dimensions" \
  cricket_staging
```

#### 4.3 Create Curated Dataset

```bash
bq mk \
  --dataset \
  --location=us-central1 \
  --description="Curated analytics layer - pre-joined views" \
  cricket_curated
```

#### 4.4 Verify Datasets

```bash
bq ls -d
# Output should show:
# cricket_raw
# cricket_staging
# cricket_curated
```

---

### Phase 5: Create Service Accounts (10 minutes)

#### 5.1 Create Dataflow Service Account

```bash
# Create service account
gcloud iam service-accounts create cricket-dataflow-sa \
  --display-name="Cricket Analytics Dataflow Service Account"

# Grant BigQuery Admin
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/bigquery.admin

# Grant Storage Admin
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/storage.admin

# Grant Dataflow Worker
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/dataflow.worker
```

#### 5.2 Create Cloud Function Service Account

```bash
# Create service account
gcloud iam service-accounts create cricket-cloud-function-sa \
  --display-name="Cricket Analytics Cloud Function Service Account"

# Grant Dataflow Admin
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-cloud-function-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/dataflow.admin

# Grant Storage Viewer
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-cloud-function-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/storage.objectViewer
```

#### 5.3 Create Composer Service Account

```bash
# Create service account
gcloud iam service-accounts create cricket-composer-sa \
  --display-name="Cricket Analytics Cloud Composer Service Account"

# Grant BigQuery Admin
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-composer-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/bigquery.admin

# Grant Dataflow Admin
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-composer-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/dataflow.admin

# Grant Storage Admin
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-composer-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/storage.admin
```

#### 5.4 Create Artifact Registry Service Account

```bash
# Create service account for Docker
gcloud iam service-accounts create cricket-artifact-registry-sa \
  --display-name="Cricket Analytics Artifact Registry Service Account"

# Grant Artifact Registry Writer
gcloud projects add-iam-policy-binding cricket-analytics-dev \
  --member=serviceAccount:cricket-artifact-registry-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --role=roles/artifactregistry.writer
```

---

### Phase 6: Create Artifact Registry (5 minutes)

```bash
# Create Docker repository
gcloud artifacts repositories create cricket-docker \
  --repository-format=docker \
  --location=us-central1 \
  --description="Docker repository for Cricket Analytics pipelines"

# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Verify
gcloud artifacts repositories list
```

---

### Phase 7: Create Cloud Scheduler Job (5 minutes)

```bash
# Create Cloud Scheduler job (runs daily at 06:00 UTC)
gcloud scheduler jobs create http cricket-daily-ingestion \
  --location=us-central1 \
  --schedule="0 6 * * *" \
  --uri="https://YOUR_CLOUD_RUN_URL/" \
  --http-method=POST \
  --message-body='{"action": "ingest"}' \
  --time-zone="UTC"

# Verify
gcloud scheduler jobs list --location=us-central1
```

---

### Phase 8: Create Cloud Function (10 minutes)

#### 8.1 Create Function Directory

```bash
# Create function files locally
mkdir -p cloud_function

# Copy main.py and requirements.txt from repository
cp cloud_function/main.py ./
cp cloud_function/requirements.txt ./
```

#### 8.2 Deploy Cloud Function

```bash
gcloud functions deploy cricket-gcs-dataflow-trigger \
  --gen2 \
  --runtime=python311 \
  --region=us-central1 \
  --source=./cloud_function \
  --entry-point=process_batting_file \
  --trigger-event-type=google.cloud.storage.object.v1.finalized \
  --trigger-resource=cricket-analytics-raw-data \
  --service-account=cricket-cloud-function-sa@cricket-analytics-dev.iam.gserviceaccount.com \
  --timeout=600 \
  --memory=512MB \
  --max-instances=10 \
  --set-env-vars=GCP_PROJECT=cricket-analytics-dev,GCP_REGION=us-central1,DATAFLOW_TEMPLATE_LOCATION=gs://cricket-analytics-dataflow-templates/batting-pipeline/metadata,BQ_DATASET=cricket_raw,BQ_TABLE=batting_rankings,TEMP_BUCKET=cricket-analytics-dataflow-temp

# Verify
gcloud functions list --gen2 --region=us-central1
```

---

### Phase 9: Create Cloud Composer (Airflow) (20 minutes)

```bash
# Create Cloud Composer environment
gcloud composer environments create cricket-analytics-composer \
  --location=us-central1 \
  --node-count=3 \
  --machine-type=n1-standard-4 \
  --python-version=3 \
  --airflow-version=2.7.3 \
  --service-account=cricket-composer-sa@cricket-analytics-dev.iam.gserviceaccount.com

# Wait for creation (5-15 minutes)
# Check status
gcloud composer environments describe cricket-analytics-composer \
  --location=us-central1

# Once created, get DAG bucket
gcloud composer environments describe cricket-analytics-composer \
  --location=us-central1 \
  --format="value(config.dagGcsPrefix)"
```

#### 9.2 Upload DAGs to Composer

```bash
# Get DAG bucket path
DAG_BUCKET=$(gcloud composer environments describe cricket-analytics-composer \
  --location=us-central1 \
  --format="value(config.dagGcsPrefix)")

# Upload DAG files
gsutil cp airflow/dags/cricket_analytics_dag.py ${DAG_BUCKET}/
gsutil cp airflow/dags/data_quality_monitoring_dag.py ${DAG_BUCKET}/

# Verify
gsutil ls ${DAG_BUCKET}/
```

---

### Phase 10: Update Configuration Files (5 minutes)

#### 10.1 Update config.yaml

```yaml
# config/config.yaml
gcp:
  project_id: "cricket-analytics-dev"
  region: "us-central1"

gcs:
  raw_bucket: "cricket-analytics-raw-data"
  raw_prefix: "batting/"
  template_bucket: "cricket-analytics-dataflow-templates"
  temp_bucket: "cricket-analytics-dataflow-temp"

bigquery:
  dataset_raw: "cricket_raw"
  dataset_staging: "cricket_staging"
  dataset_curated: "cricket_curated"
  table_raw_batting: "batting_rankings"

apis:
  rapidapi:
    base_url: "https://cricbuzz-cricket.p.rapidapi.com"
    endpoint: "/stats/v1/rankings/batsmen"
    api_key: "YOUR_RAPIDAPI_KEY"  # Add your RapidAPI key
    host: "cricbuzz-cricket.p.rapidapi.com"
    rank_type: "batsmen"
    request_timeout: 30

  formats:
    - test
    - odi
    - t20i

scheduling:
  ingestion_schedule: "0 6 * * *"
  dataflow_timeout_minutes: 30

dataflow:
  machine_type: "n1-standard-2"
  num_workers: 2
  max_workers: 5

looker:
  dashboard_title: "Cricket Batting Rankings Analytics"
  refresh_interval_minutes: 60
```

---

### Phase 11: Create Looker Studio Dashboard (15 minutes)

#### 11.1 Create Data Source

1. Go to: https://lookerstudio.google.com/
2. Click **+ Create** → **Data Source**
3. Select **BigQuery**
4. Choose your project: `cricket-analytics-dev`
5. Select dataset: `cricket_curated`

#### 11.2 Create Dashboard

1. Click **+ Create** → **Report**
2. Add the data source from above
3. Insert visualizations:

**Page 1: Current Rankings**
- Table: `vw_current_rankings`
- Columns: player_name, country_name, format, current_rank, current_rating
- Sort by: format, current_rank

**Page 2: Ranking Trends**
- Line Chart: `vw_ranking_trend`
- X-axis: full_date
- Y-axis: rank
- Dimension: player_name, format
- Time range: Last 90 days

**Page 3: Top 10 Players**
- Bar Chart: `vw_top10_by_format`
- X-axis: player_name
- Y-axis: current_rank
- Dimension: format
- Filter: format = selected

**Page 4: Country Summary**
- Pie Chart: `vw_country_summary`
- Dimension: country_name
- Metric: players_in_top10
- Dimension Slice: format

**Page 5: Format Comparison**
- Table: `vw_player_format_comparison`
- All columns displayed

#### 11.3 Name & Share Dashboard

```
Dashboard Name: Cricket Batting Rankings Analytics
Description: Daily ICC Men's Batting Rankings Analysis
Sharing: Set as needed (private/public/shared)
```

---

### Phase 12: Create BigQuery Tables & Views (10 minutes)

```bash
# Navigate to project directory
cd cricket-analytics-pipeline

# Run SQL scripts to create tables and views
for file in bigquery/sql/*.sql; do
  echo "Running: $file"
  bq query --use_legacy_sql=false < "$file"
done

# Verify tables created
bq ls cricket_raw
bq ls cricket_staging
bq ls cricket_curated
```

---

## ✅ Verification Checklist

### Resource Verification

```bash
# Verify Project
gcloud config list
# Expected: cricket-analytics-dev

# Verify APIs Enabled
gcloud services list --enabled | grep -E "storage|bigquery|dataflow|functions|scheduler|composer"

# Verify Storage Buckets
gsutil ls
# Expected: 3 buckets

# Verify BigQuery Datasets
bq ls -d
# Expected: cricket_raw, cricket_staging, cricket_curated

# Verify Service Accounts
gcloud iam service-accounts list

# Verify Cloud Function
gcloud functions list --gen2 --region=us-central1
# Expected: cricket-gcs-dataflow-trigger

# Verify Cloud Composer
gcloud composer environments list --locations=us-central1
# Expected: cricket-analytics-composer

# Verify Artifact Registry
gcloud artifacts repositories list
# Expected: cricket-docker
```

### Data Pipeline Verification

```bash
# Test ingestion script locally
cd ingestion
python fetch_batting_rankings.py

# Check data in GCS
gsutil ls gs://cricket-analytics-raw-data/batting/

# Check data in BigQuery
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM cricket_raw.batting_rankings"

# Check curated views
bq query --use_legacy_sql=false "SELECT * FROM cricket_curated.vw_current_rankings LIMIT 5"
```

---

## 🚀 Deployment & Testing

### Full End-to-End Test

#### 1. Test Ingestion Manually

```bash
cd ingestion
python fetch_batting_rankings.py

# Expected: CSV uploaded to gs://cricket-analytics-raw-data/batting/
```

#### 2. Verify Cloud Function Trigger

```bash
# Upload a test file to trigger Cloud Function
echo "test" | gsutil cp - gs://cricket-analytics-raw-data/batting/test.csv

# Check Cloud Function logs
gcloud functions logs read cricket-gcs-dataflow-trigger --gen2 --limit=10
```

#### 3. Monitor Dataflow Job

```bash
# List recent Dataflow jobs
gcloud dataflow jobs list --region=us-central1

# Get job details
gcloud dataflow jobs describe JOB_ID --region=us-central1
```

#### 4. Verify BigQuery Data

```bash
# Count records in raw table
bq query --use_legacy_sql=false \
  "SELECT COUNT(*), FORMAT FROM cricket_raw.batting_rankings GROUP BY FORMAT"

# Check staging tables
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM cricket_staging.fact_batting_rankings"

# Check curated views
bq query --use_legacy_sql=false "SELECT * FROM cricket_curated.vw_current_rankings LIMIT 10"
```

#### 5. Test Looker Studio Dashboard

1. Go to: https://lookerstudio.google.com/
2. Open your dashboard
3. Verify data is showing
4. Test filters and interactions

---

## 📊 Cost Estimation

| Service | Monthly Cost (Dev) | Notes |
|---------|-------------------|-------|
| **Cloud Storage (GCS)** | $0.50 - $1 | ~500GB data |
| **BigQuery** | $2 - $5 | On-demand queries |
| **Dataflow** | $1 - $2 | 1 job/day, 2-5 workers |
| **Cloud Functions** | $0.20 | Minimal invocations |
| **Cloud Scheduler** | $0.10 | 1 job/day |
| **Cloud Composer** | $3 - $5 | 3-node cluster |
| **Looker Studio** | FREE | Community edition |
| **TOTAL** | ~$7 - $18/month | Developer environment |

---

## 🔐 Security Best Practices

```bash
# 1. Set organization policies
gcloud resource-manager org-policies set-policy policy.yaml

# 2. Enable VPC for Cloud Composer
# (Configure during creation)

# 3. Set up Cloud Logging & Monitoring
gcloud logging sinks create cricket-analytics-sink \
  storage.googleapis.com/cricket-analytics-logs \
  --log-filter='resource.type="cloud_function"'

# 4. Enable audit logging
gcloud logging sinks create audit-sink \
  storage.googleapis.com/cricket-analytics-audit \
  --log-filter='protoPayload.serviceName="storage.googleapis.com"'
```

---

## 📞 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **API not enabled** | Run: `gcloud services enable SERVICE_NAME` |
| **Permission denied** | Check service account roles with `gcloud iam service-accounts get-iam-policy` |
| **Dataflow fails** | Check logs: `gcloud dataflow jobs list --region=us-central1` |
| **Cloud Function timeout** | Increase timeout in deployment command |
| **BigQuery quota exceeded** | Check billing account and set per-project limits |
| **Cloud Composer slow to create** | Normal - takes 10-15 minutes |

---

## 🎉 Success Criteria

You'll know everything is working when:

✅ All 3 GCS buckets created  
✅ All 3 BigQuery datasets created  
✅ All 4 service accounts with proper roles  
✅ Cloud Function deployed and listening  
✅ Cloud Scheduler job scheduled  
✅ Cloud Composer environment active  
✅ First data ingestion successful  
✅ Looker Studio dashboard showing live data  
✅ Monthly cost under $20  
✅ All resources accessible and functioning  

---

## 📝 Next Steps

1. **Execute this guide** step-by-step
2. **Update config.yaml** with your values
3. **Deploy the pipeline** using Terraform (optional)
4. **Monitor first ingestion** (06:00 UTC)
5. **Share dashboard** with team
6. **Set up alerts** for failures

---

## 🔗 Useful Links

- [GCP Console](https://console.cloud.google.com/)
- [Cloud Scheduler](https://console.cloud.google.com/cloudscheduler)
- [Cloud Functions](https://console.cloud.google.com/functions)
- [Cloud Composer](https://console.cloud.google.com/composer)
- [BigQuery](https://console.cloud.google.com/bigquery)
- [Looker Studio](https://lookerstudio.google.com/)
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)

---

**Created**: June 2026  
**Version**: 1.0  
**Status**: Production Ready  

For questions or updates, refer to [ARCHITECTURE.md](ARCHITECTURE.md) and [MODULE_DOCUMENTATION.md](MODULE_DOCUMENTATION.md)
