-- Create CURATED layer - View: Latest Batting Rankings
-- Purpose: Shows current (today's) batting rankings for all players and formats
-- Note: Dataset names are placeholders - substitute {STAGING_DATASET} and {CURATED_DATASET} with actual names from config

CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_latest` AS
SELECT
  p.player_name,
  c.country_name,
  f.format_name,
  f.format_id,
  MAX(fb.rank) as current_rank,
  MAX(fb.rating) as current_rating,
  MAX(fb.points) as current_points,
  MAX(fb.best_rank) as best_rank,
  MAX(fb.loaded_at) as last_updated
FROM `{PROJECT_ID}.{STAGING_DATASET}.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_format` f ON fb.format_id = f.format_id
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
GROUP BY p.player_name, c.country_name, f.format_name, f.format_id
ORDER BY f.format_id, current_rank;
