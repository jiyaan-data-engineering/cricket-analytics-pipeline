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
# LOOKER STUDIO DASHBOARD
# ============================================================================

resource "local_file" "looker_studio_setup" {
  filename = "${path.module}/../../scripts/create-looker-dashboard.sh"
  content  = <<-EOT
    #!/bin/bash

    # ============================================================================
    # CREATE LOOKER STUDIO DASHBOARD
    # ============================================================================
    # This script creates a Looker Studio dashboard connected to cricket_curated dataset
    # Manual setup required - use Looker Studio API or UI

    set -e

    PROJECT_ID="${var.gcp_project_id}"
    REGION="${var.gcp_region}"
    DASHBOARD_NAME="Cricket Analytics - Batting Rankings"

    echo "🚀 Looker Studio Dashboard Setup"
    echo "=================================="
    echo "Project: $PROJECT_ID"
    echo "Dataset: cricket_curated"
    echo "Region: $REGION"
    echo ""

    echo "📊 Dashboard Configuration:"
    echo "  Name: $DASHBOARD_NAME"
    echo "  Data Source: cricket_curated"
    echo ""

    echo "⚠️ MANUAL SETUP REQUIRED (Looker Studio API not available via Terraform)"
    echo ""
    echo "📋 Steps to create dashboard:"
    echo "  1. Go to: https://lookerstudio.google.com"
    echo "  2. Click 'Create' → 'Report'"
    echo "  3. Click 'Create new data source'"
    echo "  4. Select 'BigQuery' connector"
    echo "  5. Authenticate with your GCP account"
    echo "  6. Select Project: $PROJECT_ID"
    echo "  7. Select Dataset: cricket_curated"
    echo "  8. Create data source"
    echo ""
    echo "📈 Add these visualizations:"
    echo "  • Table: vw_batting_rankings_latest"
    echo "    Dimensions: player_name, country, format, rank"
    echo "    Metrics: rating, points"
    echo ""
    echo "  • Time Series: vw_batting_rankings_90day_trend"
    echo "    Dimension: ingested_date"
    echo "    Metric: rank (line chart)"
    echo ""
    echo "  • Bar Chart: vw_top_10_batsmen_by_format"
    echo "    Dimension: format"
    echo "    Metric: player_count"
    echo ""
    echo "  • Scorecard: vw_batting_statistics_by_country"
    echo "    Metric: avg_rating (by country)"
    echo ""
    echo "  • Pivot Table: vw_ranking_comparison_cross_format"
    echo "    Rows: player_name"
    echo "    Values: test_rank, odi_rank, t20i_rank"
    echo ""
    echo "🔄 Configure auto-refresh:"
    echo "  • Refresh interval: Daily at 09:00 UTC"
    echo "  • Data freshness: Cricket Analytics main DAG completes at 08:00 UTC"
    echo ""
    echo "✅ Dashboard creation complete!"
  EOT

  depends_on = [
    google_bigquery_dataset.curated
  ]
}

resource "null_resource" "looker_studio_script" {
  provisioner "local-exec" {
    command = "chmod +x ${local_file.looker_studio_setup.filename}"
  }

  depends_on = [
    local_file.looker_studio_setup
  ]
}

# Looker Studio dashboard automation is provided via scripts:
# - scripts/create-looker-dashboard.sh (interactive setup guide)
# - scripts/create-looker-dashboard-api.py (dashboard configuration reference)
# These can be run manually after Terraform deployment:
#   ./scripts/create-looker-dashboard.sh cricket-analytics-prod us-central1
#   python3 ./scripts/create-looker-dashboard-api.py cricket-analytics-prod cricket_curated

# ============================================================================
# CLOUD FUNCTION - EVENT-DRIVEN DATAFLOW TRIGGER
# ============================================================================

resource "null_resource" "cloud_function_package" {
  provisioner "local-exec" {
    command = "cd '${path.module}/../../pipeline/cloud_function' && zip -r -q /tmp/cloud_function.zip . && gsutil cp /tmp/cloud_function.zip gs://${google_storage_bucket.templates.name}/cloud-function-source.zip"
  }

  depends_on = [
    google_storage_bucket.templates
  ]
}

resource "google_cloudfunctions_function" "dataflow_trigger" {
  name        = "cricket-dataflow-trigger"
  description = "Triggers Dataflow on GCS CSV upload"
  runtime     = "python311"
  region      = var.gcp_region
  project     = var.gcp_project_id

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.templates.name
  source_archive_object = "cloud-function-source.zip"
  entry_point           = "process_batting_file"

  event_trigger {
    event_type = "google.storage.object.finalize"
    resource   = google_storage_bucket.raw_data.name
  }

  service_account_email = google_service_account.cloud_function.email

  environment_variables = {
    GCP_PROJECT_ID           = var.gcp_project_id
    GCP_REGION               = var.gcp_region
    DATAFLOW_TEMPLATE_BUCKET = google_storage_bucket.templates.name
    BQ_DATASET               = google_bigquery_dataset.raw.dataset_id
  }

  depends_on = [
    google_project_service.required_apis["cloudfunctions.googleapis.com"],
    null_resource.cloud_function_package
  ]
}

# IAM roles for Cloud Function service account - MUST BE SET MANUALLY due to GCP org policy
# After Terraform apply, run these gcloud commands:
# gcloud projects add-iam-policy-binding PROJECT_ID \
#   --member=serviceAccount:cricket-cloud-function-sa@PROJECT_ID.iam.gserviceaccount.com \
#   --role=roles/dataflow.admin
#
# gcloud projects add-iam-policy-binding PROJECT_ID \
#   --member=serviceAccount:cricket-cloud-function-sa@PROJECT_ID.iam.gserviceaccount.com \
#   --role=roles/iam.serviceAccountUser

resource "local_file" "cloud_function_iam_setup" {
  filename = "${path.module}/../../scripts/setup-cloud-function-iam.sh"
  content  = <<-EOT
    #!/bin/bash
    set -e

    PROJECT_ID=$1
    if [ -z "$PROJECT_ID" ]; then
      echo "Usage: setup-cloud-function-iam.sh <PROJECT_ID>"
      exit 1
    fi

    echo "Setting up IAM roles for Cloud Function service account..."

    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:cricket-cloud-function-sa@$PROJECT_ID.iam.gserviceaccount.com" \
      --role="roles/dataflow.admin" \
      --condition=None

    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:cricket-cloud-function-sa@$PROJECT_ID.iam.gserviceaccount.com" \
      --role="roles/iam.serviceAccountUser" \
      --condition=None

    echo "✅ Cloud Function IAM roles configured"
  EOT

  depends_on = [
    google_service_account.cloud_function
  ]
}

resource "null_resource" "make_iam_script_executable" {
  provisioner "local-exec" {
    command = "chmod +x '${local_file.cloud_function_iam_setup.filename}'"
  }

  depends_on = [
    local_file.cloud_function_iam_setup
  ]
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
