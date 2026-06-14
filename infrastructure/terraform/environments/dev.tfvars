# ============================================================================
# DEVELOPMENT ENVIRONMENT CONFIGURATION
# Light, cost-optimized setup for development
# ============================================================================

# Environment Selection
environment       = "dev"
environment_short = "dev"

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
  environment     = "development"
}

# ============================================================================
# BigQuery Configuration (Dev)
# ============================================================================

bq_dataset_prefix              = "dev_"
bq_location                    = "us-central1"
bq_dataset_expiration_days     = null  # No auto-deletion in dev
raw_table_partition_expiration = 90

raw_dataset_name      = "cricket_raw"
staging_dataset_name  = "cricket_staging"
curated_dataset_name  = "cricket_curated"
audit_dataset_name    = "cricket_audit_logs"

# ============================================================================
# GCS Bucket Configuration (Dev)
# ============================================================================

gcs_bucket_prefix     = "dev-cricket"
gcs_location          = "us-central1"
gcs_storage_class     = "STANDARD"
gcs_versioning_enabled = false  # No versioning in dev for cost savings

raw_data_bucket_name           = "raw-data"
dataflow_template_bucket_name  = "dataflow-templates"
dataflow_temp_bucket_name      = "dataflow-temp"
tf_state_bucket_name           = "tf-state"

# ============================================================================
# Dataflow Configuration (Dev - Lightweight)
# ============================================================================

dataflow_worker_machine_type = "n1-standard-2"  # Smallest machine type
dataflow_min_workers         = 2
dataflow_max_workers         = 3
dataflow_autoscaling_enabled = true

# ============================================================================
# Cloud Scheduler (Dev)
# ============================================================================

cloud_scheduler_enabled = true
cloud_scheduler_schedule = "0 6 * * *"  # Daily at 6 AM UTC
cloud_scheduler_timezone = "UTC"

# ============================================================================
# Service Accounts (Dev)
# ============================================================================

dataflow_service_account_name         = "cricket-dataflow-sa"
cloud_function_service_account_name   = "cricket-cloud-function-sa"
cloud_run_service_account_name        = "cricket-cloud-run-sa"
cloud_composer_service_account_name   = "cricket-composer-sa"

# ============================================================================
# Cloud Composer (Dev - Minimal)
# ============================================================================

cloud_composer_enabled       = true
cloud_composer_node_count    = 3    # Minimum required
cloud_composer_machine_type  = "n1-standard-4"
cloud_composer_disk_size_gb  = 30

# ============================================================================
# Monitoring & Alerting (Dev - Disabled)
# ============================================================================

monitoring_enabled = false  # No monitoring alerts in dev
alert_email        = ""

# ============================================================================
# Backup & Disaster Recovery (Dev - Disabled)
# ============================================================================

backup_enabled           = false  # No backups in dev
backup_frequency_hours   = 24
backup_retention_days    = 7

# ============================================================================
# Feature Flags (All Enabled for Testing)
# ============================================================================

api_ingestion_enabled           = true
dataflow_processing_enabled     = true
bigquery_transformation_enabled = true
