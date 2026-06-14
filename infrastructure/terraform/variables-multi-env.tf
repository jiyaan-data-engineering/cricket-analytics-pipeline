# ============================================================================
# MULTI-ENVIRONMENT TERRAFORM VARIABLES
# Environment-Specific Configuration (dev, staging, prod)
# ============================================================================

# ============================================================================
# ENVIRONMENT SELECTION
# ============================================================================

variable "environment" {
  description = "Environment name: dev, staging, or prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "environment_short" {
  description = "Short environment prefix for resource names (dev, stg, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment_short)
    error_message = "Short environment must be one of: dev, stg, prod"
  }
}

# ============================================================================
# GCP PROJECT & REGION
# ============================================================================

variable "gcp_project_id" {
  description = "GCP Project ID (single project for all environments)"
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

# ============================================================================
# RESOURCE NAMING & LABELING
# ============================================================================

variable "project_name" {
  description = "Project name for labeling"
  type        = string
  default     = "cricket-analytics"
}

variable "resource_labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    team       = "data-engineering"
  }
}

# ============================================================================
# BIGQUERY CONFIGURATION
# ============================================================================

variable "bq_dataset_prefix" {
  description = "BigQuery dataset prefix (dev_, stg_, prod_)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9_]*$", var.bq_dataset_prefix))
    error_message = "Dataset prefix must contain only lowercase letters, numbers, and underscores"
  }
}

variable "bq_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "us-central1"
}

variable "bq_dataset_expiration_days" {
  description = "Auto-delete datasets after N days (null = never)"
  type        = number
  default     = null
}

variable "raw_dataset_name" {
  description = "Raw layer dataset name"
  type        = string
  default     = "cricket_raw"
}

variable "staging_dataset_name" {
  description = "Staging layer dataset name"
  type        = string
  default     = "cricket_staging"
}

variable "curated_dataset_name" {
  description = "Curated layer dataset name"
  type        = string
  default     = "cricket_curated"
}

variable "audit_dataset_name" {
  description = "Audit logs dataset name"
  type        = string
  default     = "cricket_audit_logs"
}

variable "raw_table_partition_expiration_days" {
  description = "Raw table partition expiration in days"
  type        = number
  default     = 90
}

# ============================================================================
# GCS BUCKET CONFIGURATION
# ============================================================================

variable "gcs_bucket_prefix" {
  description = "GCS bucket prefix for all buckets"
  type        = string
  # Example: "dev-cricket", "stg-cricket", "prod-cricket"
}

variable "gcs_location" {
  description = "GCS bucket location"
  type        = string
  default     = "us-central1"
}

variable "gcs_storage_class" {
  description = "GCS storage class (STANDARD, NEARLINE, COLDLINE)"
  type        = string
  default     = "STANDARD"
}

variable "gcs_versioning_enabled" {
  description = "Enable GCS object versioning"
  type        = bool
  default     = false
}

# Bucket names
variable "raw_data_bucket_name" {
  description = "Raw data bucket name"
  type        = string
  default     = "cricket-raw-data"
}

variable "dataflow_template_bucket_name" {
  description = "Dataflow template bucket name"
  type        = string
  default     = "cricket-dataflow-templates"
}

variable "dataflow_temp_bucket_name" {
  description = "Dataflow temporary bucket name"
  type        = string
  default     = "cricket-dataflow-temp"
}

variable "tf_state_bucket_name" {
  description = "Terraform state bucket name"
  type        = string
  default     = "cricket-tf-state"
}

# ============================================================================
# DATAFLOW CONFIGURATION
# ============================================================================

variable "dataflow_worker_machine_type" {
  description = "Dataflow worker machine type"
  type        = string
  default     = "n1-standard-2"
}

variable "dataflow_min_workers" {
  description = "Minimum number of Dataflow workers"
  type        = number
  default     = 2
}

variable "dataflow_max_workers" {
  description = "Maximum number of Dataflow workers"
  type        = number
  default     = 5
}

variable "dataflow_autoscaling_enabled" {
  description = "Enable Dataflow autoscaling"
  type        = bool
  default     = true
}

variable "dataflow_temp_location" {
  description = "Dataflow temporary location"
  type        = string
  # Will be set to gs://{dataflow_temp_bucket}/temp
}

# ============================================================================
# CLOUD SCHEDULER CONFIGURATION
# ============================================================================

variable "cloud_scheduler_enabled" {
  description = "Enable Cloud Scheduler"
  type        = bool
  default     = true
}

variable "cloud_scheduler_schedule" {
  description = "Cloud Scheduler cron expression (UTC)"
  type        = string
  default     = "0 6 * * *"  # Daily at 6 AM UTC
}

variable "cloud_scheduler_timezone" {
  description = "Cloud Scheduler timezone"
  type        = string
  default     = "UTC"
}

# ============================================================================
# SERVICE ACCOUNTS & IAM
# ============================================================================

variable "dataflow_service_account_name" {
  description = "Dataflow service account name"
  type        = string
  default     = "cricket-dataflow-sa"
}

variable "cloud_function_service_account_name" {
  description = "Cloud Function service account name"
  type        = string
  default     = "cricket-cloud-function-sa"
}

variable "cloud_run_service_account_name" {
  description = "Cloud Run service account name"
  type        = string
  default     = "cricket-cloud-run-sa"
}

variable "cloud_composer_service_account_name" {
  description = "Cloud Composer service account name"
  type        = string
  default     = "cricket-composer-sa"
}

# ============================================================================
# CLOUD COMPOSER (AIRFLOW) CONFIGURATION
# ============================================================================

variable "cloud_composer_enabled" {
  description = "Enable Cloud Composer environment"
  type        = bool
  default     = true
}

variable "cloud_composer_node_count" {
  description = "Number of Cloud Composer nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.cloud_composer_node_count >= 3
    error_message = "Cloud Composer requires minimum 3 nodes"
  }
}

variable "cloud_composer_machine_type" {
  description = "Cloud Composer node machine type"
  type        = string
  default     = "n1-standard-4"
}

variable "cloud_composer_disk_size_gb" {
  description = "Cloud Composer disk size in GB"
  type        = number
  default     = 30
}

# ============================================================================
# MONITORING & ALERTING
# ============================================================================

variable "monitoring_enabled" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = false  # Lite in dev, true in stg/prod
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
  default     = ""
}

# ============================================================================
# BACKUP & DISASTER RECOVERY
# ============================================================================

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = false  # Disabled in dev/stg, enabled in prod
}

variable "backup_frequency_hours" {
  description = "Backup frequency in hours"
  type        = number
  default     = 24
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# ============================================================================
# FEATURE FLAGS
# ============================================================================

variable "api_ingestion_enabled" {
  description = "Enable API ingestion pipeline"
  type        = bool
  default     = true
}

variable "dataflow_processing_enabled" {
  description = "Enable Dataflow processing"
  type        = bool
  default     = true
}

variable "bigquery_transformation_enabled" {
  description = "Enable BigQuery transformations"
  type        = bool
  default     = true
}

# ============================================================================
# ENVIRONMENT-SPECIFIC SETTINGS (computed from environment)
# ============================================================================

locals {
  # Full dataset names with prefix
  raw_dataset         = "${var.bq_dataset_prefix}${var.raw_dataset_name}"
  staging_dataset     = "${var.bq_dataset_prefix}${var.staging_dataset_name}"
  curated_dataset     = "${var.bq_dataset_prefix}${var.curated_dataset_name}"
  audit_dataset       = "${var.bq_dataset_prefix}${var.audit_dataset_name}"

  # Full bucket names with prefix
  raw_data_bucket             = "${var.gcs_bucket_prefix}-${var.raw_data_bucket_name}"
  dataflow_template_bucket    = "${var.gcs_bucket_prefix}-${var.dataflow_template_bucket_name}"
  dataflow_temp_bucket        = "${var.gcs_bucket_prefix}-${var.dataflow_temp_bucket_name}"
  tf_state_bucket             = "${var.gcs_bucket_prefix}-${var.tf_state_bucket_name}"

  # Resource labels with environment
  resource_labels = merge(
    var.resource_labels,
    {
      environment = var.environment
      environment_short = var.environment_short
    }
  )

  # Environment-specific defaults
  is_dev     = var.environment_short == "dev"
  is_staging = var.environment_short == "stg"
  is_prod    = var.environment_short == "prod"
}
