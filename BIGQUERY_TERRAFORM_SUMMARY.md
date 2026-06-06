# 📊 BigQuery Terraform Resources Summary

**Complete BigQuery Infrastructure - 3 Datasets + 6 Tables + 6 Views**

---

## 📋 Resource Overview

### Terraform File: `terraform/bigquery.tf`

This file creates all BigQuery infrastructure automatically. Importantly, it **references existing SQL and schema files** instead of hardcoding SQL queries.

| Category | Count | Type | Source |
|----------|-------|------|--------|
| **Datasets** | 3 | google_bigquery_dataset | From variables.tf (defaults from config.yaml) |
| **Tables** | 6 | google_bigquery_table | Schema from bigquery/schemas/ + SQL from bigquery/sql/ |
| **Views/Routines** | 2 | google_bigquery_routine (VIEW) | SQL from bigquery/sql/*.sql |
| **TOTAL** | **11** | **BigQuery Resources** | Multiple files |

**Key Architecture**:
- **Schemas**: Defined in `bigquery/schemas/raw_batting_rankings.json` (loaded by terraform)
- **SQL Logic**: Defined in `bigquery/sql/01-07_*.sql` files (loaded and executed via terraform)
- **Idempotent**: Terraform creates structure, SQL scripts handle logic via MERGE/INSERT

---

## 🏗️ Complete Resource Structure

### 1️⃣ RAW LAYER (Dataset: `cricket_raw`)

**Purpose**: Exact copy of ingested API data

#### Table 1: `batting_rankings`
```terraform
resource "google_bigquery_table" "raw_batting_rankings"
```

**Schema (11 columns - from `bigquery/schemas/raw_batting_rankings.json`)**:
- `rank` (INTEGER) - Current ranking
- `player_id` (STRING) - Unique player ID
- `player_name` (STRING) - Player full name
- `country` (STRING) - Country name
- `country_id` (STRING) - Country ID
- `rating` (FLOAT64) - Player rating
- `points` (FLOAT64) - Total points
- `best_rank` (INTEGER) - Career best rank
- `format` (STRING) - TEST/ODI/T20I
- `ingested_at` (TIMESTAMP) - Ingestion time
- `source_file` (STRING) - GCS file path

**Configuration**:
- Partitioned by: `DATE(ingested_at)`
- Clustered by: `format, country`
- TTL: 90 days

#### View 1: `vw_latest_raw`
```terraform
resource "google_bigquery_routine" "raw_vw_latest_raw"
```

**Purpose**: Debug view showing latest 100 records per format per day  
**SQL Location**: `bigquery/sql/01_create_raw_table.sql`  
**Note**: Terraform loads the SQL file and substitutes {PROJECT_ID} with actual project ID

---

### 2️⃣ STAGING LAYER (Dataset: `cricket_staging`)

**Purpose**: Star schema with dimensions and facts

#### Table 2: `dim_player` (Dimension - SCD Type 1)
```terraform
resource "google_bigquery_table" "staging_dim_player"
```

**Schema (4 columns)**:
- `player_id` (STRING, PK) - Unique player identifier
- `player_name` (STRING) - Player name
- `country_id` (STRING) - Country reference
- `last_updated` (TIMESTAMP) - Update timestamp

**Features**:
- Partitioned by: `DATE(last_updated)`
- Type: SCD Type 1 (overwrites on update)
- Primary Key: NOT ENFORCED (informational)

#### Table 3: `dim_country` (Dimension)
```terraform
resource "google_bigquery_table" "staging_dim_country"
```

**Schema (4 columns)**:
- `country_id` (STRING, PK) - Unique country ID
- `country_name` (STRING) - Country name
- `icc_code` (STRING) - ICC country code (IND, AUS, etc.)
- `last_updated` (TIMESTAMP) - Update timestamp

#### Table 4: `dim_format` (Dimension - Static Lookup)
```terraform
resource "google_bigquery_table" "staging_dim_format"
```

**Schema (2 columns)**:
- `format_id` (INTEGER, PK) - 1=TEST, 2=ODI, 3=T20I
- `format_name` (STRING) - Format name

**Static Values**:
```
1, TEST
2, ODI
3, T20I
```

#### Table 5: `dim_date` (Dimension - Date Spine)
```terraform
resource "google_bigquery_table" "staging_dim_date"
```

**Schema (10 columns)**:
- `date_id` (INTEGER, PK) - YYYYMMDD format
- `full_date` (DATE) - Full date
- `year` (INTEGER) - Year
- `quarter` (INTEGER) - Quarter (1-4)
- `month` (INTEGER) - Month (1-12)
- `day` (INTEGER) - Day (1-31)
- `week` (INTEGER) - Week number
- `day_of_week` (INTEGER) - DOW (1-7)
- `day_name` (STRING) - Monday, Tuesday, etc.
- `month_name` (STRING) - January, February, etc.

**Features**:
- 7,305 rows (2015-01-01 to 2034-12-31)
- No partitioning needed (static reference table)

#### Table 6: `fact_batting_rankings` (Fact - Daily Snapshot)
```terraform
resource "google_bigquery_table" "staging_fact_batting"
```

**Schema (10 columns)**:
- `fact_id` (STRING, PK) - Composite: YYYYMMDD-player_id-format_id
- `date_id` (INTEGER, FK) → dim_date
- `player_id` (STRING, FK) → dim_player
- `format_id` (INTEGER, FK) → dim_format
- `country_id` (STRING, FK) → dim_country
- `rank` (INTEGER) - Current rank
- `rating` (FLOAT64) - Rating
- `points` (FLOAT64) - Points
- `best_rank` (INTEGER) - Career best
- `loaded_at` (TIMESTAMP) - Load time

**Features**:
- Partitioned by: `DATE(loaded_at)`
- Clustered by: `format_id, country_id`
- Daily snapshot (one record per player per format per day)
- Updated via MERGE (upsert) for idempotency

---

### 3️⃣ CURATED LAYER (Dataset: `cricket_curated`)

**Purpose**: Analytics-ready pre-joined views for dashboards

#### View 2: `vw_current_rankings`
```terraform
resource "google_bigquery_routine" "curated_vw_current_rankings"
```

**Purpose**: Latest ranking/rating per player+format for today

**Columns**:
- player_name, country_name, format_name
- current_rank, current_rating, current_points, best_rank
- last_updated

**Query**: Joins fact + all dimensions, filters for CURRENT_DATE()

---

#### View 3: `vw_ranking_trend`
```terraform
resource "google_bigquery_routine" "curated_vw_ranking_trend"
```

**Purpose**: 90-day ranking history with rank changes

**Columns**:
- player_name, country_name, format_name, full_date
- rank, rating, previous_rank, rank_change

**Query**: Includes LAG() window function for rank delta

---

#### View 4: `vw_top10_by_format`
```terraform
resource "google_bigquery_routine" "curated_vw_top10_by_format"
```

**Purpose**: Top 10 players per cricket format

**Columns**:
- player_name, country_name, format_name
- current_rank, current_rating, points
- rank_in_format (ROW_NUMBER)

**Filter**: rank <= 10

---

#### View 5: `vw_country_summary`
```terraform
resource "google_bigquery_routine" "curated_vw_country_summary"
```

**Purpose**: Country aggregates and metrics

**Columns**:
- country_name, format_name
- total_players, players_in_top10, players_in_top50
- avg_rating, min_rating, max_rating, avg_points

**Aggregation**: GROUP BY country+format

---

#### View 6: `vw_player_format_comparison`
```terraform
resource "google_bigquery_routine" "curated_vw_player_format_comparison"
```

**Purpose**: Cross-format player rankings (pivot view)

**Columns**:
- player_name, country_name
- test_rank, test_rating
- odi_rank, odi_rating
- t20i_rank, t20i_rating

**Technique**: CASE WHEN with MAX aggregation (pivot)

---

## 🔄 Data Flow & Dependencies

```
Raw Data (GCS CSV)
    ↓
raw_batting_rankings
    ↓ (MERGE logic in Airflow/Scheduler)
dim_player ←→ dim_country ←→ dim_format
    ↓                         ↓
fact_batting_rankings ←→ dim_date
    ↓
vw_current_rankings
vw_ranking_trend
vw_top10_by_format
vw_country_summary
vw_player_format_comparison
    ↓
Looker Studio Dashboard
```

---

## 📊 Terraform Dependencies

```hcl
# Dataset creation (no dependencies)
google_bigquery_dataset.raw
google_bigquery_dataset.staging
google_bigquery_dataset.curated

# Table creation (depends on dataset)
google_bigquery_table.raw_batting_rankings
→ depends_on [google_bigquery_dataset.raw]

google_bigquery_table.staging_dim_player
→ depends_on [google_bigquery_dataset.staging]

google_bigquery_table.staging_dim_country
→ depends_on [google_bigquery_dataset.staging]

google_bigquery_table.staging_dim_format
→ depends_on [google_bigquery_dataset.staging]

google_bigquery_table.staging_dim_date
→ depends_on [google_bigquery_dataset.staging]

google_bigquery_table.staging_fact_batting
→ depends_on [google_bigquery_dataset.staging]

# View creation (depends on tables)
google_bigquery_routine.raw_vw_latest_raw
→ depends_on [google_bigquery_table.raw_batting_rankings]

google_bigquery_routine.curated_vw_current_rankings
→ depends_on [all staging tables]

google_bigquery_routine.curated_vw_ranking_trend
→ depends_on [all staging tables]

google_bigquery_routine.curated_vw_top10_by_format
→ depends_on [all staging tables]

google_bigquery_routine.curated_vw_country_summary
→ depends_on [all staging tables]

google_bigquery_routine.curated_vw_player_format_comparison
→ depends_on [all staging tables]
```

---

## 🚀 Deployment

### 1. Run Terraform
```bash
terraform init
terraform plan
terraform apply
```

### 2. Verify Creation
```bash
# List datasets
bq ls -d

# List tables in staging
bq ls cricket_staging

# List views in curated
bq ls cricket_curated

# Check view schema
bq show cricket_curated.vw_current_rankings
```

### 3. Populate Tables
```bash
# Dataflow will populate raw table
# Scheduled queries/Airflow will populate staging
# Views are auto-updated with staging data
```

---

## 📝 Variables Used (from terraform.tfvars)

```hcl
gcp_project_id              = "cricket-analytics-dev"
bq_raw_dataset              = "cricket_raw"
bq_staging_dataset          = "cricket_staging"
bq_curated_dataset          = "cricket_curated"
bq_raw_table_name           = "batting_rankings"
bq_table_expiration_days    = 90
```

All customizable in `terraform/terraform.tfvars`

---

## ✅ Verification Checklist

After `terraform apply`:

```bash
☐ 3 datasets created (raw, staging, curated)
☐ 6 tables created with correct schemas
☐ 6 views created with correct queries
☐ Partitioning/clustering applied
☐ All dependencies resolved
☐ No errors in terraform output
☐ Can query each view successfully
☐ Schemas match SQL script definitions
```

---

## 🎯 Next Steps

1. **Run Terraform**:
   ```bash
   cd terraform
   terraform apply
   ```

2. **Verify Resources**:
   ```bash
   bq ls -d
   bq ls cricket_raw
   bq ls cricket_staging
   bq ls cricket_curated
   ```

3. **Deploy Application Code**:
   - Cloud Function code to GCS
   - Dataflow template to Artifact Registry
   - Airflow DAGs to Cloud Composer

4. **Test Pipeline**:
   - Run ingestion
   - Check raw data
   - Verify staging transforms
   - Query curated views

5. **Create Dashboard**:
   - Connect Looker Studio to views
   - Build visualizations

---

## 📚 File Reference

| File | Purpose |
|------|---------|
| `terraform/bigquery.tf` | All BigQuery resources |
| `terraform/variables.tf` | All configurable variables |
| `terraform/terraform.tfvars` | Your custom values |
| `bigquery/sql/*.sql` | SQL script definitions |
| `SQL_STRUCTURE.md` | SQL structure analysis |
| `BIGQUERY_TERRAFORM_SUMMARY.md` | This file |

---

**Status**: ✅ Ready for Deployment  
**Total Resources**: 15 (3 datasets + 6 tables + 6 views)  
**Date**: June 2026  

All BigQuery infrastructure fully defined in Terraform! 🚀
