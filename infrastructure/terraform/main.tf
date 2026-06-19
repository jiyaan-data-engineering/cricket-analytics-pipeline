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
    bucket = "cricket-analytics-prod-tfstate"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ============================================================================
# ENABLE REQUIRED APIs
# ============================================================================
# TODO: Enable additional APIs when needed (BigQuery, Dataflow, Composer, etc)

resource "google_project_service" "required_apis" {
  for_each = toset([
    # "bigquery.googleapis.com",
    "storage-api.googleapis.com",
    # "dataflow.googleapis.com",
    # "cloudscheduler.googleapis.com",
    # "composer.googleapis.com",
    # "artifactregistry.googleapis.com",
    # "logging.googleapis.com",
    # "monitoring.googleapis.com",
    # "iam.googleapis.com"
  ])

  service            = each.value
  disable_on_destroy = false
}

# ============================================================================
# CREATE SERVICE ACCOUNTS
# ============================================================================
# TODO: Uncomment when ready to deploy Cloud Composer

# resource "google_service_account" "cloud_composer" {
#   account_id   = var.composer_service_account_id
#   display_name = "Cloud Composer Service Account"
# }

# Note: IAM roles must be set manually via setup-iam-roles.sh script
# This is due to GCP org policy restrictions on programmatic IAM changes

# ============================================================================
# CREATE GCS BUCKETS
# ============================================================================

resource "google_storage_bucket" "raw_data" {
  name          = var.raw_data_bucket_name
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket" "templates" {
  name          = var.dataflow_templates_bucket_name
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

resource "google_storage_bucket" "temp" {
  name          = var.dataflow_temp_bucket_name
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

# ============================================================================
# CREATE BIGQUERY DATASETS
# ============================================================================

resource "google_bigquery_dataset" "raw" {
  dataset_id    = var.raw_dataset_name
  friendly_name = "Cricket Raw Data"
  description   = "Raw data ingestion layer"
  location      = var.gcp_region
  project       = var.gcp_project_id

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "staging" {
  dataset_id    = var.staging_dataset_name
  friendly_name = "Cricket Staging"
  description   = "Staging/transformed data layer"
  location      = var.gcp_region
  project       = var.gcp_project_id

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "curated" {
  dataset_id    = var.curated_dataset_name
  friendly_name = "Cricket Curated"
  description   = "Curated/analytics-ready data"
  location      = var.gcp_region
  project       = var.gcp_project_id

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "audit_logs" {
  dataset_id    = var.audit_logs_dataset_name
  friendly_name = "Cricket Audit Logs"
  description   = "Pipeline audit and monitoring logs"
  location      = var.gcp_region
  project       = var.gcp_project_id

  depends_on = [google_project_service.required_apis]
}

# ============================================================================
# LOOKER STUDIO DASHBOARD
# ============================================================================
# TODO: Uncomment when BigQuery curated dataset is enabled

# resource "local_file" "looker_studio_setup" {
#   filename = "${path.module}/../../scripts/create-looker-dashboard.sh"
#   content  = <<-EOT
#     #!/bin/bash
#
#     # ============================================================================
#     # CREATE LOOKER STUDIO DASHBOARD
#     # ============================================================================
#     # This script creates a Looker Studio dashboard connected to cricket_curated dataset
#     # Manual setup required - use Looker Studio API or UI
#
#     set -e
#
#     PROJECT_ID="${var.gcp_project_id}"
#     REGION="${var.gcp_region}"
#     DASHBOARD_NAME="Cricket Analytics - Batting Rankings"
#
#     echo "🚀 Looker Studio Dashboard Setup"
#     echo "=================================="
#     echo "Project: $PROJECT_ID"
#     echo "Dataset: cricket_curated"
#     echo "Region: $REGION"
#     echo ""
#
#     echo "📊 Dashboard Configuration:"
#     echo "  Name: $DASHBOARD_NAME"
#     echo "  Data Source: cricket_curated"
#     echo ""
#
#     echo "⚠️ MANUAL SETUP REQUIRED (Looker Studio API not available via Terraform)"
#     echo ""
#     echo "📋 Steps to create dashboard:"
#     echo "  1. Go to: https://lookerstudio.google.com"
#     echo "  2. Click 'Create' → 'Report'"
#     echo "  3. Click 'Create new data source'"
#     echo "  4. Select 'BigQuery' connector"
#     echo "  5. Authenticate with your GCP account"
#     echo "  6. Select Project: $PROJECT_ID"
#     echo "  7. Select Dataset: cricket_curated"
#     echo "  8. Create data source"
#     echo ""
#     echo "📈 Add these visualizations:"
#     echo "  • Table: vw_batting_rankings_latest"
#     echo "    Dimensions: player_name, country, format, rank"
#     echo "    Metrics: rating, points"
#     echo ""
#     echo "  • Time Series: vw_batting_rankings_90day_trend"
#     echo "    Dimension: ingested_date"
#     echo "    Metric: rank (line chart)"
#     echo ""
#     echo "  • Bar Chart: vw_top_10_batsmen_by_format"
#     echo "    Dimension: format"
#     echo "    Metric: player_count"
#     echo ""
#     echo "  • Scorecard: vw_batting_statistics_by_country"
#     echo "    Metric: avg_rating (by country)"
#     echo ""
#     echo "  • Pivot Table: vw_ranking_comparison_cross_format"
#     echo "    Rows: player_name"
#     echo "    Values: test_rank, odi_rank, t20i_rank"
#     echo ""
#     echo "🔄 Configure auto-refresh:"
#     echo "  • Refresh interval: Daily at 09:00 UTC"
#     echo "  • Data freshness: Cricket Analytics main DAG completes at 08:00 UTC"
#     echo ""
#     echo "✅ Dashboard creation complete!"
#   EOT
#
#   depends_on = [
#     google_bigquery_dataset.curated
#   ]
# }
#
# resource "null_resource" "looker_studio_script" {
#   provisioner "local-exec" {
#     command = "chmod +x ${local_file.looker_studio_setup.filename}"
#   }
#
#   depends_on = [
#     local_file.looker_studio_setup
#   ]
# }

# Looker Studio dashboard automation is provided via scripts:
# - scripts/create-looker-dashboard.sh (interactive setup guide)
# - scripts/create-looker-dashboard-api.py (dashboard configuration reference)
# These can be run manually after Terraform deployment:
#   ./scripts/create-looker-dashboard.sh cricket-analytics-prod us-central1
#   python3 ./scripts/create-looker-dashboard-api.py cricket-analytics-prod cricket_curated

# ============================================================================
# CLOUD SCHEDULER & CLOUD COMPOSER - DEPLOYED VIA GITHUB ACTIONS
# ============================================================================
# Cloud Scheduler and Cloud Composer are configured in .github/workflows/deploy-prod.yml
# via gcloud commands for compatibility with GCP org policies.
#
# Cloud Scheduler triggers Cloud Composer daily at 06:00 UTC
# Cloud Composer runs the complete pipeline orchestration DAG:
# - Phase 1: API fetch → CSV to GCS
# - Phase 2: Dataflow reads CSV → writes to BigQuery Raw
# - Phase 3: MERGE operations → BigQuery Staging (star schema)
# - Phase 4: CREATE VIEW → BigQuery Curated (analytics views)
# - Phase 5: Dashboard refresh + reporting
