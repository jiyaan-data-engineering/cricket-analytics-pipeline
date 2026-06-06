# 📘 SQL Developer Guide - Cricket Analytics Pipeline

**Complete developer documentation for all 12 SQL files**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Raw Layer Files](#raw-layer-files)
3. [Staging Layer Files](#staging-layer-files)
4. [Curated Layer Files](#curated-layer-files)
5. [Configuration & Placeholders](#configuration--placeholders)
6. [Execution Guide](#execution-guide)
7. [Development Best Practices](#development-best-practices)
8. [Troubleshooting](#troubleshooting)

---

## 📊 Overview

### Architecture Layers

```
┌─────────────────────────────────────┐
│         CURATED LAYER (5 Views)     │  Analytics & Dashboard queries
├─────────────────────────────────────┤
│ STAGING LAYER (5 Tables + 1 View)   │  Star Schema & Dimensions
├─────────────────────────────────────┤
│      RAW LAYER (1 Table + 1 View)   │  API Data Copy
└─────────────────────────────────────┘
```

### File Execution Order

```
1. raw_batting_rankings.sql              (Raw table - foundation)
2. vw_latest_raw.sql                     (Raw view - debug)
3. dim_player.sql                        (Dimension 1)
4. dim_country.sql                       (Dimension 2)
5. dim_format.sql                        (Dimension 3)
6. dim_date.sql                          (Dimension 4)
7. fact_batting_rankings.sql             (Fact table - uses all dims)
8. vw_batting_rankings_latest.sql        (Curated view 1)
9. vw_batting_rankings_90day_trend.sql   (Curated view 2)
10. vw_top_10_batsmen_by_format.sql      (Curated view 3)
11. vw_batting_statistics_by_country.sql (Curated view 4)
12. vw_ranking_comparison_cross_format.sql (Curated view 5)
```

---

## 🔴 RAW LAYER FILES

### 1. raw_batting_rankings.sql

**File**: `bigquery/sql/raw_batting_rankings.sql`  
**Schema**: `bigquery/schemas/raw_batting_rankings.json`  
**Type**: TABLE  
**Purpose**: Store exact copy of API data

#### Column Definitions

| Column | Type | Mode | Description |
|--------|------|------|-------------|
| `rank` | INT64 | NULLABLE | Player's current ranking (1-500+) |
| `player_id` | STRING | NULLABLE | Unique player identifier from API |
| `player_name` | STRING | NULLABLE | Player's full name |
| `country` | STRING | NULLABLE | Player's country of representation |
| `country_id` | STRING | NULLABLE | Unique country identifier |
| `rating` | FLOAT64 | NULLABLE | ICC rating/points (0-1000+) |
| `points` | FLOAT64 | NULLABLE | Total rating points |
| `best_rank` | INT64 | NULLABLE | Career best ranking |
| `format` | STRING | NULLABLE | Cricket format (TEST, ODI, T20I) |
| `ingested_at` | TIMESTAMP | NULLABLE | UTC timestamp when record was fetched |
| `source_file` | STRING | NULLABLE | Source CSV filename from GCS |

#### Partitioning & Clustering

```sql
PARTITION BY DATE(ingested_at)        -- Partition by ingestion date
CLUSTER BY format, country             -- Cluster by format and country
```

#### Retention Policy

```
90-day partition expiration
```

#### How to Use

```bash
# Execute this first - it creates the raw table
bq query --use_legacy_sql=false < bigquery/sql/raw_batting_rankings.sql

# Insert data from GCS CSV (via Dataflow)
# Or manually:
bq load --autodetect \
  cricket_raw.batting_rankings \
  gs://your-bucket/batting/batting_rankings_*.csv
```

#### Key Points for Developers

- **Source**: Cricbuzz API (via Cloud Run ingestion)
- **Frequency**: Daily (06:00 UTC)
- **Format**: CSV files in GCS
- **Downstream**: dim_player, dim_country, fact_batting_rankings
- **Quality**: Raw copy - no transformations

#### Example Query

```sql
-- Check latest records
SELECT *
FROM `{PROJECT_ID}.{RAW_DATASET}.batting_rankings`
WHERE DATE(ingested_at) = CURRENT_DATE()
ORDER BY format, rank
LIMIT 10;
```

---

### 2. vw_latest_raw.sql

**File**: `bigquery/sql/vw_latest_raw.sql`  
**Schema**: `bigquery/schemas/vw_latest_raw.json`  
**Type**: VIEW  
**Purpose**: Debug view showing latest 100 records per format per day

#### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `rank` | INTEGER | Player's ranking |
| `player_id` | STRING | Player identifier |
| `player_name` | STRING | Player name |
| `country` | STRING | Player's country |
| `rating` | FLOAT64 | Player's rating |
| `format` | STRING | Cricket format (TEST/ODI/T20I) |
| `ingestion_date` | DATE | Date ingested |
| `rn` | INTEGER | Row number (1-100 per format) |

#### Logic

```sql
ROW_NUMBER() OVER (
  PARTITION BY format, DATE(ingested_at)
  ORDER BY ingested_at DESC
) as rn
```

#### Use Cases

- **Debugging**: Check if API data is flowing correctly
- **Validation**: Verify latest records before processing
- **QA**: Manual data quality checks

#### Example Query

```sql
-- Check top 10 players in TEST format from today
SELECT player_name, country, rating, rank
FROM `{PROJECT_ID}.{RAW_DATASET}.vw_latest_raw`
WHERE format = 'TEST' AND rn <= 10
ORDER BY rank;
```

---

## 🟠 STAGING LAYER FILES

### 3. dim_player.sql

**File**: `bigquery/sql/dim_player.sql`  
**Schema**: `bigquery/schemas/dim_player.json`  
**Type**: TABLE (Dimension - SCD Type 1)  
**Purpose**: Player dimension with current attributes

#### Column Definitions

| Column | Type | Mode | Description |
|--------|------|------|-------------|
| `player_id` | STRING | REQUIRED | Primary key - unique player ID |
| `player_name` | STRING | NULLABLE | Player's current name |
| `country_id` | STRING | NULLABLE | FK to dim_country |
| `last_updated` | TIMESTAMP | REQUIRED | When record was last updated |

#### Primary Key

```sql
PRIMARY KEY (player_id) NOT ENFORCED
```

#### Partitioning

```sql
PARTITION BY DATE(last_updated)
```

#### Update Strategy (SCD Type 1)

- **MERGE** operation (UPSERT)
- On match: Update player_name, country_id, last_updated
- On non-match: Insert new player

#### Development Notes

- **Type 1**: Overwrites old data (no history)
- **Idempotent**: Safe to re-run
- **Frequency**: Daily (after raw data loads)
- **Source**: Distinct players from raw table

#### Example Query

```sql
-- Find all players from India
SELECT player_id, player_name
FROM `{PROJECT_ID}.{STAGING_DATASET}.dim_player` p
INNER JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_country` c
  ON p.country_id = c.country_id
WHERE c.country_name = 'India'
ORDER BY player_name;
```

---

### 4. dim_country.sql

**File**: `bigquery/sql/dim_country.sql`  
**Schema**: `bigquery/schemas/dim_country.json`  
**Type**: TABLE (Dimension)  
**Purpose**: Country mapping with ICC codes

#### Column Definitions

| Column | Type | Mode | Description |
|--------|------|------|-------------|
| `country_id` | STRING | REQUIRED | Primary key - unique country ID |
| `country_name` | STRING | NULLABLE | Full country name |
| `icc_code` | STRING | NULLABLE | 3-letter ICC country code |
| `last_updated` | TIMESTAMP | REQUIRED | When record was last updated |

#### ICC Code Mapping

| Country Name | ICC Code | Notes |
|---|---|---|
| India | IND | |
| Australia | AUS | |
| Pakistan | PAK | |
| England | ENG | |
| South Africa | RSA | |
| West Indies | WI | Regional team |
| New Zealand | NZ | |
| Sri Lanka | SL | |
| Bangladesh | BAN | |
| Afghanistan | AFG | |
| Unknown | UNK | Fallback value |

#### Primary Key

```sql
PRIMARY KEY (country_id) NOT ENFORCED
```

#### Development Notes

- **Static Lookup**: Primarily manual mapping
- **MERGE Logic**: Extracts distinct countries from raw data
- **ICC Codes**: Calculated via CASE statement
- **Idempotent**: Safe to re-run

#### Example Query

```sql
-- Get all ICC codes
SELECT country_name, icc_code
FROM `{PROJECT_ID}.{STAGING_DATASET}.dim_country`
ORDER BY country_name;

-- Find countries with no code
SELECT country_name
FROM `{PROJECT_ID}.{STAGING_DATASET}.dim_country`
WHERE icc_code = 'UNK';
```

---

### 5. dim_format.sql

**File**: `bigquery/sql/dim_format.sql`  
**Schema**: `bigquery/schemas/dim_format.json`  
**Type**: TABLE (Dimension - Static)  
**Purpose**: Cricket format lookup table

#### Column Definitions

| Column | Type | Mode | Description |
|--------|------|------|-------------|
| `format_id` | INT64 | REQUIRED | Primary key (1=TEST, 2=ODI, 3=T20I) |
| `format_name` | STRING | REQUIRED | Format name (TEST, ODI, T20I) |
| `description` | STRING | NULLABLE | Full description |

#### Static Values

```sql
(1, 'TEST', 'Test Cricket'),
(2, 'ODI', 'One Day International'),
(3, 'T20I', 'Twenty20 International')
```

#### Primary Key

```sql
PRIMARY KEY (format_id) NOT ENFORCED
```

#### Development Notes

- **Static Table**: Only 3 rows
- **Idempotent**: Uses INSERT ON CONFLICT DO NOTHING
- **Reference**: Used by all fact queries
- **No Updates**: Format definitions don't change

#### Example Query

```sql
-- Get all formats
SELECT * FROM `{PROJECT_ID}.{STAGING_DATASET}.dim_format`;

-- Join with rankings
SELECT fb.player_id, f.format_name, fb.rank
FROM fact_batting_rankings fb
JOIN dim_format f ON fb.format_id = f.format_id;
```

---

### 6. dim_date.sql

**File**: `bigquery/sql/dim_date.sql`  
**Schema**: `bigquery/schemas/dim_date.json`  
**Type**: TABLE (Dimension - Date Spine)  
**Purpose**: Date spine for time-based analysis

#### Column Definitions

| Column | Type | Mode | Description |
|--------|------|------|-------------|
| `date_id` | INT64 | REQUIRED | Date as YYYYMMDD (primary key) |
| `full_date` | DATE | REQUIRED | Actual date value |
| `year` | INT64 | NULLABLE | Year (e.g., 2026) |
| `quarter` | INT64 | NULLABLE | Quarter (1-4) |
| `month` | INT64 | NULLABLE | Month (1-12) |
| `day` | INT64 | NULLABLE | Day of month (1-31) |
| `week` | INT64 | NULLABLE | Week number of year |
| `day_of_week` | INT64 | NULLABLE | Day of week (1=Sunday, 7=Saturday) |
| `day_name` | STRING | NULLABLE | Day name (Monday, Tuesday, etc.) |
| `month_name` | STRING | NULLABLE | Month name (January, February, etc.) |

#### Date Range

```
2015-01-01 to 2034-12-31 (20 years, 7,305 rows)
```

#### Primary Key

```sql
PRIMARY KEY (date_id) NOT ENFORCED
```

#### Generation Logic

```sql
GENERATE_ARRAY(1, 7305)  -- 20 years of dates
DATE_ADD('2015-01-01', INTERVAL day DAY)
```

#### Development Notes

- **Pre-generated**: All dates pre-loaded
- **Reference**: Used for time-based joins
- **Extensible**: Easy to add more date columns
- **Performant**: Small table, indexed lookups

#### Example Query

```sql
-- Get all dates in Q1 2026
SELECT date_id, full_date, month_name
FROM `{PROJECT_ID}.{STAGING_DATASET}.dim_date`
WHERE year = 2026 AND quarter = 1
ORDER BY full_date;

-- Get day names for all Mondays
SELECT date_id, full_date
FROM `{PROJECT_ID}.{STAGING_DATASET}.dim_date`
WHERE day_name = 'Monday'
LIMIT 10;
```

---

### 7. fact_batting_rankings.sql

**File**: `bigquery/sql/fact_batting_rankings.sql`  
**Schema**: `bigquery/schemas/fact_batting_rankings.json`  
**Type**: TABLE (Fact - Daily Snapshot)  
**Purpose**: Daily snapshot of batting rankings

#### Column Definitions

| Column | Type | Mode | Description |
|--------|------|------|-------------|
| `fact_id` | STRING | REQUIRED | Composite PK: YYYYMMDD-player_id-format_id |
| `player_id` | STRING | REQUIRED | FK to dim_player |
| `country_id` | STRING | NULLABLE | FK to dim_country |
| `format_id` | INT64 | NULLABLE | FK to dim_format (1,2,3) |
| `date_id` | INT64 | NULLABLE | FK to dim_date (YYYYMMDD) |
| `rank` | INT64 | NULLABLE | Ranking on that date |
| `rating` | FLOAT64 | NULLABLE | Rating on that date |
| `points` | FLOAT64 | NULLABLE | Points on that date |
| `best_rank` | INT64 | NULLABLE | Career best rank |
| `source_file` | STRING | NULLABLE | Source CSV filename |
| `loaded_at` | TIMESTAMP | REQUIRED | When record was loaded |

#### Primary Key

```sql
PRIMARY KEY (fact_id) NOT ENFORCED
```

#### Partitioning & Clustering

```sql
PARTITION BY DATE(loaded_at)
CLUSTER BY format_id, country_id
```

#### Composite Key Logic

```sql
fact_id = CONCAT(
  FORMAT_DATE('%Y%m%d', DATE(raw.ingested_at)),
  '-',
  raw.player_id,
  '-',
  CASE raw.format WHEN 'TEST' THEN '1' 
                   WHEN 'ODI' THEN '2' 
                   WHEN 'T20I' THEN '3' END
)
```

#### Update Strategy (MERGE)

```sql
MERGE ... T
ON T.fact_id = S.fact_id AND T.player_id = S.player_id
WHEN MATCHED THEN UPDATE ...
WHEN NOT MATCHED THEN INSERT ...
```

#### Development Notes

- **Granularity**: One record per player per format per day
- **Idempotent**: MERGE prevents duplicates
- **Daily Load**: Runs after raw data is available
- **Dependencies**: Requires dim_player, dim_country, dim_format, dim_date

#### Example Query

```sql
-- Get today's rankings for India in TEST
SELECT p.player_name, fb.rank, fb.rating
FROM `{PROJECT_ID}.{STAGING_DATASET}.fact_batting_rankings` fb
JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_player` p 
  ON fb.player_id = p.player_id
JOIN `{PROJECT_ID}.{STAGING_DATASET}.dim_country` c 
  ON fb.country_id = c.country_id
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
  AND c.country_name = 'India'
  AND fb.format_id = 1  -- TEST
ORDER BY fb.rank;

-- 30-day ranking changes
SELECT p.player_name, 
       fb.rank as latest_rank,
       LAG(fb.rank) OVER (PARTITION BY fb.player_id ORDER BY fb.loaded_at) as previous_rank
FROM fact_batting_rankings fb
JOIN dim_player p ON fb.player_id = p.player_id
WHERE fb.format_id = 1
  AND fb.loaded_at >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
ORDER BY p.player_name, fb.loaded_at;
```

---

## 🟢 CURATED LAYER FILES

### 8. vw_batting_rankings_latest.sql

**File**: `bigquery/sql/vw_batting_rankings_latest.sql`  
**Schema**: `bigquery/schemas/vw_batting_rankings_latest.json`  
**Type**: VIEW  
**Purpose**: Current rankings snapshot for all players

#### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `player_name` | STRING | Player's name |
| `country_name` | STRING | Player's country |
| `format_name` | STRING | Cricket format (TEST/ODI/T20I) |
| `format_id` | INTEGER | Format ID (1/2/3) |
| `current_rank` | INTEGER | Latest rank |
| `current_rating` | FLOAT64 | Latest rating |
| `current_points` | FLOAT64 | Latest points |
| `best_rank` | INTEGER | Career best rank |
| `last_updated` | TIMESTAMP | When updated |

#### Logic

```sql
GROUP BY p.player_name, c.country_name, f.format_name, f.format_id
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
```

#### Joins

```
fact_batting_rankings --< dim_player
                      --< dim_country
                      --< dim_format
```

#### Use Cases

- **Dashboard**: Latest rankings display
- **Analysis**: Current standings
- **Export**: Looker Studio source

#### Example Query

```sql
-- Top 10 in ODI format
SELECT player_name, country_name, current_rank, current_rating
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_latest`
WHERE format_id = 2 AND current_rank <= 10
ORDER BY current_rank;

-- All players from India
SELECT * 
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_latest`
WHERE country_name = 'India'
ORDER BY format_name, current_rank;
```

---

### 9. vw_batting_rankings_90day_trend.sql

**File**: `bigquery/sql/vw_batting_rankings_90day_trend.sql`  
**Schema**: `bigquery/schemas/vw_batting_rankings_90day_trend.json`  
**Type**: VIEW  
**Purpose**: 90-day ranking progression with deltas

#### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `player_name` | STRING | Player's name |
| `country_name` | STRING | Player's country |
| `format_name` | STRING | Cricket format |
| `full_date` | DATE | Date of record |
| `rank` | INTEGER | Rank on this date |
| `rating` | FLOAT64 | Rating on this date |
| `previous_rank` | INTEGER | Rank from previous date (LAG) |
| `rank_change` | INTEGER | Difference (negative = improved) |

#### Window Function

```sql
LAG(fb.rank) OVER (
  PARTITION BY p.player_id, f.format_id
  ORDER BY d.full_date
) as previous_rank
```

#### Time Range

```sql
WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
```

#### Use Cases

- **Trends**: See ranking movements over time
- **Sparklines**: Visual trend data
- **Analysis**: Identify consistent performers
- **Looker**: Line charts and sparklines

#### Example Query

```sql
-- Players improving in TEST (rank decreasing)
SELECT player_name, country_name, full_date, rank, rank_change
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_90day_trend`
WHERE format_id = 1 
  AND rank_change < 0
  AND full_date = CURRENT_DATE()
ORDER BY rank_change
LIMIT 20;

-- Ranking volatility (biggest changes)
SELECT player_name, COUNT(*) as changes,
       AVG(ABS(rank_change)) as avg_change
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_90day_trend`
WHERE rank_change IS NOT NULL
GROUP BY player_name
ORDER BY avg_change DESC
LIMIT 10;
```

---

### 10. vw_top_10_batsmen_by_format.sql

**File**: `bigquery/sql/vw_top_10_batsmen_by_format.sql`  
**Schema**: `bigquery/schemas/vw_top_10_batsmen_by_format.json`  
**Type**: VIEW  
**Purpose**: Top 10 batsmen per cricket format

#### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `rank_position` | INTEGER | Position within format (1-10) |
| `player_name` | STRING | Player's name |
| `country_name` | STRING | Player's country |
| `format_name` | STRING | Cricket format |
| `current_rank` | INTEGER | ICC rank |
| `current_rating` | FLOAT64 | ICC rating |
| `current_points` | FLOAT64 | Total points |
| `best_rank` | INTEGER | Career best |
| `last_updated` | TIMESTAMP | Update timestamp |

#### Logic

```sql
WHERE current_rank <= 10
ROW_NUMBER() OVER (PARTITION BY format_id ORDER BY current_rank) as rank_position
```

#### Dependency

```
Depends on: vw_batting_rankings_latest
```

#### Use Cases

- **Podium Display**: Top players per format
- **Rankings**: Official standings
- **Featured**: Homepage content

#### Example Query

```sql
-- Top 10 in each format with full details
SELECT format_name, rank_position, player_name, country_name, current_rating
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_top_10_batsmen_by_format`
ORDER BY format_name, rank_position;

-- Top player in each format
SELECT DISTINCT format_name, FIRST_VALUE(player_name) OVER (PARTITION BY format_name ORDER BY rank_position) as top_player
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_top_10_batsmen_by_format`;
```

---

### 11. vw_batting_statistics_by_country.sql

**File**: `bigquery/sql/vw_batting_statistics_by_country.sql`  
**Schema**: `bigquery/schemas/vw_batting_statistics_by_country.json`  
**Type**: VIEW  
**Purpose**: Aggregated batting statistics per country

#### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `country_name` | STRING | Country name |
| `format_name` | STRING | Cricket format |
| `players_in_top50` | INTEGER | Count in top 50 |
| `players_in_top10` | INTEGER | Count in top 10 |
| `avg_rating` | FLOAT64 | Average rating (rounded to 2 decimals) |
| `min_rating` | FLOAT64 | Minimum rating in top 50 |
| `max_rating` | FLOAT64 | Maximum rating in top 50 |
| `last_updated` | TIMESTAMP | Update timestamp |

#### Logic

```sql
WHERE fb.rank <= 50 AND DATE(fb.loaded_at) = CURRENT_DATE()
GROUP BY c.country_name, f.format_name
```

#### Aggregations

```sql
COUNT(DISTINCT p.player_id) as players_in_top50
COUNT(DISTINCT CASE WHEN fb.rank <= 10 THEN p.player_id END) as players_in_top10
ROUND(AVG(fb.rating), 2) as avg_rating
ROUND(MIN(fb.rating), 2) as min_rating
ROUND(MAX(fb.rating), 2) as max_rating
```

#### Use Cases

- **Country Comparison**: Strength by nation
- **Analytics**: Depth of talent pool
- **Reports**: Performance metrics by country

#### Example Query

```sql
-- Countries with most top-10 players
SELECT country_name, players_in_top10, avg_rating
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_statistics_by_country`
WHERE format_name = 'TEST'
ORDER BY players_in_top10 DESC;

-- Rating distribution by country
SELECT country_name, format_name, avg_rating, max_rating - min_rating as rating_spread
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_statistics_by_country`
ORDER BY rating_spread DESC;
```

---

### 12. vw_ranking_comparison_cross_format.sql

**File**: `bigquery/sql/vw_ranking_comparison_cross_format.sql`  
**Schema**: `bigquery/schemas/vw_ranking_comparison_cross_format.json`  
**Type**: VIEW  
**Purpose**: Cross-format comparison for same players

#### Column Definitions

| Column | Type | Description |
|--------|------|-------------|
| `player_name` | STRING | Player's name |
| `country_name` | STRING | Player's country |
| `test_rank` | INTEGER | Rank in TEST (format_id=1) |
| `test_rating` | FLOAT64 | Rating in TEST |
| `odi_rank` | INTEGER | Rank in ODI (format_id=2) |
| `odi_rating` | FLOAT64 | Rating in ODI |
| `t20i_rank` | INTEGER | Rank in T20I (format_id=3) |
| `t20i_rating` | FLOAT64 | Rating in T20I |
| `last_updated` | TIMESTAMP | Update timestamp |

#### Pivot Logic

```sql
MAX(CASE WHEN f.format_id = 1 THEN fb.rank END) as test_rank
MAX(CASE WHEN f.format_id = 2 THEN fb.rank END) as odi_rank
MAX(CASE WHEN f.format_id = 3 THEN fb.rank END) as t20i_rank
-- Similar for ratings
```

#### Grouping

```sql
GROUP BY p.player_name, c.country_name
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
```

#### Use Cases

- **Player Profile**: All formats at a glance
- **Format Specialization**: Compare across formats
- **Rankings**: Multi-format comparison

#### Example Query

```sql
-- Players ranked in all 3 formats
SELECT player_name, country_name, test_rank, odi_rank, t20i_rank
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_ranking_comparison_cross_format`
WHERE test_rank IS NOT NULL AND odi_rank IS NOT NULL AND t20i_rank IS NOT NULL
ORDER BY test_rank
LIMIT 20;

-- Players better in ODI than TEST
SELECT player_name, country_name, 
       test_rank, odi_rank, 
       odi_rank - test_rank as rank_difference
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_ranking_comparison_cross_format`
WHERE test_rank IS NOT NULL 
  AND odi_rank IS NOT NULL
  AND odi_rank < test_rank
ORDER BY rank_difference DESC;
```

---

## ⚙️ Configuration & Placeholders

### Placeholder System

All SQL files use placeholders for flexibility:

```sql
{PROJECT_ID}      -- Your GCP project ID
{RAW_DATASET}     -- Raw layer dataset (cricket_raw)
{STAGING_DATASET} -- Staging dataset (cricket_staging)
{CURATED_DATASET} -- Curated dataset (cricket_curated)
```

### How Placeholders Work

**In SQL File**:
```sql
CREATE TABLE `{PROJECT_ID}.{RAW_DATASET}.batting_rankings` (...)
```

**In Terraform**:
```hcl
definition_body = replace(
  file("path/to/file.sql"),
  "{PROJECT_ID}",
  var.gcp_project_id
)
```

**Result in BigQuery**:
```sql
CREATE TABLE `my-project-id`.`cricket_raw`.`batting_rankings` (...)
```

### Configuration Values

Update these in `config/config.yaml`:

```yaml
gcp:
  project_id: "your-gcp-project"
  region: "us-central1"

bigquery:
  dataset_raw: "cricket_raw"
  dataset_staging: "cricket_staging"
  dataset_curated: "cricket_curated"
```

---

## 🚀 Execution Guide

### Prerequisites

```bash
# Install Google Cloud CLI
gcloud init

# Authenticate
gcloud auth login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Install BigQuery CLI (bq)
gcloud components install bq
```

### Execution Order

**1. Create Datasets (via Terraform)**
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**2. Execute SQL Files**
```bash
# Option A: Manual execution
for f in bigquery/sql/*.sql; do 
  echo "Executing $f..."
  bq query --use_legacy_sql=false < "$f"
done

# Option B: Individual file
bq query --use_legacy_sql=false < bigquery/sql/raw_batting_rankings.sql

# Option C: Check first
bq query --use_legacy_sql=false --dry_run < bigquery/sql/raw_batting_rankings.sql
```

### Verification

```bash
# List datasets
bq ls

# List tables in dataset
bq ls cricket_raw
bq ls cricket_staging
bq ls cricket_curated

# Check table schema
bq show cricket_raw.batting_rankings

# Count rows
bq query "SELECT COUNT(*) FROM cricket_raw.batting_rankings"

# Check latest data
bq query "SELECT * FROM cricket_raw.batting_rankings LIMIT 5"
```

---

## 📚 Development Best Practices

### 1. Testing Changes

```bash
# Always test with --dry_run first
bq query --use_legacy_sql=false --dry_run < modified_file.sql

# Check syntax
bq query --use_legacy_sql=false --dry_run "SELECT 1"
```

### 2. Handling Placeholders

```bash
# When testing locally, create temporary file with placeholders replaced:
sed "s/{PROJECT_ID}/my-project-id/g; \
     s/{RAW_DATASET}/cricket_raw/g; \
     s/{STAGING_DATASET}/cricket_staging/g; \
     s/{CURATED_DATASET}/cricket_curated/g" \
  bigquery/sql/dim_player.sql > /tmp/dim_player_temp.sql

bq query --use_legacy_sql=false < /tmp/dim_player_temp.sql
```

### 3. Modifying Schemas

```bash
# When adding a column:
1. Update the schema JSON file (bigquery/schemas/*.json)
2. Update the SQL CREATE TABLE statement
3. Test with --dry_run
4. Re-run to update the table (BigQuery is flexible)

# Example: Add new column
ALTER TABLE cricket_staging.dim_player
ADD COLUMN jersey_number INT64;
```

### 4. Adding New Views

```bash
# Create new view file: bigquery/sql/vw_new_view.sql
# Create schema file: bigquery/schemas/vw_new_view.json

# Add to Terraform:
resource "google_bigquery_routine" "curated_vw_new_view" {
  dataset_id = google_bigquery_dataset.curated.dataset_id
  routine_id = "vw_new_view"
  definition_body = replace(
    file("${path.module}/../bigquery/sql/vw_new_view.sql"),
    "{STAGING_DATASET}",
    var.bq_staging_dataset
  )
}

# Execute:
bq query --use_legacy_sql=false < bigquery/sql/vw_new_view.sql
```

### 5. Performance Optimization

```sql
-- Use CLUSTER BY for frequently filtered columns
CLUSTER BY format_id, country_id

-- Use PARTITION BY for time-based queries
PARTITION BY DATE(loaded_at)

-- Create indexes on dimension tables
CREATE INDEX dim_player_idx ON dim_player(player_id)
```

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: Placeholder Not Replaced

**Error**: `Table not found: {PROJECT_ID}.{RAW_DATASET}.batting_rankings`

**Solution**: Ensure Terraform is executing replace() properly
```bash
# Check if placeholders are being replaced
grep -r "{PROJECT_ID}" bigquery/sql/
# Should show no results after terraform apply
```

#### Issue 2: MERGE Table Not Found

**Error**: `MERGE target table not found`

**Solution**: Create table first, then run MERGE
```bash
# Step 1: Create empty table with schema
bq mk --table cricket_staging.dim_player bigquery/schemas/dim_player.json

# Step 2: Run MERGE script
bq query --use_legacy_sql=false < bigquery/sql/dim_player.sql
```

#### Issue 3: Date Generation Too Slow

**Error**: Query too complex for GENERATE_ARRAY

**Solution**: Split into multiple batches or use pre-generated CSV

```sql
-- Alternative: Insert in chunks
INSERT INTO cricket_staging.dim_date
SELECT CAST(FORMAT_DATE('%Y%m%d', d) AS INT64) as date_id, d as full_date, ...
FROM UNNEST(GENERATE_ARRAY('2015-01-01', '2025-12-31', INTERVAL 1 DAY)) d
WHERE d < '2025-01-01';
```

#### Issue 4: Column Type Mismatch

**Error**: `INT64 vs INTEGER mismatch`

**Solution**: BigQuery treats INT64 and INTEGER as synonymous
- Schema files use INTEGER (standard)
- SQL files use INT64 (alias)
- Both work fine

#### Issue 5: Insufficient Permissions

**Error**: `Permission denied while getting IAM policy`

**Solution**: Ensure service account has proper roles
```bash
# Grant BigQuery Admin role
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:sa@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/bigquery.admin
```

---

## 📖 Additional Resources

### Schema File Format

Every schema file follows this structure:
```json
[
  {
    "name": "column_name",
    "type": "DATA_TYPE",
    "mode": "NULLABLE|REQUIRED",
    "description": "What this column contains"
  },
  ...
]
```

### BigQuery Data Types Reference

| BigQuery Type | SQL Keyword | Python Type |
|---|---|---|
| INT64 | INTEGER | int |
| FLOAT64 | FLOAT | float |
| STRING | STRING | str |
| TIMESTAMP | TIMESTAMP | datetime |
| DATE | DATE | date |
| ARRAY | ARRAY | list |
| STRUCT | RECORD | dict |

### Useful BigQuery Commands

```bash
# Query with results to CSV
bq query --use_legacy_sql=false --format=csv \
  "SELECT * FROM cricket_raw.batting_rankings LIMIT 10" > output.csv

# Check job history
bq ls -j

# Describe table in detail
bq show --schema --format=json cricket_raw.batting_rankings

# Estimate query cost (without running)
bq query --use_legacy_sql=false --dry_run --format=json "SELECT ..." | jq '.statistics.query.estimatedBytesProcessed'
```

---

## 🎯 Quick Reference

| File | Type | Purpose | Dependencies |
|------|------|---------|--------------|
| raw_batting_rankings.sql | Table | API data copy | None |
| vw_latest_raw.sql | View | Debug view | raw_batting_rankings |
| dim_player.sql | Table | Player dimension | raw_batting_rankings |
| dim_country.sql | Table | Country mapping | raw_batting_rankings |
| dim_format.sql | Table | Format lookup | None |
| dim_date.sql | Table | Date spine | None |
| fact_batting_rankings.sql | Table | Daily snapshot | All dimensions |
| vw_batting_rankings_latest.sql | View | Current rankings | Fact + dimensions |
| vw_batting_rankings_90day_trend.sql | View | Trend analysis | Fact + dim_date |
| vw_top_10_batsmen_by_format.sql | View | Top players | vw_batting_rankings_latest |
| vw_batting_statistics_by_country.sql | View | Country stats | Fact + dimensions |
| vw_ranking_comparison_cross_format.sql | View | Cross-format | Fact + dimensions |

---

**Last Updated**: 2026-06-07  
**Status**: Production Ready  
**Verification**: 100% Complete  

All SQL files are fully documented and ready for development! 🚀

