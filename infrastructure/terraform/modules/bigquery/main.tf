# ============================================================================
# BIGQUERY MODULE - Creates datasets and tables
# ============================================================================

# Create Raw Dataset
resource "google_bigquery_dataset" "raw" {
  dataset_id           = var.raw_dataset_id
  friendly_name        = "Raw Data Layer - ${var.environment}"
  description          = "Raw data layer for cricket analytics (${var.environment})"
  location             = var.location
  default_table_expiration_ms = var.table_expiration_ms

  labels = var.labels

  access {
    role          = "OWNER"
    user_by_email = var.service_account_email
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }
}

# Create Staging Dataset
resource "google_bigquery_dataset" "staging" {
  dataset_id           = var.staging_dataset_id
  friendly_name        = "Staging Data Layer - ${var.environment}"
  description          = "Staging layer with dimensional modeling (${var.environment})"
  location             = var.location
  default_table_expiration_ms = null

  labels = var.labels

  access {
    role          = "OWNER"
    user_by_email = var.service_account_email
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }
}

# Create Curated Dataset
resource "google_bigquery_dataset" "curated" {
  dataset_id           = var.curated_dataset_id
  friendly_name        = "Curated Analytics Layer - ${var.environment}"
  description          = "Curated layer for business analytics (${var.environment})"
  location             = var.location
  default_table_expiration_ms = null

  labels = var.labels

  access {
    role          = "OWNER"
    user_by_email = var.service_account_email
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }
}

# Create Audit Logs Dataset
resource "google_bigquery_dataset" "audit_logs" {
  dataset_id           = var.audit_dataset_id
  friendly_name        = "Audit Logs - ${var.environment}"
  description          = "Pipeline execution audit logs (${var.environment})"
  location             = var.location
  default_table_expiration_ms = null

  labels = var.labels

  access {
    role          = "OWNER"
    user_by_email = var.service_account_email
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }
}

# Create Raw Batting Rankings Table
resource "google_bigquery_table" "raw_batting_rankings" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = "batting_rankings"

  description = "Raw batting rankings from Cricbuzz API"

  labels = var.labels

  time_partitioning {
    type                     = "DAY"
    field                    = "ingested_at"
    expiration_ms            = var.raw_partition_expiration_ms
    require_partition_filter = false
  }

  clustering = ["format", "country"]

  schema = jsonencode([
    {
      name        = "rank"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Player ranking in the format"
    },
    {
      name        = "player_id"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Unique player identifier"
    },
    {
      name        = "player_name"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Full name of the player"
    },
    {
      name        = "country"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Country name"
    },
    {
      name        = "country_id"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Country ID"
    },
    {
      name        = "rating"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Player rating"
    },
    {
      name        = "points"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Rating points"
    },
    {
      name        = "best_rank"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Best rank achieved"
    },
    {
      name        = "format"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Match format (test, odi, t20i)"
    },
    {
      name        = "ingested_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Timestamp when data was ingested"
    },
    {
      name        = "source_file"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Source file path in GCS"
    }
  ])
}

# Create Audit Logs Table
resource "google_bigquery_table" "audit_logs_summary" {
  dataset_id = google_bigquery_dataset.audit_logs.dataset_id
  table_id   = "pipeline_execution_summary"

  description = "Master audit log for pipeline executions"

  labels = var.labels

  time_partitioning {
    type  = "DAY"
    field = "execution_date"
  }

  clustering = ["status", "pipeline_stage_name"]

  schema = jsonencode([
    {
      name        = "execution_run_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique execution run ID"
    },
    {
      name        = "pipeline_stage_number"
      type        = "INTEGER"
      mode        = "REQUIRED"
      description = "Pipeline stage number (1-4)"
    },
    {
      name        = "pipeline_stage_name"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Pipeline stage name"
    },
    {
      name        = "execution_date"
      type        = "TIMESTAMP"
      mode        = "REQUIRED"
      description = "Execution date and time"
    },
    {
      name        = "status"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "SUCCESS or FAILED"
    },
    {
      name        = "total_records_processed"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Total records processed"
    },
    {
      name        = "total_records_with_errors"
      type        = "INTEGER"
      mode        = "NULLABLE"
      description = "Records with errors"
    },
    {
      name        = "overall_success_rate"
      type        = "FLOAT"
      mode        = "NULLABLE"
      description = "Success rate percentage"
    },
    {
      name        = "execution_start_time"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Execution start time"
    },
    {
      name        = "execution_end_time"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Execution end time"
    },
    {
      name        = "error_summary_message"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Error summary if any"
    },
    {
      name        = "created_timestamp"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Record creation timestamp"
    }
  ])
}
