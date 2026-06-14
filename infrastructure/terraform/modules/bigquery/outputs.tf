# ============================================================================
# BIGQUERY MODULE - Outputs
# ============================================================================

output "raw_dataset_id" {
  description = "Raw dataset ID"
  value       = google_bigquery_dataset.raw.dataset_id
}

output "raw_dataset_project" {
  description = "Raw dataset project"
  value       = google_bigquery_dataset.raw.project
}

output "staging_dataset_id" {
  description = "Staging dataset ID"
  value       = google_bigquery_dataset.staging.dataset_id
}

output "curated_dataset_id" {
  description = "Curated dataset ID"
  value       = google_bigquery_dataset.curated.dataset_id
}

output "audit_dataset_id" {
  description = "Audit logs dataset ID"
  value       = google_bigquery_dataset.audit_logs.dataset_id
}

output "raw_batting_table_id" {
  description = "Raw batting rankings table ID"
  value       = google_bigquery_table.raw_batting_rankings.table_id
}

output "audit_logs_table_id" {
  description = "Audit logs table ID"
  value       = google_bigquery_table.audit_logs_summary.table_id
}

output "datasets" {
  description = "Map of all created datasets"
  value = {
    raw     = google_bigquery_dataset.raw.dataset_id
    staging = google_bigquery_dataset.staging.dataset_id
    curated = google_bigquery_dataset.curated.dataset_id
    audit   = google_bigquery_dataset.audit_logs.dataset_id
  }
}
