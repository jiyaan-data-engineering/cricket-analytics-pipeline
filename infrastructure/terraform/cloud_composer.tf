# Cloud Composer (Apache Airflow) Configuration

# ============================================
# Cloud Composer Environment
# ============================================

resource "google_composer_environment" "cricket_analytics" {
  name   = "cricket-analytics-composer"
  region = var.gcp_region

  config {
    node_count = 3

    node_config {
      zone         = var.gcp_zone
      machine_type = var.cloud_composer_machine_type
      disk_size_gb = 30

      network = data.google_compute_network.default.id
    }

    # Software configuration
    software_config {
      image_version = "composer-2-airflow-2.7"
      python_version = "3"

      # PyPI packages
      pypi_packages = {
        "apache-airflow-providers-google" = "10.10.1"
        "apache-airflow-providers-apache-beam" = "5.3.1"
        "google-cloud-storage" = "2.10.0"
        "google-cloud-bigquery" = "3.13.0"
        "pandas" = "2.1.1"
        "pyyaml" = "6.0.1"
        "requests" = "2.31.0"
      }

      # Environment variables
      env_variables = {
        "GCP_PROJECT_ID" = var.gcp_project_id
        "GCP_REGION" = var.gcp_region
        "BQ_RAW_DATASET" = "cricket_raw"
        "BQ_STAGING_DATASET" = "cricket_staging"
        "BQ_CURATED_DATASET" = "cricket_curated"
        "RAW_BUCKET" = google_storage_bucket.raw_data.name
        "DATAFLOW_TEMPLATE_BUCKET" = google_storage_bucket.dataflow_templates.name
        "AIRFLOW__CORE__LOAD_EXAMPLES" = "False"
        "AIRFLOW__LOGGING__LOGGING_LEVEL" = "INFO"
      }

      # Airflow overrides
      airflow_config_overrides = {
        "core-parallelism" = "32"
        "core-dag_concurrency" = "16"
        "core-max_active_runs_per_dag" = "1"
        "scheduler-scheduler_heartbeat_interval" = "5"
      }
    }

    # Database configuration
    database_config {
      machine_type = "db-n1-standard-2"
    }

    # Web server configuration
    web_server_config {
      machine_type = "n1-standard-2"
    }

    # Encryption configuration
    encryption_config {
      kms_key_name = google_kms_crypto_key.composer.id
    }
  }

  depends_on = [
    google_project_service.required_apis,
  ]

  labels = {
    environment = var.environment
    purpose     = "cricket-analytics"
  }
}

# ============================================
# Service Account for Composer
# ============================================

resource "google_service_account" "composer_sa" {
  account_id   = "cricket-composer-sa"
  display_name = "Service Account for Cricket Composer"
}

# Grant BigQuery Admin role
resource "google_project_iam_member" "composer_bq_admin" {
  project = var.gcp_project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

# Grant Storage Admin role
resource "google_project_iam_member" "composer_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

# Grant Dataflow Admin role
resource "google_project_iam_member" "composer_dataflow_admin" {
  project = var.gcp_project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

# Grant Dataflow Worker role
resource "google_project_iam_member" "composer_dataflow_worker" {
  project = var.gcp_project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

# Grant Logging permissions
resource "google_project_iam_member" "composer_logging_admin" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

# ============================================
# KMS Key for Encryption (Optional but Recommended)
# ============================================

resource "google_kms_key_ring" "composer" {
  name     = "cricket-composer-keyring"
  location = var.gcp_region
}

resource "google_kms_crypto_key" "composer" {
  name            = "cricket-composer-key"
  key_ring        = google_kms_key_ring.composer.id
  rotation_period = "7776000s"  # 90 days

  labels = {
    environment = var.environment
  }
}

# ============================================
# Network for Composer
# ============================================

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_firewall" "composer_ingress" {
  name    = "allow-composer-internal"
  network = data.google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "6379", "3306"]
  }

  source_ranges = ["10.0.0.0/8"]

  target_tags = ["composer-environment"]
}

# ============================================
# Cloud Storage for DAGs
# ============================================

resource "google_storage_bucket" "composer_dags" {
  name          = "${var.cloud_composer_name}-dags-${var.gcp_project_id}"
  location      = var.gcp_region
  force_destroy = false

  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    purpose     = "composer-dags"
  }
}

# Upload DAG files to GCS
resource "google_storage_bucket_object" "cricket_analytics_dag" {
  name   = "dags/cricket_analytics_dag.py"
  bucket = google_storage_bucket.composer_dags.name
  source = "${path.module}/../airflow/dags/cricket_analytics_dag.py"
}

resource "google_storage_bucket_object" "data_quality_dag" {
  name   = "dags/data_quality_monitoring_dag.py"
  bucket = google_storage_bucket.composer_dags.name
  source = "${path.module}/../airflow/dags/data_quality_monitoring_dag.py"
}

# ============================================
# Airflow Variables
# ============================================

# Note: These need to be set in Airflow after environment creation
# Run: gcloud composer environments run cricket-analytics-composer --location us-central1 \
#      variables set -- gcp_project_id YOUR_PROJECT_ID

# ============================================
# Monitoring & Logging
# ============================================

resource "google_monitoring_alert_policy" "composer_dag_failure" {
  display_name = "Composer DAG Failure Alert"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "DAG task failure"

    condition_threshold {
      filter          = "resource.type=cloud_composer_environment AND metric.type=composer.googleapis.com/environment/dag_run/failed"
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0

      aggregations {
        alignment_period  = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = []  # Add your notification channel IDs

  documentation {
    content   = "DAG task has failed in Cricket Analytics Composer environment"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "composer_environment_health" {
  display_name = "Composer Environment Health Alert"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Unhealthy environment"

    condition_threshold {
      filter          = "resource.type=cloud_composer_environment AND metric.type=composer.googleapis.com/environment/is_healthy"
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period  = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = []  # Add your notification channel IDs

  documentation {
    content   = "Cricket Analytics Composer environment health check failed"
    mime_type = "text/markdown"
  }
}
