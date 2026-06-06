-- Create CURATED layer - View: Top 10 Batsmen by Format
-- Purpose: Shows the top 10 ranked batsmen for each cricket format
-- Note: Dataset names are placeholders - substitute {STAGING_DATASET} and {CURATED_DATASET} with actual names from config

CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_top_10_batsmen_by_format` AS
SELECT
  ROW_NUMBER() OVER (PARTITION BY format_id ORDER BY current_rank) as rank_position,
  player_name,
  country_name,
  format_name,
  current_rank,
  current_rating,
  current_points,
  best_rank,
  last_updated
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_latest`
WHERE current_rank <= 10
ORDER BY format_name, rank_position;
