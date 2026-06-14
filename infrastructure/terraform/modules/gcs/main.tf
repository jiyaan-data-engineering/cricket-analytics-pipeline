# ============================================================================
# GCS MODULE - Creates Cloud Storage buckets
# ============================================================================

# Raw Data Bucket
resource "google_storage_bucket" "raw_data" {
  name            = var.raw_data_bucket_name
  location        = var.location
  storage_class   = var.storage_class
  project         = var.project_id
  force_destroy   = var.force_destroy

  uniform_bucket_level_access = true

  labels = var.labels

  versioning {
    enabled = var.versioning_enabled
  }

  lifecycle_rule {
    condition {
      age = 365  # Delete objects older than 1 year
    }
    action {
      type = "Delete"
    }
  }
}

# Dataflow Template Bucket
resource "google_storage_bucket" "dataflow_templates" {
  name            = var.dataflow_template_bucket_name
  location        = var.location
  storage_class   = var.storage_class
  project         = var.project_id
  force_destroy   = var.force_destroy

  uniform_bucket_level_access = true

  labels = var.labels

  versioning {
    enabled = true  # Always version template bucket
  }
}

# Dataflow Temporary Bucket
resource "google_storage_bucket" "dataflow_temp" {
  name            = var.dataflow_temp_bucket_name
  location        = var.location
  storage_class   = var.storage_class
  project         = var.project_id
  force_destroy   = var.force_destroy

  uniform_bucket_level_access = true

  labels = var.labels

  lifecycle_rule {
    condition {
      age = 30  # Delete temp files after 30 days
    }
    action {
      type = "Delete"
    }
  }
}

# Terraform State Bucket
resource "google_storage_bucket" "tf_state" {
  name            = var.tf_state_bucket_name
  location        = var.location
  storage_class   = var.storage_class
  project         = var.project_id
  force_destroy   = false  # Never auto-destroy state

  uniform_bucket_level_access = true

  labels = merge(
    var.labels,
    {
      "terraform" = "state"
    }
  )

  versioning {
    enabled = true  # Always version state bucket
  }

  # Enable logging for state bucket
  logging {
    log_bucket = google_storage_bucket.tf_state_logs.name
  }
}

# Terraform State Logs Bucket
resource "google_storage_bucket" "tf_state_logs" {
  name            = "${var.tf_state_bucket_name}-logs"
  location        = var.location
  storage_class   = var.storage_class
  project         = var.project_id
  force_destroy   = var.force_destroy

  uniform_bucket_level_access = true

  labels = var.labels

  lifecycle_rule {
    condition {
      age = 90  # Delete logs after 90 days
    }
    action {
      type = "Delete"
    }
  }
}

# Add public access prevention
resource "google_storage_bucket_public_access_prevention" "raw_data" {
  bucket = google_storage_bucket.raw_data.id
  enabled = true
}

resource "google_storage_bucket_public_access_prevention" "templates" {
  bucket = google_storage_bucket.dataflow_templates.id
  enabled = true
}

resource "google_storage_bucket_public_access_prevention" "temp" {
  bucket = google_storage_bucket.dataflow_temp.id
  enabled = true
}

resource "google_storage_bucket_public_access_prevention" "state" {
  bucket = google_storage_bucket.tf_state.id
  enabled = true
}
