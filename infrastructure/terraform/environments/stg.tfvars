# ============================================================================
# STAGING ENVIRONMENT CONFIGURATION
# Production-like setup with full monitoring for pre-production testing
# ============================================================================

# Environment Selection
environment       = "staging"
environment_short = "stg"

# GCP Project & Region
gcp_project_id = "cricbuzz-satish-dev"
gcp_region     = "us-central1"
gcp_zone       = "us-central1-a"

# Project Name
project_name = "cricket-analytics"

# Resource Labels
resource_labels = {
  managed_by      = "terraform"
  team            = "data-engineering"
  cost_center     = "engineering"
  environment     = "staging"
  protection      = "medium"
}

# ============================================================================
# BigQuery Configuration (Staging)
# ============================================================================

bq_dataset_prefix              = "stg_"
bq_location                    = "us-central1"
bq_dataset_expiration_days     = null  # No auto-deletion
raw_table_partition_expiration = 90

raw_dataset_name      = "cricket_raw"
staging_dataset_name  = "cricket_staging"
curated_dataset_name  = "cricket_curated"
audit_dataset_name    = "cricket_audit_logs"

# ============================================================================
# GCS Bucket Configuration (Staging)
# ============================================================================

gcs_bucket_prefix     = "stg-cricket"
gcs_location          = "us-central1"
gcs_storage_class     = "STANDARD"
gcs_versioning_enabled = true  # Enable versioning for staging

raw_data_bucket_name           = "raw-data"
dataflow_template_bucket_name  = "dataflow-templates"
dataflow_temp_bucket_name      = "dataflow-temp"
tf_state_bucket_name           = "tf-state"

# ============================================================================
# Dataflow Configuration (Staging - Medium)
# ============================================================================

dataflow_worker_machine_type = "n1-standard-4"  # Larger than dev
dataflow_min_workers         = 3
dataflow_max_workers         = 5
dataflow_autoscaling_enabled = true

# ============================================================================
# Cloud Scheduler (Staging)
# ============================================================================

cloud_scheduler_enabled = true
cloud_scheduler_schedule = "0 6 * * *"  # Daily at 6 AM UTC
cloud_scheduler_timezone = "UTC"

# ============================================================================
# Service Accounts (Staging)
# ============================================================================

dataflow_service_account_name         = "cricket-dataflow-sa"
cloud_function_service_account_name   = "cricket-cloud-function-sa"
cloud_run_service_account_name        = "cricket-cloud-run-sa"
cloud_composer_service_account_name   = "cricket-composer-sa"

# ============================================================================
# Cloud Composer (Staging - Production-like)
# ============================================================================

cloud_composer_enabled       = true
cloud_composer_node_count    = 3
cloud_composer_machine_type  = "n1-standard-4"
cloud_composer_disk_size_gb  = 50  # More disk for staging

# ============================================================================
# Monitoring & Alerting (Staging - Enabled)
# ============================================================================

monitoring_enabled = true
alert_email        = "alerts-staging@company.com"  # Replace with actual email

# ============================================================================
# Backup & Disaster Recovery (Staging - Light)
# ============================================================================

backup_enabled           = true   # Daily backups in staging
backup_frequency_hours   = 24
backup_retention_days    = 14    # 2 weeks retention

# ============================================================================
# Feature Flags (All Enabled)
# ============================================================================

api_ingestion_enabled           = true
dataflow_processing_enabled     = true
bigquery_transformation_enabled = true
