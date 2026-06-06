-- ============================================================================
-- Author: Satish Mudde
-- Created: 2026-06-07
-- File: fact_batting_rankings.sql
-- ============================================================================
-- Purpose: Create STAGING layer - Fact: Batting Rankings
-- Daily snapshot of batting rankings
-- Note: Dataset names are placeholders - substitute {RAW_DATASET} and {STAGING_DATASET} with actual names from config
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.{STAGING_DATASET}.fact_batting_rankings` (
  fact_id STRING NOT NULL,
  player_id STRING NOT NULL,
  country_id STRING,
  format_id INT64,
  date_id INT64,
  rank INT64,
  rating FLOAT64,
  points FLOAT64,
  best_rank INT64,
  source_file STRING,
  loaded_at TIMESTAMP NOT NULL,
  PRIMARY KEY (fact_id) NOT ENFORCED
)
PARTITION BY DATE(loaded_at)
CLUSTER BY format_id, country_id
OPTIONS (
  description="Fact table: daily batting rankings snapshot",
  require_partition_filter=FALSE
);

-- Merge logic to populate fact table from raw data
-- This scheduled query runs daily after raw data is loaded
MERGE `{PROJECT_ID}.{STAGING_DATASET}.fact_batting_rankings` T
USING (
  SELECT
    CONCAT(
      FORMAT_DATE('%Y%m%d', DATE(raw.ingested_at)),
      '-',
      raw.player_id,
      '-',
      CASE raw.format
        WHEN 'TEST' THEN '1'
        WHEN 'ODI' THEN '2'
        WHEN 'T20I' THEN '3'
      END
    ) as fact_id,
    raw.player_id,
    raw.country_id,
    CASE raw.format
      WHEN 'TEST' THEN 1
      WHEN 'ODI' THEN 2
      WHEN 'T20I' THEN 3
    END as format_id,
    CAST(FORMAT_DATE('%Y%m%d', DATE(raw.ingested_at)) AS INT64) as date_id,
    raw.rank,
    raw.rating,
    raw.points,
    raw.best_rank,
    raw.source_file,
    CURRENT_TIMESTAMP() as loaded_at
  FROM `{PROJECT_ID}.{RAW_DATASET}.batting_rankings` raw
  WHERE DATE(raw.ingested_at) = CURRENT_DATE()
) S
ON T.fact_id = S.fact_id AND T.player_id = S.player_id
WHEN MATCHED THEN
  UPDATE SET
    rank = S.rank,
    rating = S.rating,
    points = S.points,
    best_rank = S.best_rank,
    loaded_at = S.loaded_at
WHEN NOT MATCHED THEN
  INSERT (
    fact_id, player_id, country_id, format_id, date_id,
    rank, rating, points, best_rank, source_file, loaded_at
  )
  VALUES (
    S.fact_id, S.player_id, S.country_id, S.format_id, S.date_id,
    S.rank, S.rating, S.points, S.best_rank, S.source_file, S.loaded_at
  );
