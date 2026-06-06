-- ============================================================================
-- Author: Satish Mudde
-- Created: 2026-06-07
-- File: vw_batting_statistics_by_country.sql
-- ============================================================================
-- Purpose: Create CURATED layer - View: Batting Statistics by Country
-- Aggregated batting statistics for each country and format
-- Includes: player counts, average ratings, and top player metrics
-- Note: Dataset names are placeholders - substitute {STAGING_DATASET} and {CURATED_DATASET} with actual names from config
-- ============================================================================

CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_statistics_by_country` AS
SELECT
  c.country_name,
  f.format_name,
  COUNT(DISTINCT p.player_id) as players_in_top50,
  COUNT(DISTINCT CASE WHEN fb.rank <= 10 THEN p.player_id END) as players_in_top10,
  ROUND(AVG(fb.rating), 2) as avg_rating,
  ROUND(MIN(fb.rating), 2) as min_rating,
  ROUND(MAX(fb.rating), 2) as max_rating,
  MAX(fb.loaded_at) as last_updated
FROM `{PROJECT_ID}.{STAGING_DATASET}.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_format` f ON fb.format_id = f.format_id
WHERE fb.rank <= 50 AND DATE(fb.loaded_at) = CURRENT_DATE()
GROUP BY c.country_name, f.format_name
ORDER BY c.country_name, f.format_id;
