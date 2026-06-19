# ============================================================================
# TERRAFORM VARIABLES - ALL CONFIGURABLE, NO HARDCODED DEFAULTS
# ============================================================================

# GCP Configuration
variable "gcp_project_id" {
  description = "GCP Project ID for cricket analytics"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for all resources"
  type        = string
}

# Environment
variable "environment" {
  description = "Environment: dev, staging, or prod"
  type        = string
}

# GCS Bucket Names
variable "raw_data_bucket_name" {
  description = "GCS bucket for raw cricket data"
  type        = string
}

variable "dataflow_templates_bucket_name" {
  description = "GCS bucket for Dataflow templates"
  type        = string
}

variable "dataflow_temp_bucket_name" {
  description = "GCS bucket for Dataflow temporary files"
  type        = string
}

# BigQuery Dataset Names
variable "raw_dataset_name" {
  description = "BigQuery dataset for raw data"
  type        = string
}

variable "staging_dataset_name" {
  description = "BigQuery dataset for staging data"
  type        = string
}

variable "curated_dataset_name" {
  description = "BigQuery dataset for curated analytics data"
  type        = string
}

variable "audit_logs_dataset_name" {
  description = "BigQuery dataset for audit logs"
  type        = string
}

# Service Account
variable "composer_service_account_id" {
  description = "Service account ID for Cloud Composer"
  type        = string
}

# Cloud Composer
variable "composer_env_name" {
  description = "Cloud Composer environment name"
  type        = string
}

variable "composer_node_count" {
  description = "Number of nodes in Cloud Composer cluster"
  type        = number
  default     = 3
}

variable "composer_machine_type" {
  description = "Machine type for Cloud Composer nodes"
  type        = string
  default     = "n1-standard-4"
}

# DAG Configuration
variable "dag_schedule" {
  description = "Cron schedule for DAG execution (UTC)"
  type        = string
  default     = "0 6 * * *"
}

# Dataflow Configuration
variable "dataflow_worker_count_min" {
  description = "Minimum number of Dataflow workers"
  type        = number
  default     = 2
}

variable "dataflow_worker_count_max" {
  description = "Maximum number of Dataflow workers"
  type        = number
  default     = 5
}

variable "dataflow_worker_machine_type" {
  description = "Machine type for Dataflow workers"
  type        = string
  default     = "n1-standard-2"
}

# Tags and Labels
variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    project     = "cricket-analytics"
    managed_by  = "terraform"
    created_at  = "2026-06-19"
  }
}
