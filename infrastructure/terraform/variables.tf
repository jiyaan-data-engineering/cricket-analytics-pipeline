# ============================================================================
# Terraform Variables - Cricket Analytics Pipeline
# All resource names are configurable via tfvars
# ============================================================================

# ============================================================================
# GCP PROJECT CONFIGURATION
# ============================================================================

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  # Deployment triggered - June 13, 2026
}

# ============================================================================
# GCS BUCKET NAMES - All Configurable
# ============================================================================

variable "bucket_prefix" {
  description = "Prefix for bucket names"
  type        = string
  default     = "cricket"
}

variable "gcs_raw_bucket_name" {
  description = "GCS bucket name for raw data ingestion"
  type        = string
  default     = "cricket-analytics-raw-data"
}

variable "gcs_templates_bucket_name" {
  description = "GCS bucket name for Dataflow Flex Templates"
  type        = string
  default     = "cricket-analytics-dataflow-templates"
}

variable "gcs_temp_bucket_name" {
  description = "GCS bucket name for Dataflow temporary data"
  type        = string
  default     = "cricket-analytics-dataflow-temp"
}

variable "gcs_raw_prefix" {
  description = "Prefix for raw data files in GCS"
  type        = string
  default     = "batting/"
}

# ============================================================================
# BIGQUERY DATASET & TABLE NAMES - All Configurable
# ============================================================================

variable "bq_raw_dataset" {
  description = "BigQuery raw data dataset name"
  type        = string
  default     = "cricket_raw"
}

variable "bq_staging_dataset" {
  description = "BigQuery staging dataset name (star schema)"
  type        = string
  default     = "cricket_staging"
}

variable "bq_curated_dataset" {
  description = "BigQuery curated dataset name (analytics views)"
  type        = string
  default     = "cricket_curated"
}

variable "bq_raw_table_name" {
  description = "BigQuery raw batting rankings table name"
  type        = string
  default     = "batting_rankings"
}

variable "bq_table_expiration_days" {
  description = "BigQuery table expiration in days"
  type        = number
  default     = 90
}

# ============================================================================
# BIGQUERY TABLE NAMES - All Configurable
# ============================================================================

variable "bq_raw_table_batting_rankings" {
  description = "BigQuery raw batting rankings table name"
  type        = string
  default     = "batting_rankings"
}

variable "bq_staging_table_dim_player" {
  description = "BigQuery staging dimension player table name"
  type        = string
  default     = "dim_player"
}

variable "bq_staging_table_dim_country" {
  description = "BigQuery staging dimension country table name"
  type        = string
  default     = "dim_country"
}

variable "bq_staging_table_dim_format" {
  description = "BigQuery staging dimension format table name"
  type        = string
  default     = "dim_format"
}

variable "bq_staging_table_dim_date" {
  description = "BigQuery staging dimension date table name"
  type        = string
  default     = "dim_date"
}

variable "bq_staging_table_fact_batting" {
  description = "BigQuery staging fact batting rankings table name"
  type        = string
  default     = "fact_batting_rankings"
}

# ============================================================================
# BIGQUERY VIEW NAMES - All Configurable
# ============================================================================

variable "bq_raw_view_latest_raw" {
  description = "BigQuery raw layer latest records view name"
  type        = string
  default     = "vw_latest_raw"
}

variable "bq_curated_view_batting_rankings_latest" {
  description = "BigQuery curated latest batting rankings view name"
  type        = string
  default     = "vw_batting_rankings_latest"
}

variable "bq_curated_view_batting_rankings_90day_trend" {
  description = "BigQuery curated 90-day batting ranking trend view name"
  type        = string
  default     = "vw_batting_rankings_90day_trend"
}

variable "bq_curated_view_top_10_batsmen_by_format" {
  description = "BigQuery curated top 10 batsmen by format view name"
  type        = string
  default     = "vw_top_10_batsmen_by_format"
}

variable "bq_curated_view_batting_statistics_by_country" {
  description = "BigQuery curated batting statistics by country view name"
  type        = string
  default     = "vw_batting_statistics_by_country"
}

variable "bq_curated_view_ranking_comparison_cross_format" {
  description = "BigQuery curated ranking comparison across formats view name"
  type        = string
  default     = "vw_ranking_comparison_cross_format"
}

# ============================================================================
# BIGQUERY CLUSTERING CONFIGURATION - All Configurable
# ============================================================================

variable "bq_raw_clustering_fields" {
  description = "BigQuery raw table clustering fields"
  type        = list(string)
  default     = ["format", "country"]
}

variable "bq_fact_clustering_fields" {
  description = "BigQuery fact table clustering fields"
  type        = list(string)
  default     = ["format_id", "country_id"]
}

# ============================================================================
# CLOUD FUNCTION NAMES & CONFIG
# ============================================================================

variable "cloud_function_name" {
  description = "Cloud Function name for GCS → Dataflow trigger"
  type        = string
  default     = "cricket-gcs-dataflow-trigger"
}

variable "cloud_function_runtime" {
  description = "Cloud Function runtime"
  type        = string
  default     = "python311"
}

variable "cloud_function_timeout" {
  description = "Cloud Function timeout in seconds"
  type        = number
  default     = 600
}

variable "cloud_function_memory" {
  description = "Cloud Function memory in MB"
  type        = number
  default     = 512
}

variable "cloud_function_max_instances" {
  description = "Cloud Function max concurrent instances"
  type        = number
  default     = 10
}

# ============================================================================
# DATAFLOW PIPELINE NAMES & CONFIG
# ============================================================================

variable "dataflow_pipeline_name" {
  description = "Dataflow pipeline name"
  type        = string
  default     = "cricket-batting-rankings-pipeline"
}

variable "dataflow_machine_type" {
  description = "Machine type for Dataflow workers"
  type        = string
  default     = "n1-standard-2"
}

variable "dataflow_num_workers" {
  description = "Initial number of Dataflow workers"
  type        = number
  default     = 2
}

variable "dataflow_max_workers" {
  description = "Maximum number of Dataflow workers"
  type        = number
  default     = 5
}

variable "dataflow_template_location" {
  description = "GCS location of Dataflow Flex Template metadata"
  type        = string
  default     = "gs://cricket-analytics-dataflow-templates/batting-pipeline/metadata"
}

# ============================================================================
# CLOUD SCHEDULER NAMES & CONFIG
# ============================================================================

variable "cloud_scheduler_job_name" {
  description = "Cloud Scheduler job name"
  type        = string
  default     = "cricket-daily-ingestion"
}

variable "cloud_scheduler_schedule" {
  description = "Cloud Scheduler cron schedule (UTC)"
  type        = string
  default     = "0 6 * * *"
}

variable "cloud_scheduler_timezone" {
  description = "Cloud Scheduler timezone"
  type        = string
  default     = "UTC"
}

variable "cloud_scheduler_description" {
  description = "Cloud Scheduler job description"
  type        = string
  default     = "Daily cricket rankings ingestion trigger"
}

# ============================================================================
# CLOUD COMPOSER (AIRFLOW) NAMES & CONFIG
# ============================================================================

variable "cloud_composer_name" {
  description = "Cloud Composer environment name"
  type        = string
  default     = "cricket-analytics-composer"
}

variable "cloud_composer_machine_type" {
  description = "Machine type for Cloud Composer GKE nodes"
  type        = string
  default     = "n1-standard-4"
}

variable "cloud_composer_node_count" {
  description = "Number of nodes in Cloud Composer cluster"
  type        = number
  default     = 3
}

variable "cloud_composer_disk_size" {
  description = "Cloud Composer disk size in GB"
  type        = number
  default     = 30
}

variable "cloud_composer_airflow_version" {
  description = "Airflow version for Cloud Composer"
  type        = string
  default     = "2.7.3"
}

variable "enable_cloud_composer" {
  description = "Enable Cloud Composer for Airflow orchestration"
  type        = bool
  default     = true
}

# ============================================================================
# ARTIFACT REGISTRY NAMES
# ============================================================================

variable "artifact_registry_name" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "cricket-docker"
}

variable "artifact_registry_format" {
  description = "Artifact Registry repository format"
  type        = string
  default     = "DOCKER"
}

# ============================================================================
# SERVICE ACCOUNT NAMES
# ============================================================================

variable "dataflow_sa_name" {
  description = "Dataflow service account name"
  type        = string
  default     = "cricket-dataflow-sa"
}

variable "cloud_function_sa_name" {
  description = "Cloud Function service account name"
  type        = string
  default     = "cricket-cloud-function-sa"
}

variable "cloud_composer_sa_name" {
  description = "Cloud Composer service account name"
  type        = string
  default     = "cricket-composer-sa"
}

# ============================================================================
# MONITORING & LOGGING
# ============================================================================

variable "enable_monitoring" {
  description = "Enable Cloud Monitoring and alerting"
  type        = bool
  default     = true
}

variable "alert_policy_name" {
  description = "Cloud Monitoring alert policy name"
  type        = string
  default     = "cricket-dag-failure-alert"
}

variable "log_sink_name" {
  description = "Cloud Logging sink name"
  type        = string
  default     = "cricket-analytics-logs"
}

# ============================================================================
# TAGS & LABELS
# ============================================================================

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    project     = "cricket-analytics"
    environment = "dev"
    managed_by  = "terraform"
    team        = "data-engineering"
  }
}
