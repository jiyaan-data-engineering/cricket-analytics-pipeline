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

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "dataflow.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudrun.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Create service account for Dataflow jobs
resource "google_service_account" "dataflow_sa" {
  account_id   = "cricket-dataflow-sa"
  display_name = "Service Account for Cricket Dataflow Jobs"
}

# Grant BigQuery Admin role
resource "google_project_iam_member" "dataflow_bq_admin" {
  project = var.gcp_project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Grant Storage Admin role
resource "google_project_iam_member" "dataflow_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Grant Dataflow Worker role
resource "google_project_iam_member" "dataflow_worker" {
  project = var.gcp_project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# ============================================
# GCS BUCKETS
# ============================================

resource "google_storage_bucket" "raw_data" {
  name          = "${var.bucket_prefix}-raw-data-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = false

  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }

  labels = {
    environment = var.environment
    purpose     = "raw-data-landing"
  }
}

resource "google_storage_bucket_folder" "batting_folder" {
  bucket = google_storage_bucket.raw_data.name
  name   = "batting/"
}

resource "google_storage_bucket" "dataflow_templates" {
  name          = "${var.bucket_prefix}-dataflow-templates-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = false

  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    purpose     = "dataflow-templates"
  }
}

resource "google_storage_bucket" "dataflow_temp" {
  name          = "${var.bucket_prefix}-dataflow-temp-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle {
    ignore_changes = [versioning]
  }

  labels = {
    environment = var.environment
    purpose     = "dataflow-staging"
  }
}

# ============================================
# BigQuery DATASETS
# ============================================

resource "google_bigquery_dataset" "cricket_raw" {
  dataset_id    = "cricket_raw"
  friendly_name = "Cricket Raw Layer"
  description   = "Raw batting rankings data from Cricbuzz API"
  location      = var.gcp_region

  default_table_expiration_ms = 7776000000  # 90 days

  labels = {
    environment = var.environment
    layer       = "raw"
  }
}

resource "google_bigquery_dataset" "cricket_staging" {
  dataset_id    = "cricket_staging"
  friendly_name = "Cricket Staging Layer"
  description   = "Cleaned and transformed data with star schema"
  location      = var.gcp_region

  labels = {
    environment = var.environment
    layer       = "staging"
  }
}

resource "google_bigquery_dataset" "cricket_curated" {
  dataset_id    = "cricket_curated"
  friendly_name = "Cricket Curated Layer"
  description   = "Analytics-ready views for dashboards"
  location      = var.gcp_region

  labels = {
    environment = var.environment
    layer       = "curated"
  }
}

# ============================================
# ARTIFACT REGISTRY (for Flex Templates)
# ============================================

resource "google_artifact_registry_repository" "dataflow_repo" {
  location      = var.gcp_region
  repository_id = "cricket-dataflow-templates"
  description   = "Docker repository for Cricket Dataflow Flex Templates"
  format        = "DOCKER"

  docker_config {
    immutable_tags = false
  }
}

# ============================================
# Cloud Run (for scheduled ingestion)
# ============================================

resource "google_cloud_run_service" "ingestion_service" {
  name     = "cricket-ingestion-service"
  location = var.gcp_region

  template {
    spec {
      service_account_name = google_service_account.dataflow_sa.email

      containers {
        image = "gcr.io/cloud-builders/docker"
        env {
          name  = "RAPIDAPI_KEY"
          value = var.rapidapi_key
        }
        env {
          name  = "GCP_PROJECT"
          value = var.gcp_project_id
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# ============================================
# Cloud Scheduler (daily ingestion trigger)
# ============================================

resource "google_cloud_scheduler_job" "daily_ingestion" {
  name             = "cricket-daily-ingestion"
  description      = "Trigger daily cricket batting rankings ingestion"
  schedule         = "0 6 * * *"  # 06:00 UTC daily
  time_zone        = "UTC"
  attempt_deadline = "600s"
  region           = var.gcp_region

  retry_config {
    retry_count = 2
  }

  http_target {
    http_method = "POST"
    uri         = google_cloud_run_service.ingestion_service.status[0].url

    headers = {
      "Content-Type" = "application/json"
    }
  }
}

# ============================================
# EVENTARC TRIGGER (GCS → Cloud Function)
# ============================================

resource "google_service_account" "cloud_function_sa" {
  account_id   = "cricket-cloud-function-sa"
  display_name = "Service Account for Cricket Cloud Function"
}

resource "google_project_iam_member" "cf_dataflow_admin" {
  project = var.gcp_project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

resource "google_project_iam_member" "cf_storage_reader" {
  project = var.gcp_project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}

resource "google_eventarc_trigger" "gcs_to_dataflow" {
  name            = "cricket-gcs-to-dataflow"
  location        = var.gcp_region
  service_account = google_service_account.cloud_function_sa.email

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.raw_data.name
  }

  destination {
    cloud_function = google_cloudfunctions2_function.dataflow_trigger.id
  }
}

# ============================================
# Cloud Function 2nd Gen
# ============================================

resource "google_cloudfunctions2_function" "dataflow_trigger" {
  name            = "cricket-gcs-dataflow-trigger"
  location        = var.gcp_region
  description     = "Triggered by GCS finalization, launches Dataflow job"
  build_config {
    runtime     = "python311"
    entry_point = "process_batting_file"

    source {
      storage_source {
        bucket = google_storage_bucket.dataflow_templates.name
        object = "cloud-function-source.zip"
      }
    }
  }

  service_config {
    max_instance_count = 10
    timeout_seconds    = 600
    environment_variables = {
      GCP_PROJECT                  = var.gcp_project_id
      GCP_REGION                   = var.gcp_region
      DATAFLOW_TEMPLATE_LOCATION   = "${google_artifact_registry_repository.dataflow_repo.repository_url}/batting-pipeline"
      BQ_DATASET                   = "cricket_raw"
      BQ_TABLE                     = "batting_rankings"
      DATAFLOW_TEMP_LOCATION       = "gs://${google_storage_bucket.dataflow_temp.name}/temp"
    }
    service_account_email = google_service_account.cloud_function_sa.email
  }
}

# ============================================
# SCHEDULED QUERIES (for staging → curated)
# ============================================

resource "google_bigquery_data_transfer_config" "staging_to_curated" {
  display_name           = "Cricket Staging to Curated Daily"
  data_source_id         = "scheduled_query"
  destination_dataset_id = "cricket_curated"
  location               = var.gcp_region
  schedule               = "every day 08:00"
  service_account_name   = google_service_account.dataflow_sa.email

  params = {
    query = file("${path.module}/../bigquery/sql/07_create_curated_views.sql")
  }
}
