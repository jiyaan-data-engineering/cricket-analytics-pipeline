# 🔧 Terraform: Infrastructure as Code Guide

**Author**: Satish Mudde  
**Date**: 2026-06-07  
**Status**: Complete IaC for GCP  

Consolidated documentation for all Terraform configurations.

---

## 📋 Quick Navigation

- [Overview](#overview)
- [File Structure](#file-structure)
- [GCS Configuration](#gcs-configuration)
- [BigQuery Configuration](#bigquery-configuration)
- [All Resources](#all-resources)
- [Deployment](#deployment)
- [Variables Reference](#variables-reference)

---

## 📊 Overview

Complete Infrastructure as Code for Cricket Analytics Pipeline on GCP.

| Component | Status | Count | Details |
|-----------|--------|-------|---------|
| **GCS Buckets** | ✅ | 3 | Raw data, templates, temp |
| **BigQuery Datasets** | ✅ | 3 | Raw, staging, curated |
| **BigQuery Tables** | ✅ | 6 | 1 raw + 5 staging |
| **BigQuery Views** | ✅ | 6 | 1 raw + 5 curated |
| **Service Accounts** | ✅ | 3 | Dataflow, Function, Composer |
| **IAM Roles** | ✅ | 12+ | BigQuery, Storage, Dataflow |
| **Cloud Function** | ✅ | 1 | 2nd Gen Python |
| **Cloud Scheduler** | ✅ | 1 | Daily 06:00 UTC |
| **Cloud Composer** | ✅ | 1 | Airflow 2.7.3 |
| **Artifact Registry** | ✅ | 1 | Docker images |

---

## 📁 File Structure

```
terraform/
├── main.tf                          # Core infrastructure
│   ├─ Enable GCP APIs
│   ├─ Service accounts (3)
│   ├─ IAM roles (12+)
│   ├─ GCS buckets (via gcs.tf)
│   ├─ BigQuery datasets (via bigquery.tf)
│   ├─ Cloud Function
│   ├─ Cloud Scheduler
│   ├─ Eventarc trigger
│   └─ Artifact Registry
│
├── gcs.tf                           # Google Cloud Storage
│   ├─ cricket-raw-data (prevent_destroy)
│   ├─ cricket-dataflow-templates
│   └─ cricket-dataflow-temp
│
├── bigquery.tf                      # BigQuery (12 objects)
│   ├─ Datasets (3)
│   ├─ Tables (6)
│   │  ├─ raw_batting_rankings
│   │  ├─ dim_player
│   │  ├─ dim_country
│   │  ├─ dim_format
│   │  ├─ dim_date
│   │  └─ fact_batting_rankings
│   │
│   └─ Views (6)
│      ├─ vw_latest_raw
│      ├─ vw_batting_rankings_latest
│      ├─ vw_batting_rankings_90day_trend
│      ├─ vw_top_10_batsmen_by_format
│      ├─ vw_batting_statistics_by_country
│      └─ vw_ranking_comparison_cross_format
│
├── cloud_composer.tf                # Apache Airflow setup
│   ├─ Environment (3 nodes, n1-standard-4)
│   ├─ Service account
│   ├─ KMS encryption
│   ├─ DAG uploads
│   └─ Monitoring alerts
│
├── variables.tf                     # 30+ configurable variables
│   ├─ gcp_project_id
│   ├─ gcp_region
│   ├─ All bucket names
│   ├─ All dataset names
│   ├─ All table names
│   ├─ All view names
│   ├─ Service account names
│   └─ Dataflow settings
│
├── outputs.tf                       # Resource outputs
│   ├─ Bucket names & paths
│   ├─ Dataset names
│   ├─ Service account emails
│   └─ Cloud Function URL
│
├── terraform.tfvars.example         # Example values (COPY & CUSTOMIZE)
└── terraform.tfvars                 # YOUR VALUES (NOT COMMITTED)
```

---

## 🪣 GCS Configuration

### File: `terraform/gcs.tf`

**3 Buckets Created**:

```hcl
# 1. Raw Data Bucket (prevent_destroy = true)
resource "google_storage_bucket" "raw_data" {
  name          = "${var.bucket_prefix}-raw-data-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = false  # ⚠️ Protected from accidental deletion
  
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90  # Delete after 90 days
    }
  }
}

# 2. Dataflow Templates Bucket
resource "google_storage_bucket" "templates" {
  name = "${var.bucket_prefix}-dataflow-templates-${var.gcp_project_id}"
  # No lifecycle rules - templates kept forever
}

# 3. Dataflow Temp Bucket
resource "google_storage_bucket" "temp" {
  name = "${var.bucket_prefix}-dataflow-temp-${var.gcp_project_id}"
  # Auto-cleanup by Dataflow
}
```

**Features**:
- ✅ Unique names per project (prevent conflicts)
- ✅ Regional buckets (faster access)
- ✅ Lifecycle rules (auto-cleanup old data)
- ✅ prevent_destroy on raw data (safety)

### Configuration Variables

```hcl
variable "bucket_prefix" {
  default = "cricket-analytics"
}

variable "gcs_raw_bucket_name" {
  default = "cricket-analytics-raw-data"
}

variable "gcs_dataflow_templates_bucket" {
  default = "cricket-analytics-dataflow-templates"
}

variable "gcs_dataflow_temp_bucket" {
  default = "cricket-analytics-dataflow-temp"
}
```

---

## 📊 BigQuery Configuration

### File: `terraform/bigquery.tf`

**3 Datasets Created**:

```hcl
# 1. RAW Dataset
resource "google_bigquery_dataset" "raw" {
  dataset_id    = var.bq_raw_dataset
  friendly_name = "Cricket Analytics - Raw Layer"
  
  default_table_expiration_ms = 7776000000  # 90 days
  default_partition_expiration_ms = 7776000000
  
  access {
    role          = "OWNER"
    user_by_email = google_service_account.dataflow_sa.email
  }
}

# 2. STAGING Dataset
resource "google_bigquery_dataset" "staging" {
  dataset_id    = var.bq_staging_dataset
  friendly_name = "Cricket Analytics - Staging (Star Schema)"
  
  access {
    role          = "OWNER"
    user_by_email = google_service_account.dataflow_sa.email
  }
}

# 3. CURATED Dataset
resource "google_bigquery_dataset" "curated" {
  dataset_id    = var.bq_curated_dataset
  friendly_name = "Cricket Analytics - Curated (Views)"
  
  access {
    role          = "OWNER"
    user_by_email = google_service_account.dataflow_sa.email
  }
}
```

### 6 Tables + 6 Views (12 Objects Total)

**Tables**:
```hcl
# Raw layer
google_bigquery_table "raw_batting_rankings" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = var.bq_raw_table_name
  schema     = file("${path.module}/../bigquery/schemas/raw_batting_rankings.json")
}

# Staging dimensions
google_bigquery_table "dim_player"
google_bigquery_table "dim_country"
google_bigquery_table "dim_format"
google_bigquery_table "dim_date"

# Staging fact
google_bigquery_table "fact_batting_rankings"
```

**Views** (created via SQL):
```hcl
# Raw view
google_bigquery_routine "raw_vw_latest_raw"

# Curated views
google_bigquery_routine "curated_vw_batting_rankings_latest"
google_bigquery_routine "curated_vw_batting_rankings_90day_trend"
google_bigquery_routine "curated_vw_top_10_batsmen_by_format"
google_bigquery_routine "curated_vw_batting_statistics_by_country"
google_bigquery_routine "curated_vw_ranking_comparison_cross_format"
```

### SQL Placeholder Substitution

All SQL files use placeholders replaced at deployment time:

```hcl
resource "google_bigquery_routine" "view_example" {
  definition_body = replace(
    replace(
      replace(
        file("${path.module}/../bigquery/sql/vw_example.sql"),
        "{PROJECT_ID}",
        var.gcp_project_id
      ),
      "{STAGING_DATASET}",
      var.bq_staging_dataset
    ),
    "{CURATED_DATASET}",
    var.bq_curated_dataset
  )
}
```

**Placeholders**:
- `{PROJECT_ID}` → Your GCP project ID
- `{RAW_DATASET}` → cricket_raw
- `{STAGING_DATASET}` → cricket_staging
- `{CURATED_DATASET}` → cricket_curated

---

## 🔑 All Resources

### Service Accounts (3)

```hcl
# Dataflow Service Account
resource "google_service_account" "dataflow_sa" {
  account_id = var.dataflow_sa_name
}
# Roles: BigQuery Admin, Storage Admin, Dataflow Worker

# Cloud Function Service Account
resource "google_service_account" "cloud_function_sa" {
  account_id = var.cloud_function_sa_name
}
# Roles: Dataflow Admin, Storage Viewer

# Cloud Composer Service Account
resource "google_service_account" "cloud_composer_sa" {
  account_id = var.cloud_composer_sa_name
}
# Roles: BigQuery Admin, Dataflow Admin, Composer Worker
```

### IAM Roles (12+)

```hcl
# Dataflow
google_project_iam_member "dataflow_bq_admin"
google_project_iam_member "dataflow_storage_admin"
google_project_iam_member "dataflow_worker"
google_project_iam_member "dataflow_admin"

# Cloud Function
google_project_iam_member "function_dataflow_admin"
google_project_iam_member "function_storage_viewer"
google_project_iam_member "function_logging_writer"

# Cloud Composer
google_project_iam_member "composer_bigquery_admin"
google_project_iam_member "composer_dataflow_admin"
google_project_iam_member "composer_storage_admin"
google_project_iam_member "composer_composer_worker"
```

### Cloud Resources

```hcl
# Cloud Function 2nd Gen
google_cloudfunctions2_function "dataflow_trigger" {
  name        = var.cloud_function_name
  description = "GCS → Dataflow trigger"
  location    = var.gcp_region
  
  service_config {
    max_instance_count = 10
    timeout_seconds    = 600
    memory_mb          = 512
    
    service_account_email = google_service_account.cloud_function_sa.email
  }
  
  event_trigger {
    event_type   = "google.cloud.storage.object.v1.finalized"
    retry_policy = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.cloud_function_sa.email
  }
}

# Cloud Scheduler (Daily at 06:00 UTC)
resource "google_cloud_scheduler_job" "ingestion" {
  name             = var.scheduler_job_name
  schedule         = var.ingestion_schedule  # "0 6 * * *"
  time_zone        = "UTC"
  attempt_deadline = "600s"
  
  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.cloud_run_ingestion.service_config[0].uri
    
    oidc_token {
      service_account_email = google_service_account.cloud_function_sa.email
    }
  }
}

# Eventarc Trigger (GCS → Cloud Function)
resource "google_eventarc_trigger" "gcs_to_function" {
  name            = "gcs-to-dataflow-function"
  location        = var.gcp_region
  event_data_content_type = "application/json"
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
}

# Cloud Composer (Airflow)
resource "google_composer_environment" "main" {
  name   = var.composer_env_name
  region = var.gcp_region
  
  config {
    node_count = 3
    machine_type = "n1-standard-4"
    
    software_config {
      airflow_config_overrides = {
        "core-dags_are_paused_at_creation" = "true"
      }
    }
    
    encryption_config {
      kms_key_name = google_kms_crypto_key.composer_key.id
    }
  }
}

# Artifact Registry (Docker images)
resource "google_artifact_registry_repository" "docker" {
  repository_id = var.artifact_registry_name
  location      = var.gcp_region
  format        = "DOCKER"
}
```

---

## 🚀 Deployment

### Step 1: Initialize Terraform

```bash
cd terraform
terraform init
```

**What it does**:
- Downloads Google provider plugin
- Creates .terraform directory
- Initializes backend (local by default)

### Step 2: Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Required values**:
```hcl
gcp_project_id       = "your-gcp-project-id"
gcp_region          = "us-central1"
environment         = "dev"
bucket_prefix       = "cricket-analytics"
dataflow_machine_type = "n1-standard-2"
dataflow_num_workers = 2
dataflow_max_workers = 5
```

### Step 3: Plan Deployment

```bash
terraform plan -out=tfplan
```

**Review output**:
- 30+ resources will be created
- 3 buckets, 3 datasets, 12 BQ objects
- 3 service accounts, 12+ IAM roles
- Cloud Function, Scheduler, Composer

### Step 4: Apply

```bash
terraform apply tfplan
```

**Time**: ~10-15 minutes

**Outputs**:
- Bucket names
- Dataset names
- Service account emails
- Cloud Function URL

### Step 5: Verify

```bash
# Check GCS buckets
gsutil ls -b gs://cricket-analytics-*

# Check BigQuery datasets
bq ls

# Check service accounts
gcloud iam service-accounts list

# Check Cloud Function
gcloud functions describe cricket-gcs-dataflow-trigger --gen2 --region us-central1
```

---

## 📋 Variables Reference

All variables in `terraform/variables.tf`:

### GCP Configuration

```hcl
variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  default     = "us-central1"
}
```

### GCS Buckets

```hcl
variable "gcs_raw_bucket_name" {
  default = "cricket-analytics-raw-data"
}

variable "gcs_dataflow_templates_bucket" {
  default = "cricket-analytics-dataflow-templates"
}

variable "gcs_dataflow_temp_bucket" {
  default = "cricket-analytics-dataflow-temp"
}
```

### BigQuery Datasets

```hcl
variable "bq_raw_dataset" {
  default = "cricket_raw"
}

variable "bq_staging_dataset" {
  default = "cricket_staging"
}

variable "bq_curated_dataset" {
  default = "cricket_curated"
}
```

### BigQuery Tables

```hcl
variable "bq_raw_table_name" {
  default = "batting_rankings"
}

variable "bq_staging_table_dim_player" {
  default = "dim_player"
}

variable "bq_staging_table_dim_country" {
  default = "dim_country"
}

variable "bq_staging_table_dim_format" {
  default = "dim_format"
}

variable "bq_staging_table_dim_date" {
  default = "dim_date"
}

variable "bq_staging_table_fact_batting" {
  default = "fact_batting_rankings"
}
```

### Dataflow Settings

```hcl
variable "dataflow_machine_type" {
  default = "n1-standard-2"
}

variable "dataflow_num_workers" {
  default = 2
}

variable "dataflow_max_workers" {
  default = 5
}

variable "dataflow_timeout_minutes" {
  default = 30
}
```

---

## ✅ Pre-Deployment Checklist

- [ ] GCP project created
- [ ] Billing enabled
- [ ] terraform.tfvars filled
- [ ] `terraform plan` reviewed
- [ ] No hardcoded values in .tf files
- [ ] All variables in variables.tf
- [ ] .gitignore covers terraform.tfvars
- [ ] Service account permissions planned

---

## 🔧 Maintenance

### Update a Resource

```bash
# Edit terraform/main.tf or variables.tf
# Then:
terraform plan
terraform apply
```

### Destroy Infrastructure

```bash
# WARNING: This deletes everything except raw data bucket
terraform destroy

# Manually delete raw data bucket:
gsutil -m rm -r gs://cricket-analytics-raw-data-*
```

### Backup State

```bash
# State file: terraform.tfstate
cp terraform.tfstate terraform.tfstate.backup
```

---

## 📚 Related Files

- [GCP_SETUP_GUIDE.md](../GCP_SETUP_GUIDE.md) - GCP project setup
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture
- [SERVICE_ACCOUNTS.md](../SERVICE_ACCOUNTS.md) - IAM details

---

**Status**: ✅ Complete Terraform IaC  
**Author**: Satish Mudde  
**Last Updated**: 2026-06-07  

All infrastructure as code, zero manual setup required! 🚀
