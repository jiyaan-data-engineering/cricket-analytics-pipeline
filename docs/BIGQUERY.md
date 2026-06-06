# 📊 BigQuery: Data Warehouse Guide

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete 12-Object Data Warehouse

Complete consolidated documentation for all BigQuery configurations.

---

## 📋 Quick Navigation

- [Overview](#overview)
- [Medallion Architecture](#medallion-architecture)
- [12 Objects (6 Tables + 6 Views)](#12-objects)
- [Schemas](#schemas)
- [SQL Files](#sql-files)
- [Configuration](#configuration)
- [Queries](#queries)

---

## 📊 Overview

| Layer | Tables | Views | Purpose |
|-------|--------|-------|---------|
| **RAW** | 1 | 1 | Exact API copy (90-day retention) |
| **STAGING** | 5 | 0 | Star schema (SCD Type 1) |
| **CURATED** | 0 | 5 | Pre-joined analytics views |
| **TOTAL** | 6 | 6 | 12 objects, 68 columns |

---

## 🏗️ Medallion Architecture

```
┌─────────────────────────────────────────┐
│ RAW LAYER (cricket_raw)                 │
├─────────────────────────────────────────┤
│ ✓ batting_rankings (1 table)            │
│   - 11 columns: rank, player_id, ...    │
│   - Partitioned: DATE(ingested_at)      │
│   - Clustered: format, country          │
│   - 90-day expiration                   │
│                                          │
│ ✓ vw_latest_raw (1 view)                │
│   - Debug view: latest 100/format/day   │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ STAGING LAYER (cricket_staging)         │
├─────────────────────────────────────────┤
│ DIMENSIONS (4 tables):                   │
│ ✓ dim_player (4 cols) - SCD Type 1      │
│ ✓ dim_country (4 cols) - ICC codes      │
│ ✓ dim_format (3 cols) - Static lookup   │
│ ✓ dim_date (10 cols) - Date spine       │
│                                          │
│ FACT (1 table):                         │
│ ✓ fact_batting_rankings (11 cols)       │
│   - Daily snapshot per player/format    │
│   - Composite key: YYYYMMDD-id-format   │
│   - Partitioned: DATE(loaded_at)        │
│   - Clustered: format_id, country_id    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ CURATED LAYER (cricket_curated)         │
├─────────────────────────────────────────┤
│ VIEWS (5 views):                        │
│ 1. vw_batting_rankings_latest           │
│    - Current rankings (all players)     │
│    - 9 columns                          │
│                                          │
│ 2. vw_batting_rankings_90day_trend      │
│    - Historical progression (90 days)   │
│    - With rank deltas (LAG window)      │
│    - 8 columns                          │
│                                          │
│ 3. vw_top_10_batsmen_by_format          │
│    - Top 10 per format                  │
│    - 9 columns                          │
│                                          │
│ 4. vw_batting_statistics_by_country     │
│    - Aggregated by country              │
│    - Avg/min/max ratings                │
│    - 8 columns                          │
│                                          │
│ 5. vw_ranking_comparison_cross_format   │
│    - One row per player                 │
│    - TEST vs ODI vs T20I ranks          │
│    - 9 columns (pivoted)                │
└─────────────────────────────────────────┘
```

---

## 🎯 12 Objects

### RAW LAYER

**Table 1: batting_rankings**
```
Columns (11):
- rank (INT64) - Player ranking
- player_id (STRING) - Unique identifier
- player_name (STRING)
- country (STRING)
- country_id (STRING)
- rating (FLOAT64) - ICC rating
- points (FLOAT64)
- best_rank (INT64)
- format (STRING) - TEST, ODI, T20I
- ingested_at (TIMESTAMP) - UTC load time
- source_file (STRING) - CSV filename

Partitioning: DATE(ingested_at)
Clustering: format, country
Expiration: 90 days
```

**View 1: vw_latest_raw**
```
Purpose: Debug view - latest 100 records per format per day
Columns (8): rank, player_id, player_name, country, rating, format, ingestion_date, rn
Logic: ROW_NUMBER() OVER (PARTITION BY format, DATE(ingested_at))
```

### STAGING LAYER - DIMENSIONS

**Table 2: dim_player**
```
Columns (4):
- player_id (STRING, PK) - Unique player
- player_name (STRING)
- country_id (STRING) - FK to dim_country
- last_updated (TIMESTAMP)

Update: MERGE (SCD Type 1) - overwrites on update
Partitioning: DATE(last_updated)
```

**Table 3: dim_country**
```
Columns (4):
- country_id (STRING, PK)
- country_name (STRING)
- icc_code (STRING) - 3-letter code (IND, AUS, PAK, etc.)
- last_updated (TIMESTAMP)

ICC Codes: IND, AUS, PAK, ENG, RSA, WI, NZ, SL, BAN, AFG, UNK
Update: MERGE with CASE logic for ICC code mapping
```

**Table 4: dim_format**
```
Columns (3):
- format_id (INT64, PK) - 1, 2, 3
- format_name (STRING) - TEST, ODI, T20I
- description (STRING)

Static Values: Only 3 rows, inserted once
```

**Table 5: dim_date**
```
Columns (10):
- date_id (INT64, PK) - YYYYMMDD format
- full_date (DATE)
- year (INT64)
- quarter (INT64) - 1-4
- month (INT64) - 1-12
- day (INT64) - 1-31
- week (INT64)
- day_of_week (INT64) - 1-7
- day_name (STRING) - Monday, Tuesday, ...
- month_name (STRING) - January, February, ...

Span: 2015-01-01 to 2034-12-31 (7305 rows)
Generation: GENERATE_ARRAY + date functions
```

### STAGING LAYER - FACT

**Table 6: fact_batting_rankings**
```
Columns (11):
- fact_id (STRING, PK) - YYYYMMDD-player_id-format_id
- date_id (INT64, FK)
- player_id (STRING, FK)
- format_id (INT64, FK)
- country_id (STRING, FK)
- rank (INT64)
- rating (FLOAT64)
- points (FLOAT64)
- best_rank (INT64)
- source_file (STRING)
- loaded_at (TIMESTAMP)

Composite Key: Ensures 1 record per player per format per day
Partitioning: DATE(loaded_at)
Clustering: format_id, country_id
Update: MERGE (UPSERT) - idempotent

Star Schema:
  fact_batting_rankings ────┬─ dim_player
                            ├─ dim_country
                            ├─ dim_format
                            └─ dim_date
```

### CURATED LAYER - VIEWS

**View 2: vw_batting_rankings_latest**
```
Purpose: Current rankings for all players, all formats
Columns (9): player_name, country_name, format_name, format_id, 
             current_rank, current_rating, current_points, best_rank, last_updated
Logic: Joins fact → dim_player/country/format, WHERE DATE(loaded_at) = TODAY
Aggregation: MAX() on rank/rating/loaded_at, GROUP BY player+country+format
```

**View 3: vw_batting_rankings_90day_trend**
```
Purpose: Historical ranking progression with trend deltas
Columns (8): player_name, country_name, format_name, full_date, rank, rating, 
             previous_rank, rank_change
Window Function: LAG(rank) OVER (PARTITION BY player_id, format_id ORDER BY full_date)
Calculation: rank_change = rank - LAG(rank)
Time Range: Last 90 days
```

**View 4: vw_top_10_batsmen_by_format**
```
Purpose: Top 10 ranked batsmen per format
Columns (9): rank_position, player_name, country_name, format_name, 
             current_rank, current_rating, current_points, best_rank, last_updated
Source: vw_batting_rankings_latest (view dependency)
Filter: WHERE current_rank <= 10
Ranking: ROW_NUMBER() OVER (PARTITION BY format_id ORDER BY current_rank)
```

**View 5: vw_batting_statistics_by_country**
```
Purpose: Aggregated stats per country and format
Columns (8): country_name, format_name, players_in_top50, players_in_top10,
             avg_rating, min_rating, max_rating, last_updated
Aggregations: COUNT(DISTINCT player_id), COUNT with CASE, AVG/MIN/MAX
Filter: rank <= 50, DATE(loaded_at) = TODAY
Group By: country_name, format_name
```

**View 6: vw_ranking_comparison_cross_format**
```
Purpose: Cross-format comparison - one row per player
Columns (9): player_name, country_name, test_rank, test_rating,
             odi_rank, odi_rating, t20i_rank, t20i_rating, last_updated
Pivot Logic: MAX(CASE WHEN format_id = 1 THEN rank END) as test_rank
Filter: DATE(loaded_at) = TODAY
Group By: player_name, country_name
Result: Same player with all 3 format rankings in one row
```

---

## 📋 Schemas (12 JSON Files)

Each SQL file has a corresponding schema file in `bigquery/schemas/`:

```
raw_batting_rankings.json       (11 fields)
vw_latest_raw.json              (8 fields)
dim_player.json                 (4 fields)
dim_country.json                (4 fields)
dim_format.json                 (3 fields)
dim_date.json                   (10 fields)
fact_batting_rankings.json       (11 fields)
vw_batting_rankings_latest.json (9 fields)
vw_batting_rankings_90day_trend.json (8 fields)
vw_top_10_batsmen_by_format.json (9 fields)
vw_batting_statistics_by_country.json (8 fields)
vw_ranking_comparison_cross_format.json (9 fields)
```

**Schema Format**:
```json
[
  {
    "name": "column_name",
    "type": "INTEGER|STRING|FLOAT64|DATE|TIMESTAMP",
    "mode": "REQUIRED|NULLABLE",
    "description": "What this column contains"
  }
]
```

---

## 📁 SQL Files (12 Files)

All in `bigquery/sql/`:

```
1. raw_batting_rankings.sql         - CREATE TABLE (11 cols)
2. vw_latest_raw.sql                - CREATE VIEW (8 cols)
3. dim_player.sql                   - CREATE TABLE with MERGE
4. dim_country.sql                  - CREATE TABLE with ICC mapping
5. dim_format.sql                   - CREATE TABLE (static)
6. dim_date.sql                     - CREATE TABLE (date spine)
7. fact_batting_rankings.sql        - CREATE TABLE with MERGE
8. vw_batting_rankings_latest.sql   - CREATE VIEW (joins)
9. vw_batting_rankings_90day_trend.sql - CREATE VIEW (LAG window)
10. vw_top_10_batsmen_by_format.sql - CREATE VIEW (ranking)
11. vw_batting_statistics_by_country.sql - CREATE VIEW (aggregation)
12. vw_ranking_comparison_cross_format.sql - CREATE VIEW (pivot)
```

**Placeholders in All Files**:
```sql
{PROJECT_ID}       - Your GCP project ID
{RAW_DATASET}      - cricket_raw
{STAGING_DATASET}  - cricket_staging
{CURATED_DATASET}  - cricket_curated
```

---

## ⚙️ Configuration

### Terraform (terraform/bigquery.tf)

```hcl
# 3 Datasets
resource "google_bigquery_dataset" "raw" {
  dataset_id = var.bq_raw_dataset  # cricket_raw
  default_table_expiration_ms = 7776000000  # 90 days
}

# 6 Tables
resource "google_bigquery_table" "raw_batting_rankings" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = var.bq_raw_table_name
  schema     = file("${path.module}/../bigquery/schemas/raw_batting_rankings.json")
}

# 6 Views (via SQL)
resource "google_bigquery_routine" "vw_batting_rankings_latest" {
  routine_id = "vw_batting_rankings_latest"
  definition_body = replace(
    file("${path.module}/../bigquery/sql/vw_batting_rankings_latest.sql"),
    "{PROJECT_ID}", var.gcp_project_id
  )
}
```

### Variables (terraform/variables.tf)

```hcl
variable "bq_raw_dataset" { default = "cricket_raw" }
variable "bq_staging_dataset" { default = "cricket_staging" }
variable "bq_curated_dataset" { default = "cricket_curated" }
variable "bq_raw_table_name" { default = "batting_rankings" }
# ... all 12 object names
```

---

## 🔍 Queries

### View Current Rankings

```sql
SELECT player_name, country_name, format_name, current_rank, current_rating
FROM `PROJECT_ID.cricket_curated.vw_batting_rankings_latest`
WHERE format_id = 1  -- TEST
ORDER BY current_rank
LIMIT 20;
```

### 90-Day Trend

```sql
SELECT player_name, format_name, full_date, rank, rank_change
FROM `PROJECT_ID.cricket_curated.vw_batting_rankings_90day_trend`
WHERE player_name = 'Virat Kohli'
ORDER BY full_date DESC;
```

### Top 10 per Format

```sql
SELECT *
FROM `PROJECT_ID.cricket_curated.vw_top_10_batsmen_by_format`
ORDER BY format_name, rank_position;
```

### Cross-Format Comparison

```sql
SELECT player_name, country_name, test_rank, odi_rank, t20i_rank
FROM `PROJECT_ID.cricket_curated.vw_ranking_comparison_cross_format`
WHERE test_rank IS NOT NULL AND odi_rank IS NOT NULL AND t20i_rank IS NOT NULL
ORDER BY test_rank
LIMIT 10;
```

---

## 📊 Column Reference (68 Total)

### By Table/View:
- raw_batting_rankings: 11
- dim_player: 4
- dim_country: 4
- dim_format: 3
- dim_date: 10
- fact_batting_rankings: 11
- vw_batting_rankings_latest: 9
- vw_batting_rankings_90day_trend: 8
- vw_top_10_batsmen_by_format: 9
- vw_batting_statistics_by_country: 8
- vw_ranking_comparison_cross_format: 9

Total: **68 columns** fully documented

---

## 📚 Related Documentation

- [SQL_DEVELOPER_GUIDE.md](../SQL_DEVELOPER_GUIDE.md) - Detailed SQL guide
- [SCHEMA_VALIDATION.md](./SCHEMA_VALIDATION.md) - Schema drift handling
- [TERRAFORM.md](./TERRAFORM.md) - Infrastructure setup

---

**Status**: ✅ Complete BigQuery Data Warehouse  
**Objects**: 12 (6 tables + 6 views)  
**Columns**: 68 (all documented)  
**Last Updated**: 2026-06-07  

Production-ready analytics platform! 📊
