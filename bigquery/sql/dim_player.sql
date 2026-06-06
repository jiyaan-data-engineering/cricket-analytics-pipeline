-- ============================================================================
-- Author: Satish Mudde
-- Created: 2026-06-07
-- File: dim_player.sql
-- ============================================================================
-- Purpose: Create STAGING layer - Dimension: Player
-- Slowly Changing Dimension Type 1 (current attributes only)
-- Note: Dataset names are placeholders - substitute {RAW_DATASET} and {STAGING_DATASET} with actual names from config
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.{STAGING_DATASET}.dim_player` (
  player_id STRING NOT NULL,
  player_name STRING,
  country_id STRING,
  last_updated TIMESTAMP NOT NULL,
  PRIMARY KEY (player_id) NOT ENFORCED
)
PARTITION BY DATE(last_updated)
OPTIONS (
  description="Player dimension - SCD Type 1",
  require_partition_filter=FALSE
);

-- Merge logic to upsert player data
-- This would be called daily via scheduled query after Dataflow loads raw data
MERGE `{PROJECT_ID}.{STAGING_DATASET}.dim_player` T
USING (
  SELECT DISTINCT
    player_id,
    MAX(player_name) as player_name,
    MAX(country_id) as country_id,
    CURRENT_TIMESTAMP() as last_updated
  FROM `{PROJECT_ID}.{RAW_DATASET}.batting_rankings`
  WHERE player_id IS NOT NULL
  GROUP BY player_id
) S
ON T.player_id = S.player_id
WHEN MATCHED THEN
  UPDATE SET
    player_name = S.player_name,
    country_id = S.country_id,
    last_updated = S.last_updated
WHEN NOT MATCHED THEN
  INSERT (player_id, player_name, country_id, last_updated)
  VALUES (S.player_id, S.player_name, S.country_id, S.last_updated);
