-- Create CURATED layer - Views for analytics and dashboards

-- View 1: Current Rankings (Latest snapshot per player+format)
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_current_rankings` AS
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
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_format` f ON fb.format_id = f.format_id
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
GROUP BY p.player_name, c.country_name, f.format_name, f.format_id
ORDER BY f.format_id, current_rank;

-- View 2: Ranking Trend (Historical progression for sparklines)
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_ranking_trend` AS
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
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_format` f ON fb.format_id = f.format_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_date` d ON fb.date_id = d.date_id
WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
ORDER BY p.player_name, f.format_id, d.full_date;

-- View 3: Top 10 Players per Format
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_top10_by_format` AS
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
FROM `{PROJECT_ID}.cricket_curated.vw_current_rankings`
WHERE current_rank <= 10
ORDER BY format_name, rank_position;

-- View 4: Country Summary Statistics
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_country_summary` AS
SELECT
  c.country_name,
  f.format_name,
  COUNT(DISTINCT p.player_id) as players_in_top50,
  COUNT(DISTINCT CASE WHEN fb.rank <= 10 THEN p.player_id END) as players_in_top10,
  ROUND(AVG(fb.rating), 2) as avg_rating,
  ROUND(MIN(fb.rating), 2) as min_rating,
  ROUND(MAX(fb.rating), 2) as max_rating,
  MAX(fb.loaded_at) as last_updated
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_format` f ON fb.format_id = f.format_id
WHERE fb.rank <= 50 AND DATE(fb.loaded_at) = CURRENT_DATE()
GROUP BY c.country_name, f.format_name
ORDER BY c.country_name, f.format_id;

-- View 5: Format Comparison - Same Player Across All Formats
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_player_format_comparison` AS
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
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` fb
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_player` p ON fb.player_id = p.player_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_country` c ON fb.country_id = c.country_id
INNER JOIN `{PROJECT_ID}.cricket_staging.dim_format` f ON fb.format_id = f.format_id
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
GROUP BY p.player_name, c.country_name
ORDER BY p.player_name;
