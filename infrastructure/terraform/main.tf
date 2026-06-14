# ============================================================================
# MULTI-ENVIRONMENT MAIN CONFIGURATION
# Uses modules and environment-specific variables
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend configured per environment
  # Use: terraform init -backend-config="bucket=cricket-tf-state" \
  #                      -backend-config="prefix=dev"
  backend "gcs" {
    # Bucket is specified via -backend-config flag during init
    # Each environment has its own state file in different prefix
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# ============================================================================
# BIGQUERY MODULE
# ============================================================================

module "bigquery" {
  source = "./modules/bigquery"

  project_id               = var.gcp_project_id
  environment              = var.environment
  location                 = var.bq_location

  raw_dataset_id           = local.raw_dataset
  staging_dataset_id       = local.staging_dataset
  curated_dataset_id       = local.curated_dataset
  audit_dataset_id         = local.audit_dataset

  service_account_email    = google_service_account.dataflow.email
  table_expiration_ms      = var.bq_dataset_expiration_days != null ? var.bq_dataset_expiration_days * 86400000 : null
  raw_partition_expiration_ms = var.raw_table_partition_expiration_days * 86400000

  labels                   = local.resource_labels
}

# ============================================================================
# GCS MODULE
# ============================================================================

module "gcs" {
  source = "./modules/gcs"

  project_id                      = var.gcp_project_id
  location                        = var.gcs_location
  storage_class                   = var.gcs_storage_class
  versioning_enabled              = var.gcs_versioning_enabled
  force_destroy                   = local.is_dev  # Only allow destroy in dev

  raw_data_bucket_name            = local.raw_data_bucket
  dataflow_template_bucket_name   = local.dataflow_template_bucket
  dataflow_temp_bucket_name       = local.dataflow_temp_bucket
  tf_state_bucket_name            = local.tf_state_bucket

  labels                          = local.resource_labels
}

# ============================================================================
# SERVICE ACCOUNTS
# ============================================================================

resource "google_service_account" "dataflow" {
  account_id   = var.dataflow_service_account_name
  display_name = "Cricket Analytics Dataflow SA (${var.environment})"
  description  = "Service account for Dataflow pipelines in ${var.environment}"
}

resource "google_service_account" "cloud_function" {
  account_id   = var.cloud_function_service_account_name
  display_name = "Cricket Analytics Cloud Function SA (${var.environment})"
  description  = "Service account for Cloud Functions in ${var.environment}"
}

resource "google_service_account" "cloud_run" {
  account_id   = var.cloud_run_service_account_name
  display_name = "Cricket Analytics Cloud Run SA (${var.environment})"
  description  = "Service account for Cloud Run in ${var.environment}"
}

resource "google_service_account" "cloud_composer" {
  account_id   = var.cloud_composer_service_account_name
  display_name = "Cricket Analytics Cloud Composer SA (${var.environment})"
  description  = "Service account for Cloud Composer in ${var.environment}"
}

# ============================================================================
# IAM ROLES - Dataflow Service Account
# ============================================================================

resource "google_project_iam_member" "dataflow_bigquery_admin" {
  project = var.gcp_project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_dataflow_admin" {
  project = var.gcp_project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "dataflow_compute_worker" {
  project = var.gcp_project_id
  role    = "roles/compute.instanceServiceAccount"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

# ============================================================================
# IAM ROLES - Cloud Function Service Account
# ============================================================================

resource "google_project_iam_member" "cloud_function_dataflow_admin" {
  project = var.gcp_project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.cloud_function.email}"
}

resource "google_project_iam_member" "cloud_function_iam_serviceaccountuser" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_function.email}"
}

# ============================================================================
# IAM ROLES - Cloud Composer Service Account
# ============================================================================

resource "google_project_iam_member" "cloud_composer_bigquery_admin" {
  project = var.gcp_project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.cloud_composer.email}"
}

resource "google_project_iam_member" "cloud_composer_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_composer.email}"
}

resource "google_project_iam_member" "cloud_composer_dataflow_admin" {
  project = var.gcp_project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.cloud_composer.email}"
}

# ============================================================================
# ENABLE REQUIRED GCP APIs
# ============================================================================

resource "google_project_service" "required_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "storage-api.googleapis.com",
    "dataflow.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudrun.googleapis.com",
    "composer.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project = var.gcp_project_id
  service = each.value

  disable_on_destroy = false
}

# ============================================================================
# OPTIONAL: CLOUD SCHEDULER (for daily ingestion)
# ============================================================================

resource "google_cloud_scheduler_job" "cricket_daily_ingestion" {
  count           = var.cloud_scheduler_enabled ? 1 : 0
  name            = "${var.environment_short}-cricket-daily-ingestion"
  description     = "Daily cricket data ingestion job (${var.environment})"
  schedule        = var.cloud_scheduler_schedule
  time_zone       = var.cloud_scheduler_timezone
  region          = var.gcp_region
  project         = var.gcp_project_id

  http_target {
    http_method = "GET"
    uri         = "https://example.com/ingest"  # Update with actual Cloud Run URL

    oidc_token {
      service_account_email = google_service_account.cloud_run.email
    }
  }

  depends_on = [google_project_service.required_apis["cloudscheduler.googleapis.com"]]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "bigquery_datasets" {
  description = "Created BigQuery datasets"
  value       = module.bigquery.datasets
}

output "gcs_buckets" {
  description = "Created GCS buckets"
  value       = module.gcs.buckets
}

output "service_accounts" {
  description = "Created service accounts"
  value = {
    dataflow        = google_service_account.dataflow.email
    cloud_function  = google_service_account.cloud_function.email
    cloud_run       = google_service_account.cloud_run.email
    cloud_composer  = google_service_account.cloud_composer.email
  }
}

output "environment_summary" {
  description = "Environment summary"
  value = {
    environment     = var.environment
    project_id      = var.gcp_project_id
    region          = var.gcp_region
    is_production   = local.is_prod
    monitoring      = var.monitoring_enabled
    backup_enabled  = var.backup_enabled
  }
}
