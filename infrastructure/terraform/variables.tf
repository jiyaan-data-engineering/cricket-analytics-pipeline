# ============================================================================
# TERRAFORM VARIABLES
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

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}
