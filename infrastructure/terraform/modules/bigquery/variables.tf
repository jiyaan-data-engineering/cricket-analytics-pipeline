# ============================================================================
# BIGQUERY MODULE - Input Variables
# ============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "us-central1"
}

variable "raw_dataset_id" {
  description = "Raw dataset ID"
  type        = string
}

variable "staging_dataset_id" {
  description = "Staging dataset ID"
  type        = string
}

variable "curated_dataset_id" {
  description = "Curated dataset ID"
  type        = string
}

variable "audit_dataset_id" {
  description = "Audit logs dataset ID"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for BigQuery access"
  type        = string
}

variable "table_expiration_ms" {
  description = "Default table expiration in milliseconds (null = never)"
  type        = number
  default     = null
}

variable "raw_partition_expiration_ms" {
  description = "Raw table partition expiration in milliseconds"
  type        = number
  default     = 7776000000  # 90 days
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
