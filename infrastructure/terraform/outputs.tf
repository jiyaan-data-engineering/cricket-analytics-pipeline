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
# CLOUD FUNCTION - DEPLOYED VIA GITHUB ACTIONS
# ============================================================================
# Cloud Function is now deployed via GitHub Actions workflow using gcloud
# See: .github/workflows/deploy-prod.yml for deployment details

output "cloud_function_status" {
  value       = "✅ Cloud Function: cricket-dataflow-trigger (deployed via GitHub Actions)"
  description = "Cloud Function deployment status"
}

output "cloud_function_trigger_bucket" {
  value       = google_storage_bucket.raw_data.name
  description = "GCS bucket that triggers Cloud Function"
}

output "cloud_function_next_steps" {
  value       = <<-EOT
    Cloud Function deployed via GitHub Actions workflow!

    Verify deployment:
    gcloud functions describe cricket-dataflow-trigger --region=${var.gcp_region} --project=${var.gcp_project_id}

    Test trigger by uploading CSV:
    gsutil cp sample.csv gs://${google_storage_bucket.raw_data.name}/batting/sample.csv

    Monitor execution:
    gcloud functions logs read cricket-dataflow-trigger --region=${var.gcp_region} --limit 50
  EOT
  description = "Cloud Function deployment and verification steps"
}

# ============================================================================
# CLOUD SCHEDULER - DAILY PIPELINE TRIGGER
# ============================================================================

output "cloud_scheduler_job_name" {
  value       = google_cloud_scheduler_job.cricket_analytics_trigger.name
  description = "Cloud Scheduler job name"
}

output "cloud_scheduler_schedule" {
  value       = google_cloud_scheduler_job.cricket_analytics_trigger.schedule
  description = "Cloud Scheduler cron expression (0 6 * * * = daily at 06:00 UTC)"
}

output "cloud_scheduler_next_steps" {
  value       = <<-EOT
    Cloud Scheduler Setup (PAUSED by default - enable when ready):

    1. Create Cloud Run service for ingestion:
       gcloud run deploy cricket-ingestion \
         --source pipeline/ingestion \
         --runtime python311 \
         --region ${var.gcp_region} \
         --allow-unauthenticated

    2. Update Cloud Scheduler with actual Cloud Run URL:
       gcloud scheduler jobs update http cricket-analytics-ingestion \
         --schedule "0 6 * * *" \
         --uri "https://cricket-ingestion-HASH.${var.gcp_region}.run.app/trigger" \
         --oidc-service-account-email cricket-cloud-run-sa@${var.gcp_project_id}.iam.gserviceaccount.com \
         --oidc-token-audience "https://cricket-ingestion-HASH.${var.gcp_region}.run.app"

    3. Enable the scheduler job:
       gcloud scheduler jobs resume cricket-analytics-ingestion --location ${var.gcp_region}

    4. View scheduled runs:
       gcloud scheduler jobs describe cricket-analytics-ingestion --location ${var.gcp_region}

    Daily Trigger: 06:00 UTC → Cloud Run → API Ingestion → CSV to GCS → Cloud Function → Dataflow → BigQuery
  EOT
  description = "Cloud Scheduler setup steps"
}

# ============================================================================
# LOOKER STUDIO DASHBOARD
# ============================================================================

output "looker_studio_setup_script" {
  value       = local_file.looker_studio_setup.filename
  description = "Path to Looker Studio dashboard setup script"
}

output "looker_studio_instructions" {
  value       = <<-EOT
    To create Looker Studio dashboard:

    1. Run the setup script:
       ${local_file.looker_studio_setup.filename}

    2. Or manually:
       - Go to: https://lookerstudio.google.com
       - Create new report
       - Connect to BigQuery: cricket-analytics-prod / cricket_curated
       - Add visualizations using 5 curated views

    3. Configure auto-refresh to 09:00 UTC daily

    For more details, see: DEPLOYMENT.md (Step 5)
  EOT
  description = "Instructions for creating Looker Studio dashboard"
}
