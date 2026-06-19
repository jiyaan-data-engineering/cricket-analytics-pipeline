# ============================================================================
# TERRAFORM CONFIGURATION VALUES
# ============================================================================
# This file contains all configuration values. Update these values to match
# your environment before deployment.

# GCP Configuration
gcp_project_id = "cricket-analytics-prod"
gcp_region     = "us-central1"
environment    = "prod"

# GCS Bucket Names
raw_data_bucket_name              = "cricket-raw-data-prod"
dataflow_templates_bucket_name    = "cricket-dataflow-templates-prod"
dataflow_temp_bucket_name         = "cricket-dataflow-temp-prod"

# BigQuery Dataset Names
raw_dataset_name     = "cricket_raw"
staging_dataset_name = "cricket_staging"
curated_dataset_name = "cricket_curated"
audit_logs_dataset_name = "cricket_audit_logs"

# Service Account
composer_service_account_id = "cricket-composer-sa"

# Cloud Composer
composer_env_name   = "cricket-analytics-composer"
composer_node_count = 3
composer_machine_type = "n1-standard-4"

# DAG Configuration
dag_schedule = "0 6 * * *"  # Daily at 06:00 UTC

# Dataflow Configuration
dataflow_worker_count_min    = 2
dataflow_worker_count_max    = 5
dataflow_worker_machine_type = "n1-standard-2"

# Tags and Labels
common_labels = {
  project     = "cricket-analytics"
  managed_by  = "terraform"
  environment = "prod"
  created_at  = "2026-06-19"
}
