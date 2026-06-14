# ============================================================================
# GCS MODULE - Input Variables
# ============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "GCS bucket location"
  type        = string
  default     = "us-central1"
}

variable "storage_class" {
  description = "GCS storage class (STANDARD, NEARLINE, COLDLINE)"
  type        = string
  default     = "STANDARD"
}

variable "versioning_enabled" {
  description = "Enable versioning for buckets"
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow Terraform to delete non-empty buckets"
  type        = bool
  default     = false  # Safety: prod/staging should not allow this
}

variable "raw_data_bucket_name" {
  description = "Raw data bucket name"
  type        = string
}

variable "dataflow_template_bucket_name" {
  description = "Dataflow template bucket name"
  type        = string
}

variable "dataflow_temp_bucket_name" {
  description = "Dataflow temporary bucket name"
  type        = string
}

variable "tf_state_bucket_name" {
  description = "Terraform state bucket name"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
