# ============================================================================
# Terraform Configuration - Cricket Analytics Pipeline
# Creates complete GCP infrastructure
# All resource names from variables.tf
# ============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ============================================================================
# ENABLE REQUIRED GCP APIS
# ============================================================================

resource "google_project_service" "required_apis" {
  for_each = toset([
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "dataflow.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
    "composer.googleapis.com",
    "iam.googleapis.com",
    "cloudkms.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# ============================================================================
# CREATE SERVICE ACCOUNTS
# ============================================================================

# Dataflow Service Account
resource "google_service_account" "dataflow_sa" {
  account_id   = var.dataflow_sa_name
  display_name = "Cricket Analytics Dataflow Service Account"

  depends_on = [google_project_service.required_apis["iam.googleapis.com"]]
}

# Cloud Function Service Account
resource "google_service_account" "cloud_function_sa" {
  account_id   = var.cloud_function_sa_name
  display_name = "Cricket Analytics Cloud Function Service Account"

  depends_on = [google_project_service.required_apis["iam.googleapis.com"]]
}

# ============================================================================
# GRANT IAM ROLES TO SERVICE ACCOUNTS
# ============================================================================
# Dataflow SA - BigQuery Admin
resource "google_project_iam_member" "dataflow_bq_admin" {
  project = var.gcp_project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Dataflow SA - Storage Admin
resource "google_project_iam_member" "dataflow_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Dataflow SA - Dataflow Worker
resource "google_project_iam_member" "dataflow_worker" {
  project = var.gcp_project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Cloud Function SA - Dataflow Admin
resource "google_project_iam_member" "function_dataflow_admin" {
  project = var.gcp_project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

# Cloud Function SA - Storage Object Viewer
resource "google_project_iam_member" "function_storage_viewer" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}



# ============================================================================
# GCS BUCKETS
# NOTE: GCS bucket definitions have been moved to gcs.tf
# All bucket names and configurations are now sourced from:
#   - config/config.yaml (source of truth)
#   - variables.tf (terraform overrides via terraform.tfvars)
# ============================================================================
# See gcs.tf for all GCS bucket resources
# They reference config/config.yaml for bucket names and settings

# ============================================================================
# CREATE BIGQUERY DATASETS
# ============================================================================

# ============================================================================
# CREATE ARTIFACT REGISTRY
# (BigQuery datasets are defined in bigquery.tf)
# ============================================================================

resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.gcp_region
  repository_id = var.artifact_registry_name
  description   = "Docker repository for Cricket Analytics Dataflow templates"
  format        = var.artifact_registry_format

  labels = var.labels

  depends_on = [google_project_service.required_apis["artifactregistry.googleapis.com"]]
}

# ============================================================================
# CREATE CLOUD FUNCTION (GCS Trigger)
# ============================================================================

# Create Cloud Function source code bucket (temporary)
resource "google_storage_bucket" "cloud_function_source" {
  name          = "${var.gcp_project_id}-cloud-function-source"
  location      = var.gcp_region
  force_destroy = true

  labels = var.labels

  depends_on = [google_project_service.required_apis["storage.googleapis.com"]]
}

# Upload placeholder Cloud Function source

# Cloud Function 2nd Gen
resource "google_cloudfunctions2_function" "gcs_dataflow_trigger" {
  name        = var.cloud_function_name
  location    = var.gcp_region
  description = "Trigger Dataflow job when CSV is uploaded to GCS"

  labels = var.labels

  build_config {
    runtime           = var.cloud_function_runtime
    entry_point       = "process_batting_file"
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_function_source.name
        object = "placeholder.zip"
      }
    }
  }

  service_config {
    max_instance_count    = var.cloud_function_max_instances
    timeout_seconds       = var.cloud_function_timeout
    service_account_email = google_service_account.cloud_function_sa.email

    environment_variables = {
      GCP_PROJECT                = var.gcp_project_id
      GCP_REGION                 = var.gcp_region
      DATAFLOW_TEMPLATE_LOCATION = var.dataflow_template_location
      BQ_DATASET                 = var.bq_raw_dataset
      BQ_TABLE                   = var.bq_raw_table_name
      TEMP_BUCKET                = google_storage_bucket.dataflow_temp.name  # From gcs.tf
    }
  }

  event_trigger {
    event_type           = "google.cloud.storage.object.v1.finalized"
    service_account_email = google_service_account.cloud_function_sa.email

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.raw_data.name  # From gcs.tf
    }

    event_filters {
      attribute = "name"
      value     = "${var.gcs_raw_prefix}.*\\.csv$"
    }
  }

  depends_on = [
    google_project_service.required_apis["cloudfunctions.googleapis.com"]
  ]
}

# ============================================================================
# CREATE CLOUD SCHEDULER JOB
# ============================================================================

resource "google_cloud_scheduler_job" "daily_ingestion" {
  name            = var.cloud_scheduler_job_name
  description     = var.cloud_scheduler_description
  schedule         = var.cloud_scheduler_schedule
  time_zone        = var.cloud_scheduler_timezone
  region           = var.gcp_region
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = "https://${var.gcp_region}-${var.gcp_project_id}.cloudfunctions.net/${var.cloud_function_name}"

    oidc_token {
      service_account_email = google_service_account.cloud_function_sa.email
    }
  }

  depends_on = [
    google_project_service.required_apis["cloudscheduler.googleapis.com"],
    google_cloudfunctions2_function.gcs_dataflow_trigger
  ]
}

# ============================================================================
# CREATE CLOUD COMPOSER (AIRFLOW)
# ============================================================================

resource "google_composer_environment" "cricket_composer" {
  count = var.enable_cloud_composer ? 1 : 0

  name        = var.cloud_composer_name
  region      = var.gcp_region
  labels      = var.labels

  config {
    software_config {
      airflow_config_overrides = {
        "core-load_examples" = "False"
      }

      pypi_packages = {
        "apache-airflow-providers-google"       = ">=10.0.0"
        "apache-airflow-providers-apache-beam"  = ">=5.0.0"
        "google-cloud-storage"                  = ">=2.10.0"
        "google-cloud-bigquery"                 = ">=3.10.0"
        "pandas"                                = ">=2.0.0"
        "pyyaml"                                = ">=6.0"
        "requests"                              = ">=2.31.0"
      }

      env_variables = {
        GCP_PROJECT_ID  = var.gcp_project_id
        GCP_REGION      = var.gcp_region
        RAW_DATASET     = var.bq_raw_dataset
        STAGING_DATASET = var.bq_staging_dataset
        CURATED_DATASET = var.bq_curated_dataset
        RAW_BUCKET      = google_storage_bucket.raw_data.name  # From gcs.tf
      }
    }

    node_config {
      zone         = var.gcp_zone
      machine_type = var.cloud_composer_machine_type
      disk_size_gb = var.cloud_composer_disk_size
    }

    node_count = var.cloud_composer_node_count
  }

  depends_on = [google_project_service.required_apis["composer.googleapis.com"]]
}

# ============================================================================
# OPTIONAL: MONITORING & ALERTS
# ============================================================================

resource "google_monitoring_alert_policy" "dag_failure" {
  count = var.enable_monitoring ? 1 : 0

  display_name = var.alert_policy_name
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "DAG Task Failure"

    condition_threshold {
      filter          = "resource.type=\"cloud_composer_environment\" AND metric.type=\"composer.googleapis.com/dag_run/failed\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
    }
  }

  depends_on = [google_project_service.required_apis["monitoring.googleapis.com"]]
}

# ============================================================================
# LOCAL VALUES FOR EASY REFERENCE
# ============================================================================

locals {
  dataflow_sa_email     = google_service_account.dataflow_sa.email
  function_sa_email     = google_service_account.cloud_function_sa.email
  composer_sa_email     = google_service_account.composer_sa.email
}
