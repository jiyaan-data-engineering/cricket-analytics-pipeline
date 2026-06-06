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
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "bucket_prefix" {
  description = "Prefix for GCS bucket names"
  type        = string
  default     = "cricket-analytics"
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

variable "rapidapi_key" {
  description = "RapidAPI key for Cricbuzz API"
  type        = string
  sensitive   = true
}

# ============================================
# Cloud Composer Variables
# ============================================

variable "composer_machine_type" {
  description = "Machine type for Cloud Composer nodes"
  type        = string
  default     = "n1-standard-4"
}

variable "composer_node_count" {
  description = "Number of nodes in Cloud Composer environment"
  type        = number
  default     = 3
}

variable "enable_cloud_composer" {
  description = "Enable Cloud Composer for Airflow orchestration"
  type        = bool
  default     = true
}
