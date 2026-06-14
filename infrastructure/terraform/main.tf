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
# ARTIFACT REGISTRY FOR DATAFLOW FLEX TEMPLATE
# ============================================================================

resource "google_artifact_registry_repository" "dataflow" {
  location      = var.gcp_region
  repository_id = "cricket-dataflow"
  description   = "Docker repository for Dataflow Flex Templates"
  format        = "DOCKER"
  project       = var.gcp_project_id
}

# ============================================================================
# CLOUD FUNCTION FOR DATAFLOW TRIGGER (2nd Gen)
# ============================================================================

resource "google_cloudfunctions2_function" "dataflow_trigger" {
  name        = "cricket-dataflow-trigger"
  location    = var.gcp_region
  description = "Triggered by GCS finalization to launch Dataflow job"
  project     = var.gcp_project_id

  build_config {
    runtime     = "python311"
    entry_point = "process_batting_file"

    source {
      storage_source {
        bucket = google_storage_bucket.raw_data.name
        object = "cloud-function/main.zip"
      }
    }
  }

  service_config {
    max_instance_count             = 10
    min_instance_count             = 1
    memory_mb                      = 512
    timeout_seconds                = 600
    service_account_email          = google_service_account.cloud_function.email
    ingress_settings               = "INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    environment_variables = {
      GCP_PROJECT                = var.gcp_project_id
      GCP_REGION                 = var.gcp_region
      DATAFLOW_TEMPLATE_LOCATION = "gs://${google_storage_bucket.templates.name}/batting-pipeline"
      BQ_DATASET                 = google_bigquery_dataset.raw.dataset_id
      BQ_TABLE                   = "batting_rankings"
    }
  }

  depends_on = [
    google_project_service.required_apis["cloudfunctions.googleapis.com"]
  ]
}

# ============================================================================
# EVENTARC TRIGGER: GCS → CLOUD FUNCTION
# ============================================================================

resource "google_eventarc_trigger" "gcs_to_dataflow" {
  name            = "cricket-gcs-to-dataflow"
  location        = var.gcp_region
  service_account = google_service_account.cloud_function.email
  project         = var.gcp_project_id

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.raw_data.name
  }

  destination {
    cloud_function {
      function = google_cloudfunctions2_function.dataflow_trigger.id
    }
  }

  depends_on = [
    google_project_service.required_apis["eventarc.googleapis.com"]
  ]
}

# ============================================================================
# CLOUD RUN FOR INGESTION SERVICE
# ============================================================================

resource "google_cloud_run_service" "ingestion" {
  name     = "cricket-ingestion"
  location = var.gcp_region
  project  = var.gcp_project_id

  template {
    spec {
      service_account = google_service_account.cloud_run.email
      timeout_seconds = 600

      containers {
        image = "gcr.io/cloud-builders/gke-deploy:stable"

        env {
          name  = "GCP_PROJECT"
          value = var.gcp_project_id
        }

        env {
          name  = "GCP_REGION"
          value = var.gcp_region
        }

        env {
          name  = "RAW_BUCKET"
          value = google_storage_bucket.raw_data.name
        }

        env {
          name  = "RAPIDAPI_KEY"
          value = ""
        }
      }
    }
  }

  depends_on = [
    google_project_service.required_apis["run.googleapis.com"]
  ]
}

# ============================================================================
# CLOUD SCHEDULER FOR DAILY INGESTION
# ============================================================================

resource "google_cloud_scheduler_job" "ingestion_trigger" {
  name             = "cricket-ingestion-daily"
  description      = "Trigger Cloud Run for daily cricket data ingestion at 06:00 UTC"
  schedule         = "0 6 * * *"
  time_zone        = "UTC"
  attempt_deadline = "320s"
  region           = var.gcp_region
  project          = var.gcp_project_id

  http_target {
    uri         = google_cloud_run_service.ingestion.status[0].url
    http_method = "POST"

    oidc_token {
      service_account_email = google_service_account.cloud_run.email
      audience              = google_cloud_run_service.ingestion.status[0].url
    }
  }

  depends_on = [
    google_project_service.required_apis["cloudscheduler.googleapis.com"]
  ]
}
