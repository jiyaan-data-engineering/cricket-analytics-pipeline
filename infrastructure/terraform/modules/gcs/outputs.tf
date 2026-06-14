# ============================================================================
# GCS MODULE - Outputs
# ============================================================================

output "raw_data_bucket_name" {
  description = "Raw data bucket name"
  value       = google_storage_bucket.raw_data.name
}

output "raw_data_bucket_url" {
  description = "Raw data bucket URL"
  value       = "gs://${google_storage_bucket.raw_data.name}"
}

output "dataflow_template_bucket_name" {
  description = "Dataflow template bucket name"
  value       = google_storage_bucket.dataflow_templates.name
}

output "dataflow_template_bucket_url" {
  description = "Dataflow template bucket URL"
  value       = "gs://${google_storage_bucket.dataflow_templates.name}"
}

output "dataflow_temp_bucket_name" {
  description = "Dataflow temporary bucket name"
  value       = google_storage_bucket.dataflow_temp.name
}

output "dataflow_temp_bucket_url" {
  description = "Dataflow temporary bucket URL"
  value       = "gs://${google_storage_bucket.dataflow_temp.name}"
}

output "tf_state_bucket_name" {
  description = "Terraform state bucket name"
  value       = google_storage_bucket.tf_state.name
}

output "tf_state_bucket_url" {
  description = "Terraform state bucket URL"
  value       = "gs://${google_storage_bucket.tf_state.name}"
}

output "buckets" {
  description = "Map of all created buckets"
  value = {
    raw_data             = google_storage_bucket.raw_data.name
    dataflow_templates   = google_storage_bucket.dataflow_templates.name
    dataflow_temp        = google_storage_bucket.dataflow_temp.name
    tf_state             = google_storage_bucket.tf_state.name
  }
}
