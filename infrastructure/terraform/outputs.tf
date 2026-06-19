# ============================================================================
# TERRAFORM OUTPUTS - GCS BUCKETS ONLY
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
# GCS BUCKETS (ACTIVE)
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

# ============================================================================
# BIGQUERY DATASETS (ACTIVE)
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
# SERVICE ACCOUNTS (COMMENTED - ENABLE WHEN NEEDED)
# ============================================================================
# TODO: Uncomment when Cloud Composer service account is enabled in main.tf

# output "cloud_composer_service_account" {
#   value       = google_service_account.cloud_composer.email
#   description = "Cloud Composer service account email"
# }

# ============================================================================
# LOOKER STUDIO (COMMENTED - ENABLE IN PHASE 4)
# ============================================================================
# TODO: Uncomment when Looker Studio resource is enabled in main.tf

# output "looker_studio_setup_script" {
#   value       = local_file.looker_studio_setup.filename
#   description = "Path to Looker Studio dashboard setup script"
# }
#
# output "looker_studio_instructions" {
#   value       = <<-EOT
#     To create Looker Studio dashboard:
#
#     1. Run the setup script:
#        ${local_file.looker_studio_setup.filename}
#
#     2. Or manually:
#        - Go to: https://lookerstudio.google.com
#        - Create new report
#        - Connect to BigQuery: cricket-analytics-prod / cricket_curated
#        - Add visualizations using 5 curated views
#
#     3. Configure auto-refresh to 09:00 UTC daily
#
#     For more details, see: DEPLOYMENT.md (Step 5)
#   EOT
#   description = "Instructions for creating Looker Studio dashboard"
# }
