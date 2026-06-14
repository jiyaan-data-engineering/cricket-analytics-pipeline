-- ============================================================================
-- Author: Satish Mudde
-- Created: 2026-06-07
-- File: vw_ranking_comparison_cross_format.sql
-- ============================================================================
-- Purpose: Create CURATED layer - View: Ranking Comparison Across Formats
-- Cross-format comparison showing each player's rank in all three formats (TEST, ODI, T20I)
-- Format: One row per player with columns for each format's rank and rating
-- Note: Dataset names are placeholders - substitute {STAGING_DATASET} and {CURATED_DATASET} with actual names from config
-- ============================================================================

CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_ranking_comparison_cross_format` AS
SELECT
  p.player_name,
  c.country_name,
  MAX(CASE WHEN f.format_id = 1 THEN fb.rank END) as test_rank,
  MAX(CASE WHEN f.format_id = 1 THEN fb.rating END) as test_rating,
  MAX(CASE WHEN f.format_id = 2 THEN fb.rank END) as odi_rank,
  MAX(CASE WHEN f.format_id = 2 THEN fb.rating END) as odi_rating,
  MAX(CASE WHEN f.format_id = 3 THEN fb.rank END) as t20i_rank,
  MAX(CASE WHEN f.format_id = 3 THEN fb.rating END) as t20i_rating,
  MAX(fb.loaded_at) as last_updated
FROM `{PROJECT_ID}.{STAGING_DATASET}.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_format` f ON fb.format_id = f.format_id
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
GROUP BY p.player_name, c.country_name
ORDER BY 1;
