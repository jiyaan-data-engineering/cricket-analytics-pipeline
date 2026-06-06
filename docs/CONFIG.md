# ⚙️ Configuration: config.yaml Reference

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete Configuration Guide

Complete reference for config/config.yaml and configuration management.

---

## 📋 Overview

**Purpose**: Single source of truth for all configurable values  
**Format**: YAML  
**Location**: `config/config.yaml`  
**Usage**: Read by Python scripts, Terraform, Dataflow  

---

## 🎯 Complete config.yaml

```yaml
# GCP Configuration
gcp:
  project_id: "your-gcp-project-id"
  region: "us-central1"
  zone: "us-central1-a"

# Google Cloud Storage Configuration
gcs:
  raw_bucket: "cricket-raw-data"
  raw_prefix: "batting/"
  template_bucket: "cricket-dataflow-templates"
  temp_bucket: "cricket-dataflow-temp"

# BigQuery Configuration
bigquery:
  dataset_raw: "cricket_raw"
  dataset_staging: "cricket_staging"
  dataset_curated: "cricket_curated"
  table_raw_batting: "batting_rankings"

# API Configuration
apis:
  rapidapi:
    base_url: "https://cricbuzz-cricket.p.rapidapi.com"
    endpoint: "/stats/v1/rankings/batsmen"
    api_key: "${RAPIDAPI_KEY}"  # From environment variable only!
    host: "cricbuzz-cricket.p.rapidapi.com"
    rank_type: "batsmen"
    request_timeout: 30
  
  formats:
    - test
    - odi
    - t20i

# Scheduling Configuration
scheduling:
  ingestion_schedule: "0 6 * * *"  # Cron: Daily 06:00 UTC
  dataflow_timeout_minutes: 30

# Dataflow Configuration
dataflow:
  machine_type: "n1-standard-2"
  num_workers: 2
  max_workers: 5

# Looker Studio Configuration
looker:
  dashboard_title: "Cricket Batting Rankings Analytics"
  refresh_interval_minutes: 60
```

---

## 🔑 Configuration Reference

### GCP Section

```yaml
gcp:
  project_id: "your-gcp-project-id"        # Required: Your GCP project ID
  region: "us-central1"                     # Required: GCP region (us-central1, europe-west1, etc.)
  zone: "us-central1-a"                     # Optional: Specific zone for Compute resources
```

**Where used**:
- Terraform: `var.gcp_project_id`, `var.gcp_region`
- Python: Environment variable `GCP_PROJECT`
- BigQuery: Dataset location
- Cloud Scheduler: Execution region

### GCS Section

```yaml
gcs:
  raw_bucket: "cricket-raw-data"            # GCS bucket for CSV files
  raw_prefix: "batting/"                    # Folder prefix inside bucket
  template_bucket: "cricket-dataflow-templates"  # Dataflow Flex Template storage
  temp_bucket: "cricket-dataflow-temp"      # Dataflow temporary staging location
```

**Where used**:
- Terraform: Bucket creation
- Ingestion: Upload CSV files
- Cloud Function: Detect CSV files
- Dataflow: Read input, write temp files

### BigQuery Section

```yaml
bigquery:
  dataset_raw: "cricket_raw"                # Raw layer dataset
  dataset_staging: "cricket_staging"        # Staging layer dataset
  dataset_curated: "cricket_curated"        # Curated layer dataset
  table_raw_batting: "batting_rankings"     # Raw table name
```

**Where used**:
- Terraform: Dataset creation
- Dataflow: Output table specification
- SQL files: Placeholder substitution
- Looker Studio: Data source

### APIs Section

```yaml
apis:
  rapidapi:
    base_url: "https://cricbuzz-cricket.p.rapidapi.com"
    endpoint: "/stats/v1/rankings/batsmen"  # API endpoint path
    api_key: "${RAPIDAPI_KEY}"              # Environment variable reference (NEVER hardcoded!)
    host: "cricbuzz-cricket.p.rapidapi.com" # Host header value
    rank_type: "batsmen"                    # Always "batsmen" for batting rankings
    request_timeout: 30                     # HTTP request timeout in seconds
  
  formats:                                  # Cricket formats to fetch
    - test
    - odi
    - t20i
```

**Where used**:
- Ingestion: API authentication, endpoint URL, timeouts
- Cloud Function: Format validation

### Scheduling Section

```yaml
scheduling:
  ingestion_schedule: "0 6 * * *"  # Cron expression (Daily 06:00 UTC)
  dataflow_timeout_minutes: 30     # Max job execution time
```

**Cron Format**: `minute hour day month day_of_week`
- `0 6 * * *` = Every day at 06:00 UTC
- `0 6 * * 1` = Every Monday at 06:00 UTC
- `0 */6 * * *` = Every 6 hours

**Where used**:
- Cloud Scheduler: Job scheduling
- Terraform: Scheduler configuration
- Airflow: DAG schedule

### Dataflow Section

```yaml
dataflow:
  machine_type: "n1-standard-2"    # Machine type for workers
  num_workers: 2                   # Initial number of workers
  max_workers: 5                   # Maximum for autoscaling
```

**Options**:
- Machine types: n1-standard-1, n1-standard-2, n1-standard-4
- num_workers: Start with 2, scale to max_workers
- max_workers: Set based on data volume

**Where used**:
- Terraform: Dataflow worker configuration
- Cloud Function: Job launch parameters

### Looker Section

```yaml
looker:
  dashboard_title: "Cricket Batting Rankings Analytics"
  refresh_interval_minutes: 60     # How often to refresh dashboard
```

**Where used**:
- Documentation (reference only)
- Manual Looker Studio setup

---

## 🔐 Security Considerations

### API Key Management

```yaml
api_key: "${RAPIDAPI_KEY}"  # ✅ Correct: Environment variable reference
```

**NEVER do this**:
```yaml
api_key: "68711780e9msh5801f4e4a2e884fp161186jsnbe9a5031365d"  # ❌ WRONG! Hardcoded!
```

**How to set environment variable**:
```bash
# Linux/Mac
export RAPIDAPI_KEY="your-actual-key-here"

# Windows PowerShell
$env:RAPIDAPI_KEY = "your-actual-key-here"

# Windows Command Prompt
set RAPIDAPI_KEY=your-actual-key-here
```

---

## 📝 Customization Examples

### Development Environment

```yaml
gcp:
  project_id: "cricket-dev-project"
  region: "us-central1"

bigquery:
  dataset_raw: "cricket_raw_dev"
  dataset_staging: "cricket_staging_dev"
  dataset_curated: "cricket_curated_dev"

dataflow:
  machine_type: "n1-standard-1"
  num_workers: 1
  max_workers: 2

scheduling:
  ingestion_schedule: "0 6 * * *"  # Daily
```

### Production Environment

```yaml
gcp:
  project_id: "cricket-prod-project"
  region: "us-central1"

bigquery:
  dataset_raw: "cricket_raw"
  dataset_staging: "cricket_staging"
  dataset_curated: "cricket_curated"

dataflow:
  machine_type: "n1-standard-4"
  num_workers: 5
  max_workers: 20

scheduling:
  ingestion_schedule: "0 6 * * *"  # Daily
  dataflow_timeout_minutes: 60
```

---

## 📊 How Configuration Flows

```
config.yaml (Source of Truth)
    ↓
ingestion/fetch_batting_rankings.py (Reads for APIs, GCS)
    ↓
dataflow/pipeline.py (Reads for BigQuery dataset)
    ↓
cloud_function/main.py (Reads for Dataflow template, BQ dataset)
    ↓
Terraform variables.tf (Defaults from config)
    ↓
GCP Infrastructure (Created based on config values)
```

---

## ✅ Configuration Checklist

Before deploying:

- [ ] `gcp.project_id` set to your GCP project
- [ ] `gcp.region` matches your region (default: us-central1)
- [ ] `apis.rapidapi.api_key` uses `${RAPIDAPI_KEY}` (environment variable)
- [ ] `RAPIDAPI_KEY` environment variable is set
- [ ] `scheduling.ingestion_schedule` is valid cron expression
- [ ] `dataflow.max_workers` >= num_workers

---

**Status**: ✅ Configuration Complete  
**File Location**: `config/config.yaml`  
**Last Updated**: 2026-06-07  

Centralized configuration management! ⚙️
