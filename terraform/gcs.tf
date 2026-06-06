# ============================================================================
# GCS (Google Cloud Storage) Buckets - Cricket Analytics Pipeline
# ============================================================================
#
# IMPORTANT: This file references existing configuration files.
# NO bucket names or configurations are hardcoded here - they're sourced from:
#   - config/config.yaml (bucket names, prefixes, settings)
#   - variables.tf (for override capability)
#
# Architecture:
# ├─ config.yaml is the source of truth for bucket names
# ├─ variables.tf allows Terraform overrides (terraform.tfvars)
# ├─ Terraform creates buckets with configs from above
# └─ Easy to maintain - change once in config.yaml, applies everywhere
#
# Workflow:
# 1. Update bucket names in config/config.yaml
# 2. Run terraform apply (uses config values)
# 3. Buckets created/updated with new names
#
# ============================================================================

# Load configuration from YAML file
locals {
  # Parse config.yaml to get GCS bucket names and settings
  config = yamldecode(file("${path.module}/../config/config.yaml"))

  # Extract GCS configuration
  gcs_config = local.config.gcs
  gcp_config = local.config.gcp

  # Bucket names from config (can be overridden via Terraform variables)
  raw_bucket_name       = var.gcs_raw_bucket_name != "" ? var.gcs_raw_bucket_name : local.gcs_config.raw_bucket
  templates_bucket_name = var.gcs_templates_bucket_name != "" ? var.gcs_templates_bucket_name : local.gcs_config.template_bucket
  temp_bucket_name      = var.gcs_temp_bucket_name != "" ? var.gcs_temp_bucket_name : local.gcs_config.temp_bucket
  raw_prefix            = local.gcs_config.raw_prefix
}

# ============================================================================
# RAW DATA BUCKET - Landing zone for ingested data
# ============================================================================

resource "google_storage_bucket" "raw_data" {
  name          = local.raw_bucket_name
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  description = "Raw data ingestion bucket - Source: config/config.yaml (gcs.raw_bucket)"
  labels      = var.labels

  versioning {
    enabled = false
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.required_apis["storage.googleapis.com"]]
}

# Create batting folder in raw bucket (from config)
resource "google_storage_bucket_object" "batting_folder" {
  name   = local.raw_prefix
  bucket = google_storage_bucket.raw_data.name
  content = " "
}

# ============================================================================
# DATAFLOW TEMPLATES BUCKET - Stores Flex Template images
# ============================================================================

resource "google_storage_bucket" "dataflow_templates" {
  name          = local.templates_bucket_name
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  description = "Dataflow Flex Templates storage - Source: config/config.yaml (gcs.template_bucket)"
  labels      = var.labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required_apis["storage.googleapis.com"]]
}

# Create folder structure for templates
resource "google_storage_bucket_object" "templates_folder" {
  name   = "batting-pipeline/"
  bucket = google_storage_bucket.dataflow_templates.name
  content = " "
}

# ============================================================================
# DATAFLOW TEMPORARY BUCKET - Working directory for Dataflow jobs
# ============================================================================

resource "google_storage_bucket" "dataflow_temp" {
  name          = local.temp_bucket_name
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  description = "Dataflow temporary storage - Source: config/config.yaml (gcs.temp_bucket)"
  labels      = var.labels

  versioning {
    enabled = false
  }

  depends_on = [google_project_service.required_apis["storage.googleapis.com"]]
}

# ============================================================================
# BUCKET LIFECYCLE POLICIES
# ============================================================================

# Raw data retention policy (90 days)
resource "google_storage_bucket_lifecycle_rule" "raw_data_retention" {
  bucket = google_storage_bucket.raw_data.name

  rule {
    action {
      type = "Delete"
    }
    condition {
      age = var.bq_table_expiration_days  # 90 days (from variables)
    }
  }
}

# Dataflow temp cleanup (7 days)
resource "google_storage_bucket_lifecycle_rule" "temp_cleanup" {
  bucket = google_storage_bucket.dataflow_temp.name

  rule {
    action {
      type = "Delete"
    }
    condition {
      age = 7  # Keep temp files for 7 days
    }
  }
}

# ============================================================================
# OUTPUTS - Bucket URLs and names
# ============================================================================

output "raw_bucket_name" {
  value       = google_storage_bucket.raw_data.name
  description = "Raw data bucket name (from config/config.yaml)"
}

output "raw_bucket_url" {
  value       = "gs://${google_storage_bucket.raw_data.name}"
  description = "Raw data bucket URL"
}

output "raw_bucket_prefix" {
  value       = local.raw_prefix
  description = "Raw data folder prefix (from config/config.yaml)"
}

output "templates_bucket_name" {
  value       = google_storage_bucket.dataflow_templates.name
  description = "Dataflow templates bucket name (from config/config.yaml)"
}

output "templates_bucket_url" {
  value       = "gs://${google_storage_bucket.dataflow_templates.name}"
  description = "Dataflow templates bucket URL"
}

output "temp_bucket_name" {
  value       = google_storage_bucket.dataflow_temp.name
  description = "Dataflow temp bucket name (from config/config.yaml)"
}

output "temp_bucket_url" {
  value       = "gs://${google_storage_bucket.dataflow_temp.name}"
  description = "Dataflow temp bucket URL"
}

output "gcs_summary" {
  value = {
    raw_data       = google_storage_bucket.raw_data.name
    raw_prefix     = local.raw_prefix
    templates      = google_storage_bucket.dataflow_templates.name
    temp           = google_storage_bucket.dataflow_temp.name
    config_source  = "config/config.yaml (gcs section)"
    retention_days = var.bq_table_expiration_days
  }
  description = "GCS bucket summary (all names from config/config.yaml)"
}

# ============================================================================
# LOCAL VALUES - Configuration summary
# ============================================================================

locals {
  gcs_buckets_summary = {
    source           = "config/config.yaml"
    raw_bucket       = local.raw_bucket_name
    raw_prefix       = local.raw_prefix
    templates_bucket = local.templates_bucket_name
    temp_bucket      = local.temp_bucket_name
    region           = var.gcp_region
    retention_days   = var.bq_table_expiration_days
  }
}
