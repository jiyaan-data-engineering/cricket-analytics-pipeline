-- Create RAW layer table for batting rankings
-- This table stores the exact data as ingested from the API

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_raw.batting_rankings` (
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

-- Create view for latest 100 raw records per format (for debugging)
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_raw.vw_latest_raw` AS
SELECT
  rank,
  player_id,
  player_name,
  country,
  rating,
  format,
  DATE(ingested_at) as ingestion_date,
  ROW_NUMBER() OVER (PARTITION BY format, DATE(ingested_at) ORDER BY ingested_at DESC) as rn
FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
WHERE rn <= 100;
