# 📊 SQL Structure Analysis

## 3 Datasets with 6 Tables + Views

### **Dataset 1: cricket_raw** (RAW Layer)
Purpose: Exact copy of API data

**Tables:**
1. `batting_rankings` - Raw batting data
   - Columns: 11 (rank, player_id, player_name, country, country_id, rating, points, best_rank, format, ingested_at, source_file)
   - Partitioned by: DATE(ingested_at)
   - Clustered by: format, country
   - TTL: 90 days

**Views:**
1. `vw_latest_raw` - Latest 100 records per format per day

---

### **Dataset 2: cricket_staging** (STAGING Layer - Star Schema)
Purpose: Dimensional modeling with SCD Type 1

**Tables (4):**
1. `dim_player`
   - Columns: player_id (PK), player_name, country_id, last_updated
   - Partitioned by: DATE(last_updated)
   - Type: SCD Type 1 (overwrites)

2. `dim_country`
   - Columns: country_id (PK), country_name, icc_code, last_updated
   - Static lookup table

3. `dim_format`
   - Columns: format_id (PK), format_name
   - Static: TEST=1, ODI=2, T20I=3

4. `dim_date`
   - Columns: date_id, full_date, year, quarter, month, day, week, day_of_week, day_name, month_name
   - Date spine: 2015-2035 (7305 rows)

5. `fact_batting_rankings`
   - Columns: fact_id (PK), date_id, player_id, format_id, country_id, rank, rating, points, best_rank, loaded_at
   - Composite Key: YYYYMMDD-player_id-format_id
   - Partitioned by: DATE(loaded_at)
   - Clustered by: format_id, country_id
   - Type: Daily snapshot (UPSERT via MERGE)

---

### **Dataset 3: cricket_curated** (CURATED Layer)
Purpose: Analytics-ready pre-joined views

**Views (5):**
1. `vw_current_rankings` - Latest rankings per player+format
2. `vw_ranking_trend` - 90-day history with rank changes
3. `vw_top10_by_format` - Top 10 players per format
4. `vw_country_summary` - Country aggregates
5. `vw_player_format_comparison` - Cross-format pivot

---

## Total Count

| Item | Count |
|------|-------|
| **Datasets** | 3 |
| **Tables** | 6 |
| **Views** | 6 |
| **Total** | 15 objects |

---

## Creation Order (Correct Sequence)

```
1. Create Datasets (cricket_raw, cricket_staging, cricket_curated)
2. Create RAW tables (batting_rankings)
3. Create STAGING dimension tables (dim_player, dim_country, dim_format, dim_date)
4. Create STAGING fact table (fact_batting_rankings)
5. Create CURATED views (vw_*)
```

---

## Terraform Resources Needed

- `google_bigquery_dataset` x3
- `google_bigquery_table` x6
- `google_bigquery_routine` x6 (for views)

Total: 15 Terraform resources
