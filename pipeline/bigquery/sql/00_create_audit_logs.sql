-- ============================================================================
-- AUDIT LOGS DATASET & TABLES 
-- Pipeline tracking and monitoring for each data pipeline stage
-- ============================================================================

-- Create audit logs dataset
CREATE SCHEMA IF NOT EXISTS `{PROJECT_ID}.cricket_audit_logs`
OPTIONS(
  description="Audit logs for cricket analytics pipeline execution and monitoring",
  location="us-central1"
);

-- ============================================================================
-- TABLE 1: API_INGESTION_AUDIT_LOG
-- Tracks: Cricbuzz API data fetching and initial data loading
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_audit_logs.api_ingestion_audit_log` (
  run_id STRING NOT NULL,
  pipeline_stage STRING NOT NULL,
  execution_date TIMESTAMP NOT NULL,
  status STRING NOT NULL,  -- SUCCESS, FAILED, RUNNING

  -- API Details
  api_endpoint STRING,
  formats_requested ARRAY<STRING>,

  -- Data Metrics
  total_records_fetched INT64,
  test_format_records INT64,
  odi_format_records INT64,
  t20i_format_records INT64,

  -- Storage
  gcs_output_path STRING,
  file_size_bytes INT64,

  -- Timing
  execution_start_time TIMESTAMP,
  execution_end_time TIMESTAMP,
  execution_duration_seconds INT64,

  -- Error Handling & Retry
  error_message STRING,
  error_code STRING,
  retry_attempt_count INT64,

  -- Audit Trail
  created_timestamp TIMESTAMP,
  modified_timestamp TIMESTAMP,

)
PARTITION BY DATE(execution_date)
CLUSTER BY status, execution_date;

-- ============================================================================
-- TABLE 2: DATAFLOW_PROCESSING_AUDIT_LOG
-- Tracks: Apache Beam Dataflow job execution and data processing
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_audit_logs.dataflow_processing_audit_log` (
  run_id STRING NOT NULL,
  pipeline_stage STRING NOT NULL,
  execution_date TIMESTAMP NOT NULL,
  status STRING NOT NULL,  -- SUCCESS, FAILED, RUNNING

  -- Dataflow Job Details
  dataflow_job_id STRING,
  dataflow_job_name STRING,
  dataflow_template_location STRING,

  -- Input/Output Specifications
  input_file_gcs_path STRING,
  output_bigquery_table STRING,
  output_bigquery_dataset STRING,

  -- Processing Metrics
  input_record_count INT64,
  output_record_count INT64,
  processed_record_count INT64,
  skipped_record_count INT64,
  error_record_count INT64,
  success_rate_percent FLOAT64,

  -- Resource Allocation
  worker_node_count INT64,
  worker_machine_type STRING,
  total_vcore_hours FLOAT64,
  total_memory_gb FLOAT64,

  -- Timing & Performance
  execution_start_time TIMESTAMP,
  execution_end_time TIMESTAMP,
  execution_duration_seconds INT64,
  throughput_records_per_second FLOAT64,

  -- Error Handling
  error_message STRING,
  error_code STRING,
  error_type STRING,

  -- Audit Trail
  created_timestamp TIMESTAMP,
  modified_timestamp TIMESTAMP,

)
PARTITION BY DATE(execution_date)
CLUSTER BY status, dataflow_job_id;

-- ============================================================================
-- TABLE 3: DATA_TRANSFORMATION_AUDIT_LOG
-- Tracks: BigQuery SQL transformations (RAW → STAGING layer)
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_audit_logs.data_transformation_audit_log` (
  run_id STRING NOT NULL,
  pipeline_stage STRING NOT NULL,
  execution_date TIMESTAMP NOT NULL,
  status STRING NOT NULL,  -- SUCCESS, FAILED, RUNNING

  -- Transformation Details
  transformation_name STRING,  -- dim_player, dim_country, fact_batting, etc.
  source_table_name STRING,
  target_table_name STRING,
  transformation_type STRING,  -- MERGE, INSERT, UPDATE, DELETE

  -- Data Metrics
  source_record_count INT64,
  inserted_record_count INT64,
  updated_record_count INT64,
  deleted_record_count INT64,
  total_affected_record_count INT64,

  -- Data Quality
  null_value_check_passed BOOL,
  duplicate_record_check_passed BOOL,
  referential_integrity_violations INT64,
  constraint_violation_count INT64,
  data_quality_score FLOAT64,

  -- Performance
  execution_start_time TIMESTAMP,
  execution_end_time TIMESTAMP,
  execution_duration_seconds INT64,
  bytes_processed INT64,
  bytes_billed INT64,

  -- Error Handling
  error_message STRING,
  error_code STRING,
  sql_error_line_number INT64,

  -- Audit Trail
  created_timestamp TIMESTAMP,
  modified_timestamp TIMESTAMP,

)
PARTITION BY DATE(execution_date)
CLUSTER BY status, transformation_name;

-- ============================================================================
-- TABLE 4: ANALYTICS_VIEWS_AUDIT_LOG
-- Tracks: Curated analytics views creation and data freshness
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_audit_logs.analytics_views_audit_log` (
  run_id STRING NOT NULL,
  pipeline_stage STRING NOT NULL,
  execution_date TIMESTAMP NOT NULL,
  status STRING NOT NULL,  -- SUCCESS, FAILED, RUNNING

  -- View Details
  view_name STRING,  -- vw_current_rankings, vw_trend, etc.
  view_type STRING,  -- MATERIALIZED_VIEW, LOGICAL_VIEW
  target_dataset STRING,

  -- Data Metrics
  view_row_count INT64,
  unique_player_count INT64,
  unique_country_count INT64,
  date_range_start_date DATE,
  date_range_end_date DATE,

  -- Query Performance
  query_execution_time_milliseconds INT64,
  bytes_processed INT64,
  bytes_billed INT64,
  query_cost_usd FLOAT64,

  -- Data Freshness & Lag
  max_ingestion_date DATE,
  data_lag_days INT64,
  freshness_score FLOAT64,

  -- Timing
  execution_start_time TIMESTAMP,
  execution_end_time TIMESTAMP,
  execution_duration_seconds INT64,

  -- Error Handling
  error_message STRING,
  error_code STRING,

  -- Audit Trail
  created_timestamp TIMESTAMP,
  modified_timestamp TIMESTAMP,

)
PARTITION BY DATE(execution_date)
CLUSTER BY status, view_name;

-- ============================================================================
-- TABLE 5: PIPELINE_EXECUTION_SUMMARY
-- Master log aggregating all pipeline stages
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_audit_logs.pipeline_execution_summary` (
  execution_run_id STRING NOT NULL,
  pipeline_stage_number INT64,  -- 1, 2, 3, 4
  pipeline_stage_name STRING,
  execution_date TIMESTAMP NOT NULL,
  status STRING NOT NULL,

  -- Aggregated Metrics
  total_records_processed INT64,
  total_records_with_errors INT64,
  overall_success_rate FLOAT64,

  -- Source & Target
  data_source_system STRING,
  data_target_system STRING,

  -- Duration
  execution_start_time TIMESTAMP,
  execution_end_time TIMESTAMP,
  total_execution_duration_seconds INT64,

  -- Error Summary
  error_summary_message STRING,
  error_count INT64,
  warning_count INT64,

  -- Audit Trail
  created_timestamp TIMESTAMP,

)
PARTITION BY DATE(execution_date)
CLUSTER BY status, pipeline_stage_name;
