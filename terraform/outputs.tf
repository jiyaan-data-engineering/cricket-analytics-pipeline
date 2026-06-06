output "gcp_project_id" {
  value       = var.gcp_project_id
  description = "GCP Project ID"
}

output "raw_data_bucket" {
  value       = google_storage_bucket.raw_data.name
  description = "GCS bucket for raw data landing"
}

output "dataflow_templates_bucket" {
  value       = google_storage_bucket.dataflow_templates.name
  description = "GCS bucket for Dataflow Flex Templates"
}

output "dataflow_temp_bucket" {
  value       = google_storage_bucket.dataflow_temp.name
  description = "GCS bucket for Dataflow temp files"
}

output "dataflow_service_account_email" {
  value       = google_service_account.dataflow_sa.email
  description = "Service account email for Dataflow jobs"
}

output "cloud_function_service_account_email" {
  value       = google_service_account.cloud_function_sa.email
  description = "Service account email for Cloud Function"
}

output "artifact_registry_repository_url" {
  value       = google_artifact_registry_repository.dataflow_repo.repository_url
  description = "Artifact Registry repository URL for Flex Templates"
}

output "bigquery_datasets" {
  value = {
    raw     = google_bigquery_dataset.cricket_raw.dataset_id
    staging = google_bigquery_dataset.cricket_staging.dataset_id
    curated = google_bigquery_dataset.cricket_curated.dataset_id
  }
  description = "BigQuery datasets"
}

output "cloud_scheduler_job_name" {
  value       = google_cloud_scheduler_job.daily_ingestion.name
  description = "Cloud Scheduler job name for daily ingestion"
}

output "eventarc_trigger_name" {
  value       = google_eventarc_trigger.gcs_to_dataflow.name
  description = "Eventarc trigger name for GCS to Dataflow"
}

output "cloud_function_url" {
  value       = google_cloudfunctions2_function.dataflow_trigger.service_config[0].uri
  description = "Cloud Function URL"
}

output "cloud_composer_environment_name" {
  value       = google_composer_environment.cricket_analytics.name
  description = "Cloud Composer environment name"
}

output "cloud_composer_airflow_uri" {
  value       = google_composer_environment.cricket_analytics.config[0].airflow_uri
  description = "Cloud Composer Airflow web UI URL"
}

output "cloud_composer_service_account" {
  value       = google_service_account.composer_sa.email
  description = "Cloud Composer service account email"
}

output "cloud_composer_dags_bucket" {
  value       = google_storage_bucket.composer_dags.name
  description = "Cloud Composer DAGs bucket"
}
