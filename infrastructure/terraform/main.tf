# ============================================================================
# CRICKET ANALYTICS PIPELINE - PRODUCTION TERRAFORM
# ============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # Configure with: terraform init -backend-config="bucket=cricket-tf-state-prod" -backend-config="prefix=terraform/state"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ============================================================================
# ENABLE REQUIRED APIs
# ============================================================================

resource "google_project_service" "required_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "storage-api.googleapis.com",
    "dataflow.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "composer.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "iam.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# ============================================================================
# CREATE SERVICE ACCOUNTS
# ============================================================================

# Already created manually - commented out to avoid conflicts
# resource "google_service_account" "dataflow" {
#   account_id   = "cricket-dataflow-sa"
#   display_name = "Cricket Analytics Dataflow Service Account"
# }

resource "google_service_account" "cloud_function" {
  account_id   = "cricket-cloud-function-sa"
  display_name = "Cricket Analytics Cloud Function Service Account"
}

resource "google_service_account" "cloud_run" {
  account_id   = "cricket-cloud-run-sa"
  display_name = "Cricket Analytics Cloud Run Service Account"
}

resource "google_service_account" "cloud_composer" {
  account_id   = "cricket-composer-sa"
  display_name = "Cricket Analytics Cloud Composer Service Account"
}

# ============================================================================
# GRANT IAM ROLES TO SERVICE ACCOUNTS
# ============================================================================

# Dataflow SA roles - commented out as dataflow SA is manually created
# resource "google_project_iam_member" "dataflow_bigquery_admin" {
#   project = var.gcp_project_id
#   role    = "roles/bigquery.admin"
#   member  = "serviceAccount:${google_service_account.dataflow.email}"
# }
#
# resource "google_project_iam_member" "dataflow_storage_admin" {
#   project = var.gcp_project_id
#   role    = "roles/storage.admin"
#   member  = "serviceAccount:${google_service_account.dataflow.email}"
# }
#
# resource "google_project_iam_member" "dataflow_admin" {
#   project = var.gcp_project_id
#   role    = "roles/dataflow.admin"
#   member  = "serviceAccount:${google_service_account.dataflow.email}"
# }
#
# resource "google_project_iam_member" "dataflow_worker" {
#   project = var.gcp_project_id
#   role    = "roles/dataflow.worker"
#   member  = "serviceAccount:${google_service_account.dataflow.email}"
# }

# Cloud Function SA roles
# IAM roles set manually - commented out to avoid service account permission issues
# resource "google_project_iam_member" "cf_dataflow_admin" {
#   project = var.gcp_project_id
#   role    = "roles/dataflow.admin"
#   member  = "serviceAccount:${google_service_account.cloud_function.email}"
# }
#
# resource "google_project_iam_member" "cf_service_account_user" {
#   project = var.gcp_project_id
#   role    = "roles/iam.serviceAccountUser"
#   member  = "serviceAccount:${google_service_account.cloud_function.email}"
# }
#
# # Cloud Composer SA roles
# resource "google_project_iam_member" "composer_bigquery_admin" {
#   project = var.gcp_project_id
#   role    = "roles/bigquery.admin"
#   member  = "serviceAccount:${google_service_account.cloud_composer.email}"
# }
#
# resource "google_project_iam_member" "composer_storage_admin" {
#   project = var.gcp_project_id
#   role    = "roles/storage.admin"
#   member  = "serviceAccount:${google_service_account.cloud_composer.email}"
# }
#
# resource "google_project_iam_member" "composer_dataflow_admin" {
#   project = var.gcp_project_id
#   role    = "roles/dataflow.admin"
#   member  = "serviceAccount:${google_service_account.cloud_composer.email}"
# }

# ============================================================================
# CREATE GCS BUCKETS
# ============================================================================

resource "google_storage_bucket" "raw_data" {
  name          = "cricket-raw-data-prod"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket" "templates" {
  name          = "cricket-dataflow-templates-prod"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket" "temp" {
  name          = "cricket-dataflow-temp-prod"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

# Already created manually - commented out to avoid conflicts
# resource "google_storage_bucket" "tf_state" {
#   name          = "cricket-tf-state-prod"
#   location      = var.gcp_region
#   project       = var.gcp_project_id
#   force_destroy = false
#
#   uniform_bucket_level_access = true
#
#   versioning {
#     enabled = true
#   }
# }

# ============================================================================
# CREATE BIGQUERY DATASETS
# ============================================================================

resource "google_bigquery_dataset" "raw" {
  dataset_id    = "cricket_raw"
  friendly_name = "Cricket Raw Data"
  description   = "Raw data ingestion layer"
  location      = var.gcp_region
  project       = var.gcp_project_id
}

resource "google_bigquery_dataset" "staging" {
  dataset_id    = "cricket_staging"
  friendly_name = "Cricket Staging"
  description   = "Staging/transformed data layer"
  location      = var.gcp_region
  project       = var.gcp_project_id
}

resource "google_bigquery_dataset" "curated" {
  dataset_id    = "cricket_curated"
  friendly_name = "Cricket Curated"
  description   = "Curated/analytics-ready data"
  location      = var.gcp_region
  project       = var.gcp_project_id
}

resource "google_bigquery_dataset" "audit_logs" {
  dataset_id    = "cricket_audit_logs"
  friendly_name = "Cricket Audit Logs"
  description   = "Pipeline audit and monitoring logs"
  location      = var.gcp_region
  project       = var.gcp_project_id
}

# ============================================================================
# EVENT-DRIVEN & ORCHESTRATION RESOURCES (DEPLOYED MANUALLY)
# ============================================================================
# Note: Cloud Function, Eventarc, Cloud Run, Cloud Scheduler, and Cloud Composer
# require complex nested structures and will be deployed manually via
# gcloud commands or the provided deployment scripts after Terraform
# core infrastructure is in place. The Python code is ready in:
# - pipeline/cloud_function/main.py (Dataflow trigger)
# - pipeline/ingestion/fetch_batting_rankings.py (API ingestion)
# - pipeline/dataflow/pipeline.py (Apache Beam processing)
# - pipeline/airflow/dags/*.py (Airflow DAGs for Cloud Composer)
#
# Use scripts/deploy-composer.sh to deploy Cloud Composer environment
