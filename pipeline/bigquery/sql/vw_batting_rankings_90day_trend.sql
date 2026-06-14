-- ============================================================================
-- Author: Satish Mudde
-- Created: 2026-06-07
-- File: vw_batting_rankings_90day_trend.sql
-- ============================================================================
-- Purpose: Create CURATED layer - View: 90-Day Batting Ranking Trend
-- Shows historical ranking progression over last 90 days with rank changes
-- Note: Dataset names are placeholders - substitute {STAGING_DATASET} and {CURATED_DATASET} with actual names from config
-- ============================================================================

CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_90day_trend` AS
SELECT
  p.player_name,
  c.country_name,
  f.format_name,
  d.full_date,
  fb.rank,
  fb.rating,
  LAG(fb.rank) OVER (
    PARTITION BY p.player_id, f.format_id
    ORDER BY d.full_date
  ) as previous_rank,
  fb.rank - LAG(fb.rank) OVER (
    PARTITION BY p.player_id, f.format_id
    ORDER BY d.full_date
  ) as rank_change
FROM `{PROJECT_ID}.{STAGING_DATASET}.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_format` f ON fb.format_id = f.format_id
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_date` d ON fb.date_id = d.date_id
WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
ORDER BY 1, 3, 4;
