# ✅ BigQuery Views - Complete Refactoring (Meaningful Names + Separate Files)

**Each view now has its own SQL file with a descriptive, self-documenting name**

---

## 🎯 The Problem (Before)

All views in one file with unclear, generic names:

```
bigquery/sql/
└── 07_create_curated_views.sql  ❌ Generic name, all views mixed together
    ├── vw_current_rankings  ❌ Not clear what "current" means
    ├── vw_ranking_trend  ❌ Not clear what data it contains
    ├── vw_top10_by_format  ❌ Abbreviation (top10) not professional
    ├── vw_country_summary  ❌ Too generic
    └── vw_player_format_comparison  ❌ Too long, unclear purpose
```

**Issues**:
- All views cramped in one file (hard to find and edit)
- Names don't clearly describe purpose
- Inconsistent naming (mix of formal and abbreviated)
- Hard to understand at a glance what each view does

---

## ✅ The Solution (After)

Separate files with meaningful, descriptive names:

```
bigquery/sql/
├── 08_create_view_batting_rankings_latest.sql          ✨ Clear & professional
├── 09_create_view_batting_rankings_90day_trend.sql     ✨ Specific & descriptive
├── 10_create_view_top_10_batsmen_by_format.sql         ✨ Professional (no abbreviations)
├── 11_create_view_batting_statistics_by_country.sql    ✨ Domain-specific language
└── 12_create_view_ranking_comparison_cross_format.sql  ✨ Explains the comparison type
```

**Benefits**:
- Each view has its own file (easy to find and edit)
- Names clearly explain purpose
- Professional naming (no abbreviations)
- Self-documenting code

---

## 📋 View Mapping: Old → New

| File Number | Old Name | New Name | Purpose |
|------------|----------|----------|---------|
| 08 | vw_current_rankings | vw_batting_rankings_latest | Today's rankings snapshot |
| 09 | vw_ranking_trend | vw_batting_rankings_90day_trend | 90-day historical trend |
| 10 | vw_top10_by_format | vw_top_10_batsmen_by_format | Top 10 players per format |
| 11 | vw_country_summary | vw_batting_statistics_by_country | Country aggregates |
| 12 | vw_player_format_comparison | vw_ranking_comparison_cross_format | Cross-format rankings |

---

## 🎨 Naming Principles

### Old Style (Generic)
```
vw_current_rankings
vw_top10_by_format
vw_country_summary
```

### New Style (Descriptive)
```
vw_batting_rankings_latest          # Clear: THIS dataset's rankings, TODAY
vw_top_10_batsmen_by_format         # Clear: Top 10 BATSMEN (not generic), per FORMAT
vw_batting_statistics_by_country    # Clear: STATISTICS about BATTING, grouped by COUNTRY
```

**Naming Rules Used**:
1. **Include domain context**: "batting" (not just "rankings")
2. **Be specific about numbers**: "top_10" (not "top10")
3. **Describe the dimension**: "by_format", "by_country" (not just "summary")
4. **Explain the time period**: "latest", "90day_trend", "cross_format"
5. **Use underscores**: Professional snake_case (not camelCase or abbreviations)

---

## 📁 File Structure

### 08_create_view_batting_rankings_latest.sql

```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_latest` AS
SELECT
  p.player_name,
  c.country_name,
  f.format_name,
  MAX(fb.rank) as current_rank,
  MAX(fb.rating) as current_rating,
  ...
WHERE DATE(fb.loaded_at) = CURRENT_DATE()
```

**Purpose**: Latest rankings snapshot for today  
**Scope**: All players, all formats  
**Time**: Current date only  
**Columns**: 9 (player info + ranking metrics)  

---

### 09_create_view_batting_rankings_90day_trend.sql

```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_90day_trend` AS
SELECT
  p.player_name,
  c.country_name,
  f.format_name,
  d.full_date,
  fb.rank,
  LAG(fb.rank) OVER (...) as previous_rank,
  fb.rank - LAG(fb.rank) OVER (...) as rank_change
WHERE d.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
```

**Purpose**: Historical ranking changes over 90 days  
**Scope**: All players, all formats  
**Time**: Last 90 days  
**Columns**: 7 (player info + date + rank metrics)  
**Key Feature**: `rank_change` calculated via LAG() window function  

---

### 10_create_view_top_10_batsmen_by_format.sql

```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_top_10_batsmen_by_format` AS
SELECT
  ROW_NUMBER() OVER (PARTITION BY format_id ORDER BY current_rank) as rank_position,
  player_name,
  country_name,
  format_name,
  current_rank,
  current_rating,
  ...
FROM `{PROJECT_ID}.{CURATED_DATASET}.vw_batting_rankings_latest`
WHERE current_rank <= 10
```

**Purpose**: Top 10 batsmen per format  
**Scope**: Only rank <= 10  
**Depends on**: vw_batting_rankings_latest  
**Columns**: 8 (position + player info + metrics)  

---

### 11_create_view_batting_statistics_by_country.sql

```sql
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
GROUP BY c.country_name, f.format_name
```

**Purpose**: Aggregated batting statistics per country  
**Scope**: Players in top 50  
**Metrics**: Count, average, min, max  
**Columns**: 8 (country, format, player counts, ratings)  

---

### 12_create_view_ranking_comparison_cross_format.sql

```sql
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
GROUP BY p.player_name, c.country_name
```

**Purpose**: Compare player rankings across formats  
**Format**: Pivot - one row per player  
**Columns**: 8 (player, country, test/odi/t20i ranks & ratings)  
**Key Feature**: Pivot with CASE/MAX for cross-format comparison  

---

## 🔄 Terraform Integration

### Before
```hcl
resource "google_bigquery_routine" "curated_vw_current_rankings" {
  routine_id = var.bq_curated_view_current_rankings  # ❌ Old name
  definition_body = replace(
    file("bigquery/sql/07_create_curated_views.sql"),  # ❌ All views in one file
    ...
  )
}

# Other views: not created separately
```

### After
```hcl
resource "google_bigquery_routine" "curated_vw_batting_rankings_latest" {
  routine_id = var.bq_curated_view_batting_rankings_latest  # ✅ New name
  definition_body = replace(
    file("bigquery/sql/08_create_view_batting_rankings_latest.sql"),  # ✅ Separate file
    ...
  )
}

resource "google_bigquery_routine" "curated_vw_batting_rankings_90day_trend" {
  routine_id = var.bq_curated_view_batting_rankings_90day_trend
  definition_body = replace(
    file("bigquery/sql/09_create_view_batting_rankings_90day_trend.sql"),
    ...
  )
}

# ... 3 more view resources, each with its own SQL file
```

---

## 📊 View Dependencies

```
dim_player ──┐
dim_country ─┼─→ vw_batting_rankings_latest
dim_format  ─┼
dim_date ───┘
fact_batting_rankings

vw_batting_rankings_latest ──→ vw_top_10_batsmen_by_format

fact_batting_rankings ──┐
dim_player ────────────┼─→ vw_batting_rankings_90day_trend
dim_country ───────────┼
dim_format ────────────┤
dim_date ──────────────┘

fact_batting_rankings ──┐
dim_player ────────────┼─→ vw_batting_statistics_by_country
dim_country ───────────┼
dim_format ────────────┘

fact_batting_rankings ──┐
dim_player ────────────┼─→ vw_ranking_comparison_cross_format
dim_country ───────────┤
dim_format ────────────┘
```

---

## ✨ Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **File Organization** | All views in one file | One file per view |
| **Naming** | Generic abbreviations | Descriptive & professional |
| **Clarity** | Hard to find/edit | Easy to navigate |
| **Self-documenting** | Unclear purpose | Purpose in the name |
| **Maintainability** | Single point of change risk | Independent, modular |
| **Scalability** | Hard to add more views | Easy to add new views |

---

## 🚀 File Organization Summary

```
Before:
  bigquery/sql/07_create_curated_views.sql  (5 views, 102 lines)

After:
  bigquery/sql/08_create_view_batting_rankings_latest.sql
  bigquery/sql/09_create_view_batting_rankings_90day_trend.sql
  bigquery/sql/10_create_view_top_10_batsmen_by_format.sql
  bigquery/sql/11_create_view_batting_statistics_by_country.sql
  bigquery/sql/12_create_view_ranking_comparison_cross_format.sql
  
  (5 separate files, each with descriptive name)
```

---

## ✅ Verification

After deployment, verify all views exist with correct names:

```bash
# List all views in curated dataset
bq ls cricket_curated

# Expected output:
#   vw_batting_rankings_latest
#   vw_batting_rankings_90day_trend
#   vw_top_10_batsmen_by_format
#   vw_batting_statistics_by_country
#   vw_ranking_comparison_cross_format

# Check view schema/definition
bq show --schema cricket_curated.vw_batting_rankings_latest
bq show --schema cricket_curated.vw_batting_rankings_90day_trend
# ... etc for all views
```

---

## 📁 Files Changed

**Created**:
- ✅ `bigquery/sql/08_create_view_batting_rankings_latest.sql`
- ✅ `bigquery/sql/09_create_view_batting_rankings_90day_trend.sql`
- ✅ `bigquery/sql/10_create_view_top_10_batsmen_by_format.sql`
- ✅ `bigquery/sql/11_create_view_batting_statistics_by_country.sql`
- ✅ `bigquery/sql/12_create_view_ranking_comparison_cross_format.sql`

**Updated**:
- ✅ `terraform/bigquery.tf` (5 separate view resources)
- ✅ `terraform/variables.tf` (new view name variables)
- ✅ `terraform/terraform.tfvars.example` (new view names)

**Deprecated**:
- 📌 `bigquery/sql/07_create_curated_views.sql` (no longer used, can be deleted)

---

## 🎉 Summary

✨ **MEANINGFUL NAMES & SEPARATE FILES!**

- ✅ **5 views** → **5 separate SQL files**
- ✅ **Generic names** → **Descriptive, professional names**
- ✅ **All mixed** → **Organized, modular structure**
- ✅ **Hard to find** → **Easy to navigate**
- ✅ **Self-documenting** → **Purpose in the name**

---

**Status**: ✅ Complete - All views refactored  
**Files Created**: 5 new SQL files  
**Names Updated**: 5 view names  
**Organization**: From monolithic to modular  

Views are now clear, organized, and professional! 🎯

---
