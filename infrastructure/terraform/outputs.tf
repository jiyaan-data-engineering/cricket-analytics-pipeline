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
# CLOUD FUNCTION - EVENT-DRIVEN DATAFLOW TRIGGER
# ============================================================================

output "cloud_function_trigger_bucket" {
  value       = google_storage_bucket.raw_data.name
  description = "GCS bucket for triggering Cloud Function on CSV upload"
}

output "cloud_function_deployment_instructions" {
  value       = <<EOT
To deploy Cloud Function (event-driven trigger):

1. Deploy the function:
   gcloud functions deploy cricket-dataflow-trigger \
     --runtime python311 \
     --region us-central1 \
     --trigger-bucket ${google_storage_bucket.raw_data.name} \
     --entry-point process_batting_file \
     --source ./pipeline/cloud_function \
     --service-account cricket-cloud-function-sa@${var.gcp_project_id}.iam.gserviceaccount.com \
     --project ${var.gcp_project_id}

2. Grant IAM roles to service account:
   gcloud projects add-iam-policy-binding ${var.gcp_project_id} \
     --member=serviceAccount:cricket-cloud-function-sa@${var.gcp_project_id}.iam.gserviceaccount.com \
     --role=roles/dataflow.admin

   gcloud projects add-iam-policy-binding ${var.gcp_project_id} \
     --member=serviceAccount:cricket-cloud-function-sa@${var.gcp_project_id}.iam.gserviceaccount.com \
     --role=roles/iam.serviceAccountUser

   gcloud projects add-iam-policy-binding ${var.gcp_project_id} \
     --member=serviceAccount:cricket-cloud-function-sa@${var.gcp_project_id}.iam.gserviceaccount.com \
     --role=roles/storage.objectViewer

After deployment, CSV uploads to ${google_storage_bucket.raw_data.name} will trigger Dataflow automatically.
EOT
  description = "Cloud Function deployment instructions"
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
