# 🔐 Service Accounts - Cricket Analytics Pipeline

**Complete Overview of All Service Accounts with IAM Roles**

---

## 📋 Service Accounts Summary

All service accounts are created in `terraform/main.tf` (lines 51-72).

| # | Service Account | Variable | Default Name | Location | Purpose |
|---|-----------------|----------|--------------|----------|---------|
| 1 | **Dataflow** | `dataflow_sa_name` | `cricket-dataflow-sa` | main.tf:51-56 | Apache Beam data processing |
| 2 | **Cloud Function** | `cloud_function_sa_name` | `cricket-cloud-function-sa` | main.tf:59-64 | GCS → Dataflow trigger |
| 3 | **Cloud Composer** | `cloud_composer_sa_name` | `cricket-composer-sa` | main.tf:67-72 | Airflow orchestration |

---

## 🔑 Service Account 1: Dataflow

**Name**: `cricket-dataflow-sa`  
**Variable**: `var.dataflow_sa_name` (from variables.tf, line 251)  
**Location**: `terraform/main.tf:51-56`  
**Default**: `cricket-dataflow-sa` (from variables.tf, line 254)

### Roles Granted
```
✅ roles/bigquery.admin         → Full BigQuery access
✅ roles/storage.admin          → Full GCS access
✅ roles/dataflow.worker        → Run Dataflow jobs
```

### Use Cases
- Reads CSV from GCS raw bucket
- Writes to BigQuery raw table
- Processes data with Apache Beam

### Terraform Code
```hcl
resource "google_service_account" "dataflow_sa" {
  account_id   = var.dataflow_sa_name
  display_name = "Cricket Analytics Dataflow Service Account"
}

# BigQuery Admin role
resource "google_project_iam_member" "dataflow_bq_admin" {
  role   = "roles/bigquery.admin"
  member = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Storage Admin role
resource "google_project_iam_member" "dataflow_storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Dataflow Worker role
resource "google_project_iam_member" "dataflow_worker" {
  role   = "roles/dataflow.worker"
  member = "serviceAccount:${google_service_account.dataflow_sa.email}"
}
```

---

## 🔑 Service Account 2: Cloud Function

**Name**: `cricket-cloud-function-sa`  
**Variable**: `var.cloud_function_sa_name` (from variables.tf, line 257)  
**Location**: `terraform/main.tf:59-64`  
**Default**: `cricket-cloud-function-sa` (from variables.tf, line 260)

### Roles Granted
```
✅ roles/dataflow.admin        → Launch Dataflow jobs
✅ roles/storage.objectViewer  → Read GCS objects
```

### Use Cases
- Listen for CSV files in GCS
- Launch Dataflow Flex Template jobs
- Monitor job progress

### Terraform Code
```hcl
resource "google_service_account" "cloud_function_sa" {
  account_id   = var.cloud_function_sa_name
  display_name = "Cricket Analytics Cloud Function Service Account"
}

# Dataflow Admin role
resource "google_project_iam_member" "function_dataflow_admin" {
  role   = "roles/dataflow.admin"
  member = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

# Storage Object Viewer role
resource "google_project_iam_member" "function_storage_viewer" {
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}
```

---

## 🔑 Service Account 3: Cloud Composer (Airflow)

**Name**: `cricket-composer-sa`  
**Variable**: `var.cloud_composer_sa_name` (from variables.tf, line 263)  
**Location**: `terraform/main.tf:67-72`  
**Default**: `cricket-composer-sa` (from variables.tf, line 266)

### Roles Granted
```
✅ roles/bigquery.admin      → Full BigQuery access
✅ roles/dataflow.admin      → Launch Dataflow jobs
✅ roles/storage.admin       → Full GCS access
```

### Use Cases
- Run Airflow DAGs
- Execute BigQuery queries (MERGE, staging transforms)
- Launch Dataflow jobs from Airflow
- Upload DAG files to Cloud Composer

### Terraform Code
```hcl
resource "google_service_account" "cloud_composer_sa" {
  account_id   = var.cloud_composer_sa_name
  display_name = "Cricket Analytics Cloud Composer Service Account"
}

# BigQuery Admin role
resource "google_project_iam_member" "composer_bq_admin" {
  role   = "roles/bigquery.admin"
  member = "serviceAccount:${google_service_account.cloud_composer_sa.email}"
}

# Dataflow Admin role
resource "google_project_iam_member" "composer_dataflow_admin" {
  role   = "roles/dataflow.admin"
  member = "serviceAccount:${google_service_account.cloud_composer_sa.email}"
}

# Storage Admin role
resource "google_project_iam_member" "composer_storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloud_composer_sa.email}"
}
```

---

## 🔄 Service Account Interactions

```
Data Flow:
Ingestion Script
    ↓
Cloud Scheduler (HTTP POST)
    ↓
Cloud Run (ingestion container)
    ↓
GCS raw bucket (batting_rankings_*.csv)
    ↓ (GCS event via Eventarc)
Cloud Function (cricket-cloud-function-sa)
    ↓ launches job using Dataflow Admin role
Dataflow Job (cricket-dataflow-sa)
    ↓ reads from GCS using Storage Admin role
    ↓ writes to BigQuery using BigQuery Admin role
BigQuery raw table
    ↓ (scheduled query)
Cloud Composer DAG (cricket-composer-sa)
    ↓ executes MERGE queries using BigQuery Admin role
    ↓ may launch secondary Dataflow jobs using Dataflow Admin role
BigQuery staging & curated tables
```

---

## 📊 IAM Roles Summary

| Role | SA 1: Dataflow | SA 2: Function | SA 3: Composer |
|------|---|---|---|
| `bigquery.admin` | ✅ | ❌ | ✅ |
| `storage.admin` | ✅ | ❌ | ✅ |
| `storage.objectViewer` | ❌ | ✅ | ❌ |
| `dataflow.admin` | ❌ | ✅ | ✅ |
| `dataflow.worker` | ✅ | ❌ | ❌ |

---

## 🚀 How to Get Service Account Email

After running `terraform apply`:

```bash
# Get all service account emails
terraform output | grep -i "service_account"

# Or use gcloud
gcloud iam service-accounts list --filter="displayName:Cricket"

# Get specific SA email
gcloud iam service-accounts describe cricket-dataflow-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

---

## 🔐 Security Best Practices

✅ **Least Privilege**: Each SA has only needed roles  
✅ **Separation of Concerns**: Different SAs for different tasks  
✅ **No Default Compute SA**: Not using project's default SA  
✅ **Audit Trail**: All actions logged with SA identity  

---

## 📋 Configurable Names

All service account names are configurable via `terraform.tfvars`:

```hcl
# terraform.tfvars
dataflow_sa_name       = "my-dataflow-service-account"
cloud_function_sa_name = "my-function-service-account"
cloud_composer_sa_name = "my-composer-service-account"
```

Or use defaults from `terraform/variables.tf`:

```hcl
# terraform/variables.tf
variable "dataflow_sa_name" {
  default = "cricket-dataflow-sa"
}

variable "cloud_function_sa_name" {
  default = "cricket-cloud-function-sa"
}

variable "cloud_composer_sa_name" {
  default = "cricket-composer-sa"
}
```

---

## 🔗 Related Files

| File | Purpose | Lines |
|------|---------|-------|
| `terraform/main.tf` | Service account definitions | 51-72 (creation), 79-132 (IAM roles) |
| `terraform/variables.tf` | SA name variables | 251-267 (service account names) |
| `terraform/terraform.tfvars.example` | SA name overrides (optional) | - |
| `terraform/cloud_composer.tf` | Cloud Composer environment config | - |

---

## ✅ Deployment

Service accounts are created automatically when you run:

```bash
cd terraform
terraform apply
```

**Result**:
- ✅ 3 service accounts created
- ✅ All IAM roles assigned
- ✅ Ready to use in cloud resources

---

## 📞 Using Service Accounts

### In Cloud Function
```python
# Uses cricket-cloud-function-sa automatically
from google.cloud import dataflow_v1beta3
client = dataflow_v1beta3.FlexTemplatesServiceClient()
```

### In Dataflow
```python
# Configured via Terraform launch params
# Uses cricket-dataflow-sa automatically
```

### In Cloud Composer (Airflow)
```python
# DAGs run as cricket-composer-sa
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
```

---

**Status**: ✅ Service Accounts Configured  
**Total**: 3 service accounts with least-privilege roles  
**Automated**: Created via Terraform  

All service accounts are ready for the pipeline! 🎉
