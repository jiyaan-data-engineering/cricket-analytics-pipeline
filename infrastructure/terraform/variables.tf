# ============================================================================
# CRICKET ANALYTICS PIPELINE - PRODUCTION VARIABLES
# ============================================================================

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "cricket-analytics-prod"
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "backup_enabled" {
  description = "Enable backups for production"
  type        = bool
  default     = false
}

variable "monitoring_enabled" {
  description = "Enable monitoring for production"
  type        = bool
  default     = false
}
