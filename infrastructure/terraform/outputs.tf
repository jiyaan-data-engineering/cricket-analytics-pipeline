# ============================================================================
# CRICKET ANALYTICS PIPELINE - PRODUCTION OUTPUTS
# ============================================================================

output "gcp_project_id" {
  value       = var.gcp_project_id
  description = "GCP Project ID"
}

output "gcp_region" {
  value       = var.gcp_region
  description = "GCP Region"
}

# ============================================================================
# GCS BUCKETS
# ============================================================================

output "raw_data_bucket" {
  value       = google_storage_bucket.raw_data.name
  description = "Raw data bucket name"
}

output "templates_bucket" {
  value       = google_storage_bucket.templates.name
  description = "Dataflow templates bucket name"
}

output "temp_bucket" {
  value       = google_storage_bucket.temp.name
  description = "Dataflow temp bucket name"
}

# Already created manually - commented out
# output "tf_state_bucket" {
#   value       = google_storage_bucket.tf_state.name
#   description = "Terraform state bucket name"
# }

# ============================================================================
# BIGQUERY DATASETS
# ============================================================================

output "raw_dataset" {
  value       = google_bigquery_dataset.raw.dataset_id
  description = "BigQuery raw dataset"
}

output "staging_dataset" {
  value       = google_bigquery_dataset.staging.dataset_id
  description = "BigQuery staging dataset"
}

output "curated_dataset" {
  value       = google_bigquery_dataset.curated.dataset_id
  description = "BigQuery curated dataset"
}

output "audit_logs_dataset" {
  value       = google_bigquery_dataset.audit_logs.dataset_id
  description = "BigQuery audit logs dataset"
}

# ============================================================================
# SERVICE ACCOUNTS
# ============================================================================

# Already created manually - commented out
# output "dataflow_service_account" {
#   value       = google_service_account.dataflow.email
#   description = "Dataflow service account email"
# }

output "cloud_function_service_account" {
  value       = google_service_account.cloud_function.email
  description = "Cloud Function service account email"
}

output "cloud_run_service_account" {
  value       = google_service_account.cloud_run.email
  description = "Cloud Run service account email"
}

output "cloud_composer_service_account" {
  value       = google_service_account.cloud_composer.email
  description = "Cloud Composer service account email"
}

# ============================================================================
# ARTIFACT REGISTRY
# ============================================================================

output "artifact_registry_repository" {
  value       = google_artifact_registry_repository.dataflow.repository_id
  description = "Artifact Registry repository for Dataflow templates"
}

output "artifact_registry_location" {
  value       = google_artifact_registry_repository.dataflow.location
  description = "Artifact Registry repository location"
}

# ============================================================================
# CLOUD FUNCTION
# ============================================================================

output "cloud_function_uri" {
  value       = google_cloudfunctions2_function.dataflow_trigger.service_config[0].uri
  description = "Cloud Function URI for testing"
}

output "eventarc_trigger_name" {
  value       = google_eventarc_trigger.gcs_to_dataflow.name
  description = "Eventarc trigger name"
}

# ============================================================================
# CLOUD RUN
# ============================================================================

output "cloud_run_ingestion_url" {
  value       = google_cloud_run_service.ingestion.status[0].url
  description = "Cloud Run ingestion service URL"
}

# ============================================================================
# CLOUD SCHEDULER
# ============================================================================

output "cloud_scheduler_job_name" {
  value       = google_cloud_scheduler_job.ingestion_trigger.name
  description = "Cloud Scheduler job name for daily ingestion"
}
