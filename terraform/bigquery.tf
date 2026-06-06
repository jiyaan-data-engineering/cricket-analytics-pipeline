# ============================================================================
# BigQuery Resources - Cricket Analytics Pipeline
# 3 Datasets + 6 Tables + 6 Views = 12 Total Objects
# ============================================================================
#
# IMPORTANT: This file references existing SQL scripts and schema files.
# NO SQL queries or schemas are hardcoded here - they're sourced from:
#   - bigquery/schemas/*.json (all 12 schema definitions)
#   - bigquery/sql/*.sql (all 12 SQL scripts - tables and views)
#
# Architecture:
# ├─ Terraform creates the BigQuery structure (datasets & table placeholders)
# ├─ SQL scripts define actual schemas and views
# ├─ Schema files document all column definitions
# ├─ Single source of truth for all SQL logic (in .sql files)
# └─ Easy to maintain - change once, apply everywhere
#
# Objects (12 Total):
# Raw Layer:     1 table + 1 view
# Staging Layer: 5 tables
# Curated Layer: 5 views
#
# Workflow:
# 1. terraform apply (creates 3 datasets + 6 table placeholders)
# 2. Execute all SQL scripts from bigquery/sql/:
#    - raw_batting_rankings.sql (create raw table)
#    - vw_latest_raw.sql (create raw view)
#    - dim_*.sql (create 5 staging dimensions)
#    - fact_batting_rankings.sql (create staging fact)
#    - vw_*.sql (create 5 curated views)
#
# ============================================================================

# ============================================================================
# RAW LAYER - Exact copy from API
# ============================================================================

# Raw Table: batting_rankings
# SQL: bigquery/sql/raw_batting_rankings.sql
# Schema: bigquery/schemas/raw_batting_rankings.json
# Table name configurable via var.bq_raw_table_batting_rankings (from config/config.yaml)
resource "google_bigquery_table" "raw_batting_rankings" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = var.bq_raw_table_batting_rankings

  description = "Raw ICC Men's Batting Rankings - Exact copy from Cricbuzz API"
  labels      = var.labels

  # Partitioning and Clustering
  time_partitioning {
    type  = "DAY"
    field = "ingested_at"
    expiration_ms = var.bq_table_expiration_days * 24 * 60 * 60 * 1000
  }

  clustering = var.bq_raw_clustering_fields

  # Load schema from existing JSON file (single source of truth)
  schema = file("${path.module}/../bigquery/schemas/raw_batting_rankings.json")

  depends_on = [google_bigquery_dataset.raw]
}

# Raw View: vw_latest_raw (Latest 100 records per format)
# SQL: bigquery/sql/vw_latest_raw.sql
# Schema: bigquery/schemas/vw_latest_raw.json
# View name configurable via var.bq_raw_view_latest_raw (from config/config.yaml)
resource "google_bigquery_routine" "raw_vw_latest_raw" {
  dataset_id      = google_bigquery_dataset.raw.dataset_id
  routine_id      = var.bq_raw_view_latest_raw
  routine_type    = "VIEW"
  language        = "SQL"

  # Use replace() to substitute {PROJECT_ID}, {RAW_DATASET}, etc. from SQL file with actual values
  # Gets dataset names from config/config.yaml via variables
  definition_body = replace(
    replace(
      replace(
        file("${path.module}/../bigquery/sql/vw_latest_raw.sql"),
        "{PROJECT_ID}",
        var.gcp_project_id
      ),
      "{RAW_DATASET}",
      var.bq_raw_dataset
    ),
    "{STAGING_DATASET}",
    var.bq_staging_dataset
  )

  depends_on = [google_bigquery_table.raw_batting_rankings]
}

# ============================================================================
# STAGING LAYER - Star Schema with SCD Type 1
# Note: Tables are created via SQL scripts (bigquery/sql/*.sql)
# Terraform creates the datasets only - schemas managed in SQL files
# ============================================================================

# Dimension Table: dim_player
# SQL: bigquery/sql/dim_player.sql
# Schema: bigquery/schemas/dim_player.json
# Table name configurable via var.bq_staging_table_dim_player (from config/config.yaml)
resource "google_bigquery_table" "staging_dim_player" {
  dataset_id = google_bigquery_dataset.staging.dataset_id
  table_id   = var.bq_staging_table_dim_player

  description = "Player dimension - SCD Type 1 (current attributes only)"
  labels      = var.labels

  time_partitioning {
    type  = "DAY"
    field = "last_updated"
  }

  # Load schema from separate JSON file (single source of truth)
  schema = file("${path.module}/../bigquery/schemas/dim_player.json")

  depends_on = [google_bigquery_dataset.staging]
}

# Dimension Table: dim_country
# SQL: bigquery/sql/dim_country.sql
# Schema: bigquery/schemas/dim_country.json
# Table name configurable via var.bq_staging_table_dim_country (from config/config.yaml)
resource "google_bigquery_table" "staging_dim_country" {
  dataset_id = google_bigquery_dataset.staging.dataset_id
  table_id   = var.bq_staging_table_dim_country

  description = "Country dimension with ICC codes"
  labels      = var.labels

  # Load schema from separate JSON file (single source of truth)
  schema = file("${path.module}/../bigquery/schemas/dim_country.json")

  depends_on = [google_bigquery_dataset.staging]
}

# Dimension Table: dim_format
# SQL: bigquery/sql/dim_format.sql
# Schema: bigquery/schemas/dim_format.json
# Table name configurable via var.bq_staging_table_dim_format (from config/config.yaml)
resource "google_bigquery_table" "staging_dim_format" {
  dataset_id = google_bigquery_dataset.staging.dataset_id
  table_id   = var.bq_staging_table_dim_format

  description = "Format dimension - Static lookup (TEST=1, ODI=2, T20I=3)"
  labels      = var.labels

  # Load schema from separate JSON file (single source of truth)
  schema = file("${path.module}/../bigquery/schemas/dim_format.json")

  depends_on = [google_bigquery_dataset.staging]
}

# Dimension Table: dim_date (Date Spine 2015-2035)
# SQL: bigquery/sql/dim_date.sql
# Schema: bigquery/schemas/dim_date.json
# Table name configurable via var.bq_staging_table_dim_date (from config/config.yaml)
resource "google_bigquery_table" "staging_dim_date" {
  dataset_id = google_bigquery_dataset.staging.dataset_id
  table_id   = var.bq_staging_table_dim_date

  description = "Date dimension - 7305 rows (2015-01-01 to 2034-12-31)"
  labels      = var.labels

  # Load schema from separate JSON file (single source of truth)
  schema = file("${path.module}/../bigquery/schemas/dim_date.json")

  depends_on = [google_bigquery_dataset.staging]
}

# Fact Table: fact_batting_rankings (Daily Snapshot)
# SQL: bigquery/sql/fact_batting_rankings.sql
# Schema: bigquery/schemas/fact_batting_rankings.json
# Table name configurable via var.bq_staging_table_fact_batting (from config/config.yaml)
resource "google_bigquery_table" "staging_fact_batting" {
  dataset_id = google_bigquery_dataset.staging.dataset_id
  table_id   = var.bq_staging_table_fact_batting

  description = "Fact table - Daily snapshot of batting rankings (Composite Key: YYYYMMDD-player_id-format_id)"
  labels      = var.labels

  time_partitioning {
    type  = "DAY"
    field = "loaded_at"
  }

  clustering = var.bq_fact_clustering_fields

  # Load schema from separate JSON file (single source of truth)
  schema = file("${path.module}/../bigquery/schemas/fact_batting_rankings.json")

  depends_on = [google_bigquery_dataset.staging]
}

# ============================================================================
# CURATED LAYER - Analytics Views (5 Separate Views)
# Each view has its own SQL file with meaningful name
# ============================================================================

# View 1: vw_batting_rankings_latest
# SQL: bigquery/sql/vw_batting_rankings_latest.sql
# Schema: bigquery/schemas/vw_batting_rankings_latest.json
# Purpose: Shows current (today's) batting rankings for all players
resource "google_bigquery_routine" "curated_vw_batting_rankings_latest" {
  dataset_id      = google_bigquery_dataset.curated.dataset_id
  routine_id      = var.bq_curated_view_batting_rankings_latest
  routine_type    = "VIEW"
  language        = "SQL"
  description     = "Latest batting rankings - Today's snapshot for all players and formats"

  definition_body = replace(
    replace(
      replace(
        replace(
          file("${path.module}/../bigquery/sql/vw_batting_rankings_latest.sql"),
          "{PROJECT_ID}",
          var.gcp_project_id
        ),
        "{STAGING_DATASET}",
        var.bq_staging_dataset
      ),
      "{CURATED_DATASET}",
      var.bq_curated_dataset
    ),
    "{RAW_DATASET}",
    var.bq_raw_dataset
  )

  depends_on = [
    google_bigquery_table.staging_dim_player,
    google_bigquery_table.staging_dim_country,
    google_bigquery_table.staging_dim_format,
    google_bigquery_table.staging_fact_batting
  ]
}

# View 2: vw_batting_rankings_90day_trend
# SQL: bigquery/sql/vw_batting_rankings_90day_trend.sql
# Schema: bigquery/schemas/vw_batting_rankings_90day_trend.json
# Purpose: Shows 90-day ranking progression with rank changes
resource "google_bigquery_routine" "curated_vw_batting_rankings_90day_trend" {
  dataset_id      = google_bigquery_dataset.curated.dataset_id
  routine_id      = var.bq_curated_view_batting_rankings_90day_trend
  routine_type    = "VIEW"
  language        = "SQL"
  description     = "90-day ranking trend - Historical progression with rank deltas"

  definition_body = replace(
    replace(
      replace(
        replace(
          file("${path.module}/../bigquery/sql/vw_batting_rankings_90day_trend.sql"),
          "{PROJECT_ID}",
          var.gcp_project_id
        ),
        "{STAGING_DATASET}",
        var.bq_staging_dataset
      ),
      "{CURATED_DATASET}",
      var.bq_curated_dataset
    ),
    "{RAW_DATASET}",
    var.bq_raw_dataset
  )

  depends_on = [
    google_bigquery_table.staging_dim_player,
    google_bigquery_table.staging_dim_country,
    google_bigquery_table.staging_dim_format,
    google_bigquery_table.staging_dim_date,
    google_bigquery_table.staging_fact_batting
  ]
}

# View 3: vw_top_10_batsmen_by_format
# SQL: bigquery/sql/vw_top_10_batsmen_by_format.sql
# Schema: bigquery/schemas/vw_top_10_batsmen_by_format.json
# Purpose: Shows top 10 ranked batsmen per cricket format
resource "google_bigquery_routine" "curated_vw_top_10_batsmen_by_format" {
  dataset_id      = google_bigquery_dataset.curated.dataset_id
  routine_id      = var.bq_curated_view_top_10_batsmen_by_format
  routine_type    = "VIEW"
  language        = "SQL"
  description     = "Top 10 batsmen by format - Top 10 ranked players per format"

  definition_body = replace(
    replace(
      replace(
        replace(
          file("${path.module}/../bigquery/sql/vw_top_10_batsmen_by_format.sql"),
          "{PROJECT_ID}",
          var.gcp_project_id
        ),
        "{STAGING_DATASET}",
        var.bq_staging_dataset
      ),
      "{CURATED_DATASET}",
      var.bq_curated_dataset
    ),
    "{RAW_DATASET}",
    var.bq_raw_dataset
  )

  depends_on = [google_bigquery_routine.curated_vw_batting_rankings_latest]
}

# View 4: vw_batting_statistics_by_country
# SQL: bigquery/sql/vw_batting_statistics_by_country.sql
# Schema: bigquery/schemas/vw_batting_statistics_by_country.json
# Purpose: Aggregated batting statistics per country and format
resource "google_bigquery_routine" "curated_vw_batting_statistics_by_country" {
  dataset_id      = google_bigquery_dataset.curated.dataset_id
  routine_id      = var.bq_curated_view_batting_statistics_by_country
  routine_type    = "VIEW"
  language        = "SQL"
  description     = "Batting statistics by country - Aggregated metrics per country and format"

  definition_body = replace(
    replace(
      replace(
        replace(
          file("${path.module}/../bigquery/sql/vw_batting_statistics_by_country.sql"),
          "{PROJECT_ID}",
          var.gcp_project_id
        ),
        "{STAGING_DATASET}",
        var.bq_staging_dataset
      ),
      "{CURATED_DATASET}",
      var.bq_curated_dataset
    ),
    "{RAW_DATASET}",
    var.bq_raw_dataset
  )

  depends_on = [
    google_bigquery_table.staging_dim_player,
    google_bigquery_table.staging_dim_country,
    google_bigquery_table.staging_dim_format,
    google_bigquery_table.staging_fact_batting
  ]
}

# View 5: vw_ranking_comparison_cross_format
# SQL: bigquery/sql/vw_ranking_comparison_cross_format.sql
# Schema: bigquery/schemas/vw_ranking_comparison_cross_format.json
# Purpose: Cross-format comparison showing each player's rank in all formats
resource "google_bigquery_routine" "curated_vw_ranking_comparison_cross_format" {
  dataset_id      = google_bigquery_dataset.curated.dataset_id
  routine_id      = var.bq_curated_view_ranking_comparison_cross_format
  routine_type    = "VIEW"
  language        = "SQL"
  description     = "Cross-format ranking comparison - Each player's rank across all formats"

  definition_body = replace(
    replace(
      replace(
        replace(
          file("${path.module}/../bigquery/sql/vw_ranking_comparison_cross_format.sql"),
          "{PROJECT_ID}",
          var.gcp_project_id
        ),
        "{STAGING_DATASET}",
        var.bq_staging_dataset
      ),
      "{CURATED_DATASET}",
      var.bq_curated_dataset
    ),
    "{RAW_DATASET}",
    var.bq_raw_dataset
  )

  depends_on = [
    google_bigquery_table.staging_dim_player,
    google_bigquery_table.staging_dim_country,
    google_bigquery_table.staging_dim_format,
    google_bigquery_table.staging_fact_batting
  ]
}
