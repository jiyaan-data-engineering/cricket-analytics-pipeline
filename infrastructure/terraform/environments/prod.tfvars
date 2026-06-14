# ============================================================================
# PRODUCTION ENVIRONMENT CONFIGURATION
# Highly available, fully monitored, enterprise-grade setup
# ============================================================================

# Environment Selection
environment       = "prod"
environment_short = "prod"

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
  cost_center     = "operations"
  environment     = "production"
  protection      = "high"
  sla             = "99.9"
}

# ============================================================================
# BigQuery Configuration (Production)
# ============================================================================

bq_dataset_prefix              = "prod_"
bq_location                    = "us-central1"
bq_dataset_expiration_days     = null  # No auto-deletion in prod
raw_table_partition_expiration = 90

raw_dataset_name      = "cricket_raw"
staging_dataset_name  = "cricket_staging"
curated_dataset_name  = "cricket_curated"
audit_dataset_name    = "cricket_audit_logs"

# ============================================================================
# GCS Bucket Configuration (Production)
# ============================================================================

gcs_bucket_prefix     = "prod-cricket"
gcs_location          = "us-central1"
gcs_storage_class     = "STANDARD"
gcs_versioning_enabled = true  # Always version in production

raw_data_bucket_name           = "raw-data"
dataflow_template_bucket_name  = "dataflow-templates"
dataflow_temp_bucket_name      = "dataflow-temp"
tf_state_bucket_name           = "tf-state"

# ============================================================================
# Dataflow Configuration (Production - High Performance)
# ============================================================================

dataflow_worker_machine_type = "n1-standard-8"  # High-performance machines
dataflow_min_workers         = 5
dataflow_max_workers         = 20  # Can scale higher
dataflow_autoscaling_enabled = true

# ============================================================================
# Cloud Scheduler (Production)
# ============================================================================

cloud_scheduler_enabled = true
cloud_scheduler_schedule = "0 6 * * *"  # Daily at 6 AM UTC
cloud_scheduler_timezone = "UTC"

# ============================================================================
# Service Accounts (Production)
# ============================================================================

dataflow_service_account_name         = "cricket-dataflow-sa"
cloud_function_service_account_name   = "cricket-cloud-function-sa"
cloud_run_service_account_name        = "cricket-cloud-run-sa"
cloud_composer_service_account_name   = "cricket-composer-sa"

# ============================================================================
# Cloud Composer (Production - Enterprise)
# ============================================================================

cloud_composer_enabled       = true
cloud_composer_node_count    = 4   # HA configuration
cloud_composer_machine_type  = "n1-standard-8"  # More resources
cloud_composer_disk_size_gb  = 100 # More disk for prod logs

# ============================================================================
# Monitoring & Alerting (Production - Full)
# ============================================================================

monitoring_enabled = true
alert_email        = "alerts@company.com"  # Production alerts email

# ============================================================================
# Backup & Disaster Recovery (Production - Full)
# ============================================================================

backup_enabled           = true   # Hourly backups in production
backup_frequency_hours   = 1      # Every hour
backup_retention_days    = 90     # 3 months retention

# ============================================================================
# Feature Flags (All Enabled for Production)
# ============================================================================

api_ingestion_enabled           = true
dataflow_processing_enabled     = true
bigquery_transformation_enabled = true
