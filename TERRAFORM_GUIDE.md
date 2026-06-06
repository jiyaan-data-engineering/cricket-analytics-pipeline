# 🏗️ Terraform Infrastructure as Code Guide

**Cricket Analytics Pipeline - Infrastructure Deployment**

---

## 📋 Overview

This guide explains how to deploy the entire Cricket Analytics Pipeline infrastructure using Terraform, with **all resource names configurable via variables**.

---

## 🎯 What Gets Created

| Resource | Configurable Name | Count |
|----------|-------------------|-------|
| **GCS Buckets** | `gcs_raw_bucket_name`, `gcs_templates_bucket_name`, `gcs_temp_bucket_name` | 3 |
| **BigQuery Datasets** | `bq_raw_dataset`, `bq_staging_dataset`, `bq_curated_dataset` | 3 |
| **BigQuery Tables** | `bq_raw_table_name` | 1 |
| **Cloud Function** | `cloud_function_name` | 1 |
| **Dataflow** | `dataflow_pipeline_name` | Template |
| **Cloud Scheduler** | `cloud_scheduler_job_name` | 1 |
| **Cloud Composer** | `cloud_composer_name` | 1 |
| **Service Accounts** | `*_sa_name` | 3 |
| **Artifact Registry** | `artifact_registry_name` | 1 |

---

## 📁 File Structure

```
terraform/
├── main.tf                      # Core GCP resources (APIs, SAs, Cloud Function, Scheduler, Composer, Monitoring)
├── gcs.tf                       # GCS buckets (reads from config/config.yaml)
├── bigquery.tf                  # BigQuery datasets & tables (reads from SQL/schema files)
├── cloud_composer.tf            # Cloud Composer configuration
├── variables.tf                 # ALL configurable variables
├── outputs.tf                   # Resource outputs
├── terraform.tfvars.example     # Example values (COPY THIS)
└── terraform.tfvars            # Your actual values (CREATE FROM EXAMPLE)
```

**Key Architecture**:
- `config/config.yaml` is the **SOURCE OF TRUTH** for bucket and dataset names
- `terraform/gcs.tf` reads bucket names from `config/config.yaml`
- `terraform/bigquery.tf` reads schemas and SQL from existing files
- Variables in `terraform/variables.tf` allow OVERRIDES (optional)

---

## 🚀 Quick Start

### Step 1: Clone & Navigate

```bash
cd cricket-analytics-pipeline/terraform
```

### Step 2: Create terraform.tfvars

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars  # or use your favorite editor
```

### Step 3: Update terraform.tfvars

```hcl
# Required: Set these values
gcp_project_id = "YOUR_GCP_PROJECT_ID"
rapidapi_key   = "YOUR_RAPIDAPI_KEY"

# Optional: Customize resource names
gcs_raw_bucket_name = "my-raw-data-bucket"
cloud_function_name = "my-gcs-trigger"
cloud_composer_name = "my-airflow-env"
# ... customize others as needed
```

### Step 4: Initialize Terraform

```bash
terraform init
```

### Step 5: Plan Deployment

```bash
terraform plan
```

Review the output and verify all resources will be created correctly.

### Step 6: Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

---

## 📝 Configuration Variables

### GCP Project Configuration

```hcl
gcp_project_id = "cricket-analytics-dev"    # Your GCP project
gcp_region     = "us-central1"              # GCP region
gcp_zone       = "us-central1-a"            # GCP zone
environment    = "dev"                      # dev/staging/prod
```

### GCS Bucket Names

Bucket names are sourced from `config/config.yaml` (primary source):
```yaml
gcs:
  raw_bucket: "cricket-raw-data"
  template_bucket: "cricket-dataflow-templates"
  temp_bucket: "cricket-dataflow-temp"
  raw_prefix: "batting/"
```

Can be overridden via `terraform/terraform.tfvars` (optional):
```hcl
gcs_raw_bucket_name       = "my-raw-bucket"
gcs_templates_bucket_name = "my-templates"
gcs_temp_bucket_name      = "my-temp"
gcs_raw_prefix            = "batting/"
```

**Change if**: You want different bucket names
**Note**: Primary source is `config/config.yaml`; override via `terraform.tfvars` if needed

### BigQuery Configuration

Dataset names are sourced from `config/config.yaml`:
```yaml
bigquery:
  dataset_raw: "cricket_raw"
  dataset_staging: "cricket_staging"
  dataset_curated: "cricket_curated"
  table_raw_batting: "batting_rankings"
```

Can be overridden in `terraform/terraform.tfvars`:
```hcl
bq_raw_dataset           = "cricket_raw"
bq_staging_dataset       = "cricket_staging"
bq_curated_dataset       = "cricket_curated"
bq_raw_table_name        = "batting_rankings"
bq_table_expiration_days = 90
```

Table schema is defined in:
- `bigquery/schemas/raw_batting_rankings.json` (loaded by terraform/bigquery.tf)

SQL logic is defined in:
- `bigquery/sql/01_create_raw_table.sql` through `07_create_curated_views.sql`

**Change if**: You prefer different dataset/table names
**Note**: Primary source is `config/config.yaml`; SQL files are source of truth for schemas

### Cloud Function Configuration

```hcl
cloud_function_name         = "cricket-gcs-dataflow-trigger"
cloud_function_timeout      = 600          # seconds
cloud_function_memory       = 512          # MB
cloud_function_max_instances = 10          # concurrent instances
```

**Change if**: You want different function name or limits

### Dataflow Configuration

```hcl
dataflow_pipeline_name     = "cricket-batting-rankings-pipeline"
dataflow_machine_type      = "n1-standard-2"
dataflow_num_workers       = 2
dataflow_max_workers       = 5
dataflow_template_location = "gs://cricket-analytics-dataflow-templates/batting-pipeline/metadata"
```

**Change if**: You need more/fewer workers or different machine type

### Cloud Scheduler Configuration

```hcl
cloud_scheduler_job_name = "cricket-daily-ingestion"
cloud_scheduler_schedule = "0 6 * * *"    # Cron: daily at 06:00 UTC
cloud_scheduler_timezone = "UTC"
```

**Change if**: You want different schedule

### Cloud Composer (Airflow) Configuration

```hcl
cloud_composer_name            = "cricket-analytics-composer"
cloud_composer_machine_type    = "n1-standard-4"
cloud_composer_node_count      = 3
cloud_composer_disk_size       = 30
cloud_composer_airflow_version = "2.7.3"
enable_cloud_composer          = true
```

**Change if**: You want different Airflow setup

### Service Account Names

```hcl
dataflow_sa_name       = "cricket-dataflow-sa"
cloud_function_sa_name = "cricket-cloud-function-sa"
cloud_composer_sa_name = "cricket-composer-sa"
```

**Change if**: You want different service account names

### Labels

```hcl
labels = {
  project     = "cricket-analytics"
  environment = "dev"
  managed_by  = "terraform"
  team        = "data-engineering"
}
```

**Change if**: You use different labeling strategy

---

## 🔄 Common Terraform Commands

### Initialize Terraform

```bash
terraform init
```

### Validate Configuration

```bash
terraform validate
```

### Format Code

```bash
terraform fmt -recursive
```

### View Plan (dry-run)

```bash
terraform plan
terraform plan -out=tfplan
```

### Apply Configuration

```bash
terraform apply
terraform apply tfplan
```

### Destroy Resources

```bash
terraform destroy
```

**Warning**: This will delete all infrastructure!

### Show State

```bash
terraform show
terraform state list
terraform state show google_storage_bucket.raw_data
```

### Refresh State

```bash
terraform refresh
```

### Get Output Values

```bash
terraform output
terraform output gcs_raw_bucket_url
```

---

## 📊 Example Customizations

### Scenario 1: Change All Bucket Names

```hcl
gcs_raw_bucket_name       = "my-project-raw"
gcs_templates_bucket_name = "my-project-templates"
gcs_temp_bucket_name      = "my-project-temp"
```

Then apply:

```bash
terraform plan
terraform apply
```

### Scenario 2: Use Production Naming

```hcl
environment = "prod"

gcs_raw_bucket_name       = "cricket-prod-raw-data"
cloud_function_name       = "cricket-prod-gcs-trigger"
cloud_composer_name       = "cricket-prod-composer"

dataflow_num_workers      = 5
dataflow_max_workers      = 10

cloud_composer_node_count = 5
cloud_composer_disk_size  = 100
```

### Scenario 3: Disable Airflow

```hcl
enable_cloud_composer = false
```

This skips Cloud Composer creation to save costs.

---

## 🔍 Verify Deployment

### Check Resource Creation

```bash
# List all resources
terraform show

# Check specific resource
terraform state show google_storage_bucket.raw_data
terraform state show google_bigquery_dataset.raw
```

### View Terraform Outputs

```bash
terraform output

# Expected output:
# gcs_raw_bucket_url = "gs://cricket-analytics-raw-data"
# dataflow_sa_email = "cricket-dataflow-sa@project.iam.gserviceaccount.com"
# cloud_function_url = "https://..."
# cloud_composer_dag_bucket = "gs://..."
```

### Verify in GCP Console

1. **GCS Buckets**: https://console.cloud.google.com/storage
2. **BigQuery**: https://console.cloud.google.com/bigquery
3. **Cloud Functions**: https://console.cloud.google.com/functions
4. **Cloud Composer**: https://console.cloud.google.com/composer
5. **Cloud Scheduler**: https://console.cloud.google.com/cloudscheduler

---

## 🔐 Security Best Practices

### 1. Never Commit Secrets

```bash
# Add to .gitignore
echo "terraform.tfvars" >> .gitignore
echo ".terraform/" >> .gitignore
echo "*.tfstate*" >> .gitignore
```

### 2. Use Environment Variables for Sensitive Data

```bash
export TF_VAR_rapidapi_key="your_actual_key"
terraform plan
```

### 3. Store State Remotely

```bash
# Configure remote state
terraform remote config -backend=gcs -backend-config="bucket=YOUR_BUCKET" -backend-config="prefix=terraform/state"
```

### 4. Use Terraform Cloud

```bash
# Sign up at https://app.terraform.io
terraform login
# Set organization and workspace
```

---

## 🐛 Troubleshooting

### Error: "API not enabled"

**Solution**: Terraform will try to enable APIs, but you can manually enable them:

```bash
gcloud services enable storage.googleapis.com bigquery.googleapis.com
```

### Error: "Permission denied"

**Solution**: Check service account permissions:

```bash
gcloud projects get-iam-policy cricket-analytics-dev --flatten="bindings[].members" | grep cricket-
```

### Error: "Project not found"

**Solution**: Verify project exists and is set:

```bash
gcloud projects list
gcloud config set project cricket-analytics-dev
```

### Terraform State Lock

**Solution**: If stuck, you can forcefully unlock:

```bash
terraform force-unlock LOCK_ID
```

---

## 📈 Cost Estimation

```bash
# Estimate costs before applying
terraform plan -out=tfplan

# Estimated monthly costs (dev environment):
# GCS:      $0.50 - $1.00
# BigQuery: $2.00 - $5.00
# Dataflow: $1.00 - $2.00
# Composer: $3.00 - $5.00
# Function: $0.20
# Scheduler: $0.10
# TOTAL:   ~$7.00 - $18.00/month
```

---

## 🔄 Update Existing Infrastructure

### Change Configuration

```hcl
# Edit terraform.tfvars
cloud_composer_node_count = 5
dataflow_max_workers = 10
```

### Plan & Apply Changes

```bash
terraform plan      # Review changes
terraform apply     # Apply changes
```

Terraform will only update changed resources.

---

## 🗑️ Cleanup

### Destroy All Resources

```bash
# WARNING: This deletes everything!
terraform destroy
```

### Destroy Specific Resource

```bash
# Destroy only Cloud Composer
terraform destroy -target=google_composer_environment.cricket
```

### Keep Resources, Remove Terraform

```bash
# Remove terraform state without deleting resources
rm -rf .terraform terraform.tfstate*
```

---

## 📚 File Reference

### variables.tf
Contains all input variables with:
- `description`: What the variable does
- `type`: Variable type (string, number, bool, map)
- `default`: Default value (if optional)
- All defaults align with `config/config.yaml` values

### main.tf
Contains core infrastructure definitions:
- API services enablement
- Service accounts (lines 51-72)
- IAM role assignments (lines 79-132)
- Cloud Function 2nd Gen
- Cloud Function source bucket
- Cloud Scheduler job
- Cloud Composer environment (optional)
- Artifact Registry
- Monitoring & alerts (optional)

### gcs.tf
GCS bucket management:
- Reads bucket names from `config/config.yaml`
- Allows overrides via `terraform/variables.tf`
- Creates 3 buckets: raw_data, dataflow_templates, dataflow_temp
- Includes lifecycle rules for retention
- References: `config/config.yaml` (gcs section)

### bigquery.tf
BigQuery management:
- Reads schemas from `bigquery/schemas/raw_batting_rankings.json`
- Reads SQL logic from `bigquery/sql/*.sql` files
- Creates 3 datasets: raw, staging, curated
- Creates table placeholders with partitioning/clustering
- Substitutes {PROJECT_ID} in SQL files
- References:
  - `bigquery/schemas/raw_batting_rankings.json`
  - `bigquery/sql/01_create_raw_table.sql`
  - `bigquery/sql/07_create_curated_views.sql`

### cloud_composer.tf
Cloud Composer environment (optional):
- Airflow configuration
- Python packages pre-installation
- Environment variables setup

### outputs.tf
Exports important values for reference:
- Bucket URLs
- Dataset IDs
- Service account emails
- Function URL
- Composer DAG bucket
- All GCS bucket names (sourced from `config/config.yaml`)

### terraform.tfvars
Your actual values (not committed to git):
- GCP project ID
- Resource names (defaults from `config/config.yaml`)
- Configuration values
- API keys

---

## ✅ Success Criteria

You'll know Terraform deployment succeeded when:

✅ All `terraform apply` shows "Apply complete"  
✅ All GCS buckets created and visible  
✅ All BigQuery datasets created  
✅ Cloud Function deployed  
✅ Cloud Scheduler job visible  
✅ Cloud Composer environment running  
✅ Service accounts created with proper roles  
✅ `terraform output` shows all resource names  
✅ No errors in GCP console  
✅ Monthly cost within budget  

---

## 🎉 Next Steps

1. **Copy terraform.tfvars.example** → `terraform.tfvars`
2. **Update values** in terraform.tfvars
3. **Run `terraform init`**
4. **Run `terraform plan`** to review
5. **Run `terraform apply`** to deploy
6. **Verify** all resources in GCP console
7. **Deploy application code** to Cloud Function
8. **Deploy DAGs** to Cloud Composer
9. **Test end-to-end** pipeline

---

## 📞 Additional Resources

- [Terraform Docs](https://www.terraform.io/docs)
- [Google Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/cloud-docs/recommended-practices)
- [GCP Documentation](https://cloud.google.com/docs)

---

**Version**: 1.0  
**Last Updated**: June 2026  
**Status**: Production Ready  

For questions, refer to [GCP_SETUP_GUIDE.md](GCP_SETUP_GUIDE.md)
