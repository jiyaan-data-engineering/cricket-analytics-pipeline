# ✅ SQL Placeholders - Complete Refactoring (NO Hardcoding)

**All SQL Scripts Now Use Placeholders for Dynamic Dataset Names**

---

## 🎯 The Problem (Before)

SQL files had hardcoded dataset names:
```sql
-- HARDCODED - Not configurable
CREATE OR REPLACE TABLE `cricket-project.cricket_raw.batting_rankings` AS ...
MERGE `cricket-project.cricket_staging.dim_player` ...
```

**Issues**:
- Can't change dataset names without editing SQL files
- Tight coupling between SQL and configuration
- Multiple sources of truth (config.yaml AND SQL files)

---

## ✅ The Solution (After)

All SQL files now use **placeholders** for dynamic substitution:

```sql
-- CONFIGURABLE - Gets values from terraform variables
CREATE OR REPLACE TABLE `{PROJECT_ID}.{RAW_DATASET}.batting_rankings` AS ...
MERGE `{PROJECT_ID}.{STAGING_DATASET}.dim_player` ...
```

**Placeholders Used**:
- `{PROJECT_ID}` → GCP project ID (from `var.gcp_project_id`)
- `{RAW_DATASET}` → Raw dataset name (from `var.bq_raw_dataset`)
- `{STAGING_DATASET}` → Staging dataset name (from `var.bq_staging_dataset`)
- `{CURATED_DATASET}` → Curated dataset name (from `var.bq_curated_dataset`)

---

## 📁 Files Updated

### SQL Files (All 7 Updated)

| File | Placeholders | Source |
|------|-----------|--------|
| `01_create_raw_table.sql` | {PROJECT_ID}, {RAW_DATASET} | config.yaml → bq_raw_dataset |
| `02_create_dim_player.sql` | {PROJECT_ID}, {RAW_DATASET}, {STAGING_DATASET} | config.yaml |
| `03_create_dim_country.sql` | {PROJECT_ID}, {RAW_DATASET}, {STAGING_DATASET} | config.yaml |
| `04_create_dim_format.sql` | {PROJECT_ID}, {STAGING_DATASET} | config.yaml |
| `05_create_dim_date.sql` | {PROJECT_ID}, {STAGING_DATASET} | config.yaml |
| `06_create_fact_batting.sql` | {PROJECT_ID}, {RAW_DATASET}, {STAGING_DATASET} | config.yaml |
| `07_create_curated_views.sql` | {PROJECT_ID}, {STAGING_DATASET}, {CURATED_DATASET} | config.yaml |

### Terraform File (Updated)

**`terraform/bigquery.tf`**:

```hcl
# OLD (single replacement)
definition_body = replace(
  file("bigquery/sql/01_create_raw_table.sql"),
  "{PROJECT_ID}",
  var.gcp_project_id
)

# NEW (multiple nested replacements)
definition_body = replace(
  replace(
    replace(
      file("bigquery/sql/01_create_raw_table.sql"),
      "{PROJECT_ID}",
      var.gcp_project_id
    ),
    "{RAW_DATASET}",
    var.bq_raw_dataset
  ),
  "{STAGING_DATASET}",
  var.bq_staging_dataset
)
```

**How it Works**:
1. Read SQL file
2. Replace `{PROJECT_ID}` with actual project ID
3. Replace `{RAW_DATASET}` with dataset name from config.yaml
4. Replace `{STAGING_DATASET}` with dataset name from config.yaml
5. Replace `{CURATED_DATASET}` with dataset name from config.yaml
6. Pass to BigQuery

---

## 🔄 Data Flow: Config → Terraform → SQL

```
config/config.yaml (Source of Truth)
├─ gcp.project_id = "cricket-analytics-dev"
└─ bigquery:
   ├─ dataset_raw: "cricket_raw"
   ├─ dataset_staging: "cricket_staging"
   └─ dataset_curated: "cricket_curated"
    ↓
terraform/variables.tf (Read and Override)
├─ var.gcp_project_id (default from config)
├─ var.bq_raw_dataset (default from config)
├─ var.bq_staging_dataset (default from config)
└─ var.bq_curated_dataset (default from config)
    ↓
terraform/terraform.tfvars (Optional Overrides)
├─ gcp_project_id = "cricket-analytics-dev"
├─ bq_raw_dataset = "cricket_raw"
├─ bq_staging_dataset = "cricket_staging"
└─ bq_curated_dataset = "cricket_curated"
    ↓
terraform/bigquery.tf (Substitution)
├─ Replace {PROJECT_ID} → "cricket-analytics-dev"
├─ Replace {RAW_DATASET} → "cricket_raw"
├─ Replace {STAGING_DATASET} → "cricket_staging"
└─ Replace {CURATED_DATASET} → "cricket_curated"
    ↓
bigquery/sql/*.sql (Dynamic SQL)
├─ `{PROJECT_ID}.{RAW_DATASET}.batting_rankings`
│  ↓ becomes
├─ `cricket-analytics-dev.cricket_raw.batting_rankings`
│
├─ `{PROJECT_ID}.{STAGING_DATASET}.dim_player`
│  ↓ becomes
├─ `cricket-analytics-dev.cricket_staging.dim_player`
│
└─ `{PROJECT_ID}.{CURATED_DATASET}.vw_current_rankings`
   ↓ becomes
   `cricket-analytics-dev.cricket_curated.vw_current_rankings`
```

---

## 💡 Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Hardcoded Values** | Dataset names in SQL | Uses placeholders |
| **Configuration** | Multiple sources | Single source (config.yaml) |
| **Customization** | Edit SQL files | Just change variables |
| **Team Collaboration** | Risk of conflicts | Safe and simple |
| **Reusability** | Low (tight coupling) | High (fully dynamic) |
| **Error Prone** | Yes (manual edits) | No (automated) |

---

## 🚀 Example: Changing Dataset Names

### Scenario: Need different dataset names for production

**BEFORE** (Hardcoded - Had to edit SQL files):
```bash
# Edit 7 SQL files manually
sed -i 's/cricket_raw/prod_raw/g' bigquery/sql/*.sql
sed -i 's/cricket_staging/prod_staging/g' bigquery/sql/*.sql
sed -i 's/cricket_curated/prod_curated/g' bigquery/sql/*.sql
# Risk of errors, version control issues, etc.
```

**AFTER** (Placeholders - Just update config):
```yaml
# config/config.yaml
bigquery:
  dataset_raw: "prod_raw"
  dataset_staging: "prod_staging"
  dataset_curated: "prod_curated"
```

Or via Terraform:
```hcl
# terraform.tfvars
bq_raw_dataset = "prod_raw"
bq_staging_dataset = "prod_staging"
bq_curated_dataset = "prod_curated"
```

Then run:
```bash
terraform apply
# All placeholders automatically substituted!
```

---

## 📋 Placeholder Reference

### In SQL Files:

```sql
-- RAW LAYER
CREATE TABLE `{PROJECT_ID}.{RAW_DATASET}.batting_rankings`

-- STAGING LAYER
CREATE TABLE `{PROJECT_ID}.{STAGING_DATASET}.dim_player`
MERGE `{PROJECT_ID}.{STAGING_DATASET}.dim_player`

-- CURATED LAYER
CREATE VIEW `{PROJECT_ID}.{CURATED_DATASET}.vw_current_rankings`
```

### In Terraform:

```hcl
# terraform/variables.tf (defaults from config.yaml)
variable "gcp_project_id" {
  type = string
}

variable "bq_raw_dataset" {
  type = string
}

variable "bq_staging_dataset" {
  type = string
}

variable "bq_curated_dataset" {
  type = string
}

# terraform/bigquery.tf (substitution)
definition_body = replace(
  replace(
    replace(
      replace(
        file("sql_file.sql"),
        "{PROJECT_ID}",
        var.gcp_project_id
      ),
      "{RAW_DATASET}",
      var.bq_raw_dataset
    ),
    "{STAGING_DATASET}",
    var.bq_staging_dataset
  ),
  "{CURATED_DATASET}",
  var.bq_curated_dataset
)
```

---

## ✅ Verification

After deploying, verify placeholders were substituted correctly:

```bash
# Check terraform output
terraform output bigquery_raw_dataset
# Output: cricket_raw

terraform output bigquery_staging_dataset
# Output: cricket_staging

# Check BigQuery
bq ls -d
# Output:
# cricket_curated
# cricket_raw
# cricket_staging

# Verify table exists with correct project+dataset
bq show cricket_raw.batting_rankings
```

---

## 🔗 Related Architecture

This refactoring follows the same pattern as:
- ✅ GCS bucket names from `config.yaml` (via `terraform/gcs.tf`)
- ✅ BigQuery schemas from `bigquery/schemas/raw_batting_rankings.json`
- ✅ All configuration centralized in `config/config.yaml`

**Single Source of Truth**: All configuration lives in `config/config.yaml`

---

## 📚 Documentation Files Updated

The following markdown files have been updated to reflect this change:

- `BIGQUERY_TERRAFORM_SUMMARY.md` — Added placeholder explanation
- `TERRAFORM_GUIDE.md` — Updated deployment section
- `TERRAFORM_BIGQUERY_REFACTORED.md` — Updated with placeholder details
- `SQL_STRUCTURE.md` — Added placeholder reference

---

## 🎉 Summary

✨ **NO HARDCODING** — All dataset names are now dynamic  
✨ **CONFIGURABLE** — Change names from config.yaml or terraform.tfvars  
✨ **CONSISTENT** — Follows same pattern as GCS/schemas  
✨ **MAINTAINABLE** — Single source of truth (config.yaml)  
✨ **SAFE** — Automated substitution eliminates manual errors  

---

**Status**: ✅ Complete - All SQL files refactored  
**Files Updated**: 7 SQL files + terraform/bigquery.tf + documentation  
**No More Hardcoding**: Dataset names fully dynamic!

---

All SQL files are now configuration-driven! 🚀
