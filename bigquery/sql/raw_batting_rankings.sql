-- ============================================================================
-- Author: Satish Mudde
-- Created: 2026-06-07
-- File: raw_batting_rankings.sql
-- ============================================================================
-- Purpose: Create RAW layer table for batting rankings
-- This table stores the exact data as ingested from the API
-- Note: Dataset names are placeholders - substitute {RAW_DATASET} with actual dataset name from config
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.{RAW_DATASET}.batting_rankings` (
  rank INT64,
  player_id STRING,
  player_name STRING,
  country STRING,
  country_id STRING,
  rating FLOAT64,
  points FLOAT64,
  best_rank INT64,
  format STRING,
  ingested_at TIMESTAMP,
  source_file STRING
)
PARTITION BY DATE(ingested_at)
CLUSTER BY format, country
OPTIONS (
  description="Raw batting rankings from Cricbuzz API - Test/ODI/T20I formats",
  require_partition_filter=FALSE
);
