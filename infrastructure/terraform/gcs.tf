# ============================================================================
# GCS (Google Cloud Storage) Buckets - Cricket Analytics Pipeline
# ============================================================================
# All bucket names come from Terraform variables

resource "google_storage_bucket" "raw_data" {
  name          = "${var.gcs_raw_bucket_name}-${var.gcp_project_id}"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  labels                      = var.labels
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "dataflow_templates" {
  name          = "${var.gcs_templates_bucket_name}-${var.gcp_project_id}"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  labels                      = var.labels
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "dataflow_temp" {
  name          = "${var.gcs_temp_bucket_name}-${var.gcp_project_id}"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = true

  labels                      = var.labels
  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 7
    }
  }
}
