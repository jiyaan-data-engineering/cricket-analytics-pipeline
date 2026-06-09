# ============================================================================
# BigQuery - Simplified (Only Datasets)
# ============================================================================
# Tables and Views are created via SQL scripts in pipeline/bigquery/sql/
# This avoids file loading issues and keeps Terraform simple

resource "google_bigquery_dataset" "raw" {
  dataset_id    = var.bq_raw_dataset
  friendly_name = "Cricket Raw Layer"
  description   = "Raw ICC Men's Batting Rankings from Cricbuzz API"
  location      = var.gcp_region
  labels        = var.labels
}

resource "google_bigquery_dataset" "staging" {
  dataset_id    = var.bq_staging_dataset
  friendly_name = "Cricket Staging Layer"
  description   = "Staging layer with dimensions and facts (star schema)"
  location      = var.gcp_region
  labels        = var.labels
}

resource "google_bigquery_dataset" "curated" {
  dataset_id    = var.bq_curated_dataset
  friendly_name = "Cricket Curated Layer"
  description   = "Analytics-ready curated views"
  location      = var.gcp_region
  labels        = var.labels
}
