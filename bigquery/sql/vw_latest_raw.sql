-- Create RAW layer view for latest raw records
-- Purpose: Debug view showing latest 100 records per format per day
-- Note: Dataset names are placeholders - substitute {RAW_DATASET} with actual dataset name from config

CREATE OR REPLACE VIEW `{PROJECT_ID}.{RAW_DATASET}.vw_latest_raw` AS
SELECT
  rank,
  player_id,
  player_name,
  country,
  rating,
  format,
  DATE(ingested_at) as ingestion_date,
  ROW_NUMBER() OVER (PARTITION BY format, DATE(ingested_at) ORDER BY ingested_at DESC) as rn
FROM `{PROJECT_ID}.{RAW_DATASET}.batting_rankings`
WHERE rn <= 100;
