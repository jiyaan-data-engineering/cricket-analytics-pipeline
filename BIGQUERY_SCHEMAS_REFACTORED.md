# ✅ BigQuery Schemas - Complete Refactoring (One Schema Per Table)

**Each table now has its own schema file with only needed columns**

---

## 🎯 The Problem (Before)

Only one schema file for all tables:
```
bigquery/schemas/
└── raw_batting_rankings.json  ❌ Only one schema!
```

**Issues**:
- All tables would share the same schema
- Can't customize columns per table
- Hard to maintain separate schemas
- Not clear which columns belong to which table

---

## ✅ The Solution (After)

Separate schema file for each table with only needed columns:

```
bigquery/schemas/
├── raw_batting_rankings.json     (11 columns)
├── dim_player.json               (4 columns)
├── dim_country.json              (4 columns)
├── dim_format.json               (3 columns)
├── dim_date.json                 (10 columns)
└── fact_batting_rankings.json    (11 columns)
```

Each schema:
- Contains ONLY columns for that table
- Is independently managed
- Can be customized per table
- Is the single source of truth for that table

---

## 📋 Schema Files Created (5 New + 1 Existing)

### 1. Raw Layer

#### `raw_batting_rankings.json` (11 columns)
```json
[
  { "name": "rank", "type": "INTEGER" },
  { "name": "player_id", "type": "STRING" },
  { "name": "player_name", "type": "STRING" },
  { "name": "country", "type": "STRING" },
  { "name": "country_id", "type": "STRING" },
  { "name": "rating", "type": "FLOAT64" },
  { "name": "points", "type": "FLOAT64" },
  { "name": "best_rank", "type": "INTEGER" },
  { "name": "format", "type": "STRING" },
  { "name": "ingested_at", "type": "TIMESTAMP" },
  { "name": "source_file", "type": "STRING" }
]
```

**Purpose**: Exact copy of API data  
**Partitioned by**: ingested_at  
**Clustered by**: format, country  

---

### 2. Staging Layer - Dimensions

#### `dim_player.json` (4 columns)
```json
[
  { "name": "player_id", "type": "STRING", "mode": "REQUIRED" },
  { "name": "player_name", "type": "STRING" },
  { "name": "country_id", "type": "STRING" },
  { "name": "last_updated", "type": "TIMESTAMP", "mode": "REQUIRED" }
]
```

**Purpose**: Dimension table - Player info  
**Type**: SCD Type 1 (overwrites on update)  
**Primary Key**: player_id  
**Partitioned by**: last_updated  

---

#### `dim_country.json` (4 columns)
```json
[
  { "name": "country_id", "type": "STRING", "mode": "REQUIRED" },
  { "name": "country_name", "type": "STRING" },
  { "name": "icc_code", "type": "STRING" },
  { "name": "last_updated", "type": "TIMESTAMP" }
]
```

**Purpose**: Dimension table - Country info  
**Primary Key**: country_id  
**ICC Codes**: IND, AUS, PAK, ENG, RSA, WI, NZ, SL, BAN, AFG, UNK  

---

#### `dim_format.json` (3 columns)
```json
[
  { "name": "format_id", "type": "INTEGER", "mode": "REQUIRED" },
  { "name": "format_name", "type": "STRING", "mode": "REQUIRED" },
  { "name": "description", "type": "STRING" }
]
```

**Purpose**: Dimension table - Cricket format lookup  
**Static Values**:
- 1 → TEST (Test Cricket)
- 2 → ODI (One Day International)
- 3 → T20I (Twenty20 International)

---

#### `dim_date.json` (10 columns)
```json
[
  { "name": "date_id", "type": "INTEGER", "mode": "REQUIRED" },
  { "name": "full_date", "type": "DATE", "mode": "REQUIRED" },
  { "name": "year", "type": "INTEGER" },
  { "name": "quarter", "type": "INTEGER" },
  { "name": "month", "type": "INTEGER" },
  { "name": "day", "type": "INTEGER" },
  { "name": "week", "type": "INTEGER" },
  { "name": "day_of_week", "type": "INTEGER" },
  { "name": "day_name", "type": "STRING" },
  { "name": "month_name", "type": "STRING" }
]
```

**Purpose**: Dimension table - Date spine  
**Date Range**: 2015-01-01 to 2034-12-31 (7,305 rows)  
**Primary Key**: date_id (YYYYMMDD format)  

---

#### `fact_batting_rankings.json` (11 columns)
```json
[
  { "name": "fact_id", "type": "STRING", "mode": "REQUIRED" },
  { "name": "date_id", "type": "INTEGER" },
  { "name": "player_id", "type": "STRING", "mode": "REQUIRED" },
  { "name": "format_id", "type": "INTEGER" },
  { "name": "country_id", "type": "STRING" },
  { "name": "rank", "type": "INTEGER" },
  { "name": "rating", "type": "FLOAT64" },
  { "name": "points", "type": "FLOAT64" },
  { "name": "best_rank", "type": "INTEGER" },
  { "name": "source_file", "type": "STRING" },
  { "name": "loaded_at", "type": "TIMESTAMP", "mode": "REQUIRED" }
]
```

**Purpose**: Fact table - Daily ranking snapshot  
**Type**: Daily snapshot (one record per player per format per day)  
**Primary Key**: fact_id (composite: YYYYMMDD-player_id-format_id)  
**Partitioned by**: loaded_at  
**Clustered by**: format_id, country_id  
**Update Method**: MERGE (UPSERT) for idempotency  

---

## 🔄 Terraform Integration

### Before
```hcl
# Only raw table had schema loaded
resource "google_bigquery_table" "raw_batting_rankings" {
  schema = file("bigquery/schemas/raw_batting_rankings.json")
}

# Staging tables had no schema
resource "google_bigquery_table" "staging_dim_player" {
  # ❌ No schema parameter
}
```

### After
```hcl
# Each table loads its own schema
resource "google_bigquery_table" "raw_batting_rankings" {
  schema = file("bigquery/schemas/raw_batting_rankings.json")
}

resource "google_bigquery_table" "staging_dim_player" {
  schema = file("bigquery/schemas/dim_player.json")  # ✅ Separate schema
}

resource "google_bigquery_table" "staging_dim_country" {
  schema = file("bigquery/schemas/dim_country.json")  # ✅ Separate schema
}

resource "google_bigquery_table" "staging_dim_format" {
  schema = file("bigquery/schemas/dim_format.json")  # ✅ Separate schema
}

resource "google_bigquery_table" "staging_dim_date" {
  schema = file("bigquery/schemas/dim_date.json")  # ✅ Separate schema
}

resource "google_bigquery_table" "staging_fact_batting" {
  schema = file("bigquery/schemas/fact_batting_rankings.json")  # ✅ Separate schema
}
```

---

## 📊 Column Count by Table

| Table | Columns | Type | Format |
|-------|---------|------|--------|
| **batting_rankings** | 11 | Raw | API response |
| **dim_player** | 4 | Dimension | SCD Type 1 |
| **dim_country** | 4 | Dimension | Static |
| **dim_format** | 3 | Dimension | Static |
| **dim_date** | 10 | Dimension | Date spine |
| **fact_batting_rankings** | 11 | Fact | Daily snapshot |
| **TOTAL** | **43** | | |

---

## 🎯 Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Schema Organization** | Single file | One per table |
| **Column Clarity** | Mixed columns | Only needed columns |
| **Customization** | Difficult | Easy (per table) |
| **Maintenance** | Error-prone | Clear and simple |
| **Reusability** | Low | High |
| **Documentation** | Unclear | Self-documenting |

---

## 🔗 Schema-to-SQL-to-Terraform Flow

```
SQL Definition (Source)
└── bigquery/sql/02_create_dim_player.sql

    CREATE TABLE `{PROJECT_ID}.{STAGING_DATASET}.dim_player` (
      player_id STRING NOT NULL,
      player_name STRING,
      country_id STRING,
      last_updated TIMESTAMP NOT NULL,
      PRIMARY KEY (player_id) NOT ENFORCED
    )

         ↓ (Defines which columns)

Schema Definition (Single Source of Truth)
└── bigquery/schemas/dim_player.json

    [
      { "name": "player_id", "type": "STRING", "mode": "REQUIRED" },
      { "name": "player_name", "type": "STRING" },
      { "name": "country_id", "type": "STRING" },
      { "name": "last_updated", "type": "TIMESTAMP", "mode": "REQUIRED" }
    ]

         ↓ (Referenced by)

Terraform Definition
└── terraform/bigquery.tf

    resource "google_bigquery_table" "staging_dim_player" {
      schema = file("bigquery/schemas/dim_player.json")
      ...
    }

         ↓ (Creates)

BigQuery Table
└── cricket_staging.dim_player

    With exactly the columns defined in dim_player.json
```

---

## ✅ Verification

After deployment, verify each table has correct schema:

```bash
# Check raw table schema
bq show --schema cricket_raw.batting_rankings

# Check dimension tables
bq show --schema cricket_staging.dim_player
bq show --schema cricket_staging.dim_country
bq show --schema cricket_staging.dim_format
bq show --schema cricket_staging.dim_date

# Check fact table
bq show --schema cricket_staging.fact_batting_rankings

# List all columns for a table
bq show --schema --format=json cricket_raw.batting_rankings
```

---

## 📁 Files Updated/Created

**Created**:
- ✅ `bigquery/schemas/dim_player.json`
- ✅ `bigquery/schemas/dim_country.json`
- ✅ `bigquery/schemas/dim_format.json`
- ✅ `bigquery/schemas/dim_date.json`
- ✅ `bigquery/schemas/fact_batting_rankings.json`

**Updated**:
- ✅ `terraform/bigquery.tf` (added schema file references for all tables)

---

## 🚀 Next Steps

Deploy with Terraform:

```bash
cd terraform
terraform apply
```

**Result**:
- ✅ All tables created with schemas from JSON files
- ✅ Each table has exactly the columns it needs
- ✅ Single source of truth for each schema
- ✅ Easy to customize per table

---

## 🎉 Summary

**ZERO HARDCODING IN SCHEMAS!**

- ✅ **6 tables** → **6 schema files**
- ✅ **Each file** → Only needed columns
- ✅ **Single source** → Easy maintenance
- ✅ **Terraform integration** → Automatic loading
- ✅ **Independent** → Customize any table

All table schemas are now cleanly organized! 🎯

---

**Status**: ✅ Complete - All schemas refactored  
**Files Created**: 5 new schema files  
**Tables Configured**: 6 (1 raw + 4 dimensions + 1 fact)  
**Total Columns Defined**: 43 across all tables  

No more hardcoding, maximum clarity! 🚀
