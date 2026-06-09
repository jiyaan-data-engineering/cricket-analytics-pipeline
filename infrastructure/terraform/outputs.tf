# ============================================================================
# Terraform Outputs - Cricket Analytics Pipeline
# All important resource information
# ============================================================================

output "gcp_project_id" {
  value       = var.gcp_project_id
  description = "GCP Project ID"
}

# ============================================================================
# GCS BUCKET OUTPUTS
# ============================================================================

output "gcs_raw_bucket_name" {
  value       = google_storage_bucket.raw_data.name
  description = "GCS bucket name for raw data ingestion"
}

output "gcs_raw_bucket_url" {
  value       = "gs://${google_storage_bucket.raw_data.name}"
  description = "GCS bucket URL for raw data"
}

output "gcs_templates_bucket_name" {
  value       = google_storage_bucket.dataflow_templates.name
  description = "GCS bucket name for Dataflow Flex Templates"
}

output "gcs_templates_bucket_url" {
  value       = "gs://${google_storage_bucket.dataflow_templates.name}"
  description = "GCS bucket URL for Dataflow templates"
}

output "gcs_temp_bucket_name" {
  value       = google_storage_bucket.dataflow_temp.name
  description = "GCS bucket name for Dataflow temporary data"
}

output "gcs_temp_bucket_url" {
  value       = "gs://${google_storage_bucket.dataflow_temp.name}"
  description = "GCS bucket URL for Dataflow temp files"
}

# ============================================================================
# BIGQUERY OUTPUTS
# ============================================================================

output "bigquery_raw_dataset" {
  value       = google_bigquery_dataset.raw.dataset_id
  description = "BigQuery raw data dataset"
}

output "bigquery_staging_dataset" {
  value       = google_bigquery_dataset.staging.dataset_id
  description = "BigQuery staging dataset"
}

output "bigquery_curated_dataset" {
  value       = google_bigquery_dataset.curated.dataset_id
  description = "BigQuery curated dataset"
}

output "bigquery_raw_table" {
  value       = "${google_bigquery_dataset.raw.dataset_id}.${google_bigquery_table.raw_batting_rankings.table_id}"
  description = "Full path to raw batting rankings table"
}

output "bigquery_datasets_summary" {
  value = {
    raw     = google_bigquery_dataset.raw.dataset_id
    staging = google_bigquery_dataset.staging.dataset_id
    curated = google_bigquery_dataset.curated.dataset_id
  }
  description = "All BigQuery datasets created"
}

# ============================================================================
# SERVICE ACCOUNT OUTPUTS
# ============================================================================

output "dataflow_service_account_email" {
  value       = google_service_account.dataflow_sa.email
  description = "Dataflow service account email"
}

output "cloud_function_service_account_email" {
  value       = google_service_account.cloud_function_sa.email
  description = "Cloud Function service account email"
}

output "cloud_composer_service_account_email" {
  value       = google_service_account.composer_sa.email
  description = "Cloud Composer service account email"
}

# ============================================================================
# CLOUD FUNCTION OUTPUTS
# ============================================================================

output "cloud_function_name" {
  value       = google_cloudfunctions2_function.gcs_dataflow_trigger.name
  description = "Cloud Function name"
}

output "cloud_function_location" {
  value       = google_cloudfunctions2_function.gcs_dataflow_trigger.location
  description = "Cloud Function location"
}

# ============================================================================
# CLOUD SCHEDULER OUTPUTS
# ============================================================================

output "cloud_scheduler_job_name" {
  value       = google_cloud_scheduler_job.daily_ingestion.name
  description = "Cloud Scheduler job name"
}

output "cloud_scheduler_schedule" {
  value       = var.cloud_scheduler_schedule
  description = "Cloud Scheduler cron schedule"
}

# ============================================================================
# CLOUD COMPOSER OUTPUTS
# ============================================================================

output "cloud_composer_name" {
  value       = var.enable_cloud_composer ? google_composer_environment.cricket_composer[0].name : "Cloud Composer disabled"
  description = "Cloud Composer environment name"
}

output "cloud_composer_dag_bucket" {
  value       = var.enable_cloud_composer ? google_composer_environment.cricket_composer[0].config[0].dag_gcs_prefix : "Cloud Composer disabled"
  description = "Cloud Composer DAGs bucket path"
}

# ============================================================================
# ARTIFACT REGISTRY OUTPUTS
# ============================================================================

output "artifact_registry_name" {
  value       = google_artifact_registry_repository.docker_repo.repository_id
  description = "Artifact Registry repository name"
}

output "artifact_registry_url" {
  value       = google_artifact_registry_repository.docker_repo.repository
  description = "Artifact Registry repository URL"
}

# ============================================================================
# QUICK REFERENCE OUTPUTS
# ============================================================================

output "deployment_summary" {
  value = {
    project_id            = var.gcp_project_id
    region                = var.gcp_region
    raw_bucket            = google_storage_bucket.raw_data.name
    raw_dataset           = google_bigquery_dataset.raw.dataset_id
    staging_dataset       = google_bigquery_dataset.staging.dataset_id
    curated_dataset       = google_bigquery_dataset.curated.dataset_id
    cloud_function_name   = google_cloudfunctions2_function.gcs_dataflow_trigger.name
    cloud_scheduler_job   = google_cloud_scheduler_job.daily_ingestion.name
    cloud_composer_status = var.enable_cloud_composer ? "Enabled" : "Disabled"
    dataflow_sa           = google_service_account.dataflow_sa.email
    function_sa           = google_service_account.cloud_function_sa.email
    composer_sa           = google_service_account.composer_sa.email
  }
  description = "Summary of all deployed resources"
}

output "next_steps" {
  value = [
    "1. Deploy Cloud Function source code",
    "2. Build and push Dataflow Flex Template to Artifact Registry",
    "3. Upload DAGs to Cloud Composer",
    "4. Create BigQuery tables using SQL scripts",
    "5. Test end-to-end pipeline",
    "6. Create Looker Studio dashboard"
  ]
  description = "Next steps after Terraform deployment"
}
