# ✅ Terraform BigQuery.tf - Complete Refactoring (NO Hardcoding)

**All table names, view names, and clustering configurations are now fully configurable**

---

## 🎯 The Problem (Before)

The `terraform/bigquery.tf` file had multiple hardcoded values:

```hcl
# HARDCODED - Not configurable
resource "google_bigquery_table" "staging_dim_player" {
  table_id = "dim_player"  # ❌ Hardcoded
  ...
}

resource "google_bigquery_routine" "raw_vw_latest_raw" {
  routine_id = "vw_latest_raw"  # ❌ Hardcoded
  ...
}

resource "google_bigquery_table" "raw_batting_rankings" {
  clustering = ["format", "country"]  # ❌ Hardcoded
  ...
}
```

**Issues**:
- Can't change table/view names without editing Terraform code
- Clustering columns hardcoded (can't customize)
- Difficult for multi-environment setups (dev/staging/prod)
- Error-prone when copy-pasting configurations

---

## ✅ The Solution (After)

All hardcoded values are now **configurable variables**:

```hcl
# CONFIGURABLE - Gets values from config.yaml via variables
resource "google_bigquery_table" "staging_dim_player" {
  table_id = var.bq_staging_table_dim_player
  ...
}

resource "google_bigquery_routine" "raw_vw_latest_raw" {
  routine_id = var.bq_raw_view_latest_raw
  ...
}

resource "google_bigquery_table" "raw_batting_rankings" {
  clustering = var.bq_raw_clustering_fields
  ...
}
```

---

## 📋 Variables Added to `terraform/variables.tf`

### Table Names (6 variables)

```hcl
variable "bq_raw_table_batting_rankings" {
  default = "batting_rankings"
}

variable "bq_staging_table_dim_player" {
  default = "dim_player"
}

variable "bq_staging_table_dim_country" {
  default = "dim_country"
}

variable "bq_staging_table_dim_format" {
  default = "dim_format"
}

variable "bq_staging_table_dim_date" {
  default = "dim_date"
}

variable "bq_staging_table_fact_batting" {
  default = "fact_batting_rankings"
}
```

### View Names (6 variables)

```hcl
variable "bq_raw_view_latest_raw" {
  default = "vw_latest_raw"
}

variable "bq_curated_view_current_rankings" {
  default = "vw_current_rankings"
}

variable "bq_curated_view_ranking_trend" {
  default = "vw_ranking_trend"
}

variable "bq_curated_view_top10_by_format" {
  default = "vw_top10_by_format"
}

variable "bq_curated_view_country_summary" {
  default = "vw_country_summary"
}

variable "bq_curated_view_player_format_comparison" {
  default = "vw_player_format_comparison"
}
```

### Clustering Configuration (2 variables)

```hcl
variable "bq_raw_clustering_fields" {
  type    = list(string)
  default = ["format", "country"]
}

variable "bq_fact_clustering_fields" {
  type    = list(string)
  default = ["format_id", "country_id"]
}
```

---

## 🔄 Configuration Hierarchy

```
config/config.yaml (Source of Truth)
├─ bigquery:
│  ├─ table_raw_batting: "batting_rankings"
│  └─ (other table names)
    ↓
terraform/variables.tf (Read + Allow Overrides)
├─ var.bq_raw_table_batting_rankings (default from config)
├─ var.bq_staging_table_dim_player (default from config)
├─ var.bq_raw_clustering_fields (list)
└─ ... (all table/view names)
    ↓
terraform/terraform.tfvars (Optional Overrides)
├─ bq_raw_table_batting_rankings = "batting_rankings"
├─ bq_staging_table_dim_player = "dim_player"
├─ bq_raw_clustering_fields = ["format", "country"]
└─ ... (customize as needed)
    ↓
terraform/bigquery.tf (Uses variables)
├─ table_id = var.bq_staging_table_dim_player
├─ routine_id = var.bq_raw_view_latest_raw
├─ clustering = var.bq_raw_clustering_fields
└─ ... (all resource definitions)
    ↓
BigQuery (Creates with configured names)
├─ cricket_raw.dim_player
├─ cricket_staging.vw_current_rankings
└─ ... (all tables and views)
```

---

## 📝 Changes to `terraform/bigquery.tf`

### Before
```hcl
resource "google_bigquery_table" "raw_batting_rankings" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = var.bq_raw_table_name  # ❌ Mixed naming
  clustering = ["format", "country"]   # ❌ Hardcoded
  ...
}

resource "google_bigquery_table" "staging_dim_player" {
  table_id = "dim_player"  # ❌ Hardcoded
  ...
}

resource "google_bigquery_routine" "raw_vw_latest_raw" {
  routine_id = "vw_latest_raw"  # ❌ Hardcoded
  ...
}
```

### After
```hcl
resource "google_bigquery_table" "raw_batting_rankings" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = var.bq_raw_table_batting_rankings  # ✅ Variable
  clustering = var.bq_raw_clustering_fields      # ✅ Variable
  ...
}

resource "google_bigquery_table" "staging_dim_player" {
  table_id = var.bq_staging_table_dim_player  # ✅ Variable
  ...
}

resource "google_bigquery_routine" "raw_vw_latest_raw" {
  routine_id = var.bq_raw_view_latest_raw  # ✅ Variable
  ...
}
```

---

## 💡 Use Cases

### Use Case 1: Multi-Environment Setup

**Dev environment** (`terraform-dev.tfvars`):
```hcl
bq_raw_dataset = "cricket_raw_dev"
bq_staging_table_dim_player = "dim_player_dev"
bq_curated_view_current_rankings = "vw_current_rankings_dev"
```

**Prod environment** (`terraform-prod.tfvars`):
```hcl
bq_raw_dataset = "cricket_raw_prod"
bq_staging_table_dim_player = "dim_player_prod"
bq_curated_view_current_rankings = "vw_current_rankings_prod"
```

Deploy:
```bash
# Dev
terraform apply -var-file=terraform-dev.tfvars

# Prod
terraform apply -var-file=terraform-prod.tfvars
```

### Use Case 2: Custom Naming Convention

```hcl
# Organization uses `fact_` prefix for all fact tables
bq_staging_table_fact_batting = "fact_batting_rankings_daily"

# Organization uses `dim_` prefix (already default)
bq_staging_table_dim_player = "dim_player"
```

### Use Case 3: Different Clustering Strategy

```hcl
# Default: cluster by [format, country]
bq_raw_clustering_fields = ["country", "format"]  # Different order

# Fact table: add player_id to clustering
bq_fact_clustering_fields = ["format_id", "country_id", "player_id"]
```

---

## ✨ Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Hardcoded Names** | 8 hardcoded table/view names | Zero hardcoding |
| **Customization** | Edit TF files | Update variables only |
| **Reusability** | Low (tight coupling) | High (fully configurable) |
| **Multi-Environment** | Difficult | Easy (separate tfvars files) |
| **Naming Flexibility** | None | Complete control |
| **Clustering Config** | Hardcoded | Fully customizable |

---

## 🚀 Example Deployment

### Default (from variables)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform apply
```

**Creates**:
- Tables: `batting_rankings`, `dim_player`, `dim_country`, etc.
- Views: `vw_latest_raw`, `vw_current_rankings`, etc.
- Clustering: `[format, country]` for raw, `[format_id, country_id]` for fact

### Custom Names
```bash
# Edit terraform.tfvars
bq_staging_table_dim_player = "player_dimension"
bq_staging_table_dim_country = "country_dimension"
bq_curated_view_current_rankings = "rankings_current"
```

**Creates**:
- Tables: `batting_rankings`, `player_dimension`, `country_dimension`, etc.
- Views: `vw_latest_raw`, `rankings_current`, etc.
- Clustering: unchanged

---

## 📋 Variable Summary

### Table Name Variables (6)
- `bq_raw_table_batting_rankings` → "batting_rankings"
- `bq_staging_table_dim_player` → "dim_player"
- `bq_staging_table_dim_country` → "dim_country"
- `bq_staging_table_dim_format` → "dim_format"
- `bq_staging_table_dim_date` → "dim_date"
- `bq_staging_table_fact_batting` → "fact_batting_rankings"

### View Name Variables (6)
- `bq_raw_view_latest_raw` → "vw_latest_raw"
- `bq_curated_view_current_rankings` → "vw_current_rankings"
- `bq_curated_view_ranking_trend` → "vw_ranking_trend"
- `bq_curated_view_top10_by_format` → "vw_top10_by_format"
- `bq_curated_view_country_summary` → "vw_country_summary"
- `bq_curated_view_player_format_comparison` → "vw_player_format_comparison"

### Clustering Variables (2)
- `bq_raw_clustering_fields` → ["format", "country"]
- `bq_fact_clustering_fields` → ["format_id", "country_id"]

---

## 🎯 Files Updated

✅ **terraform/variables.tf** — Added 14 new variables  
✅ **terraform/bigquery.tf** — Updated 8 resource definitions  
✅ **terraform/terraform.tfvars.example** — Added variable examples  

---

## ✅ Verification

After deployment, verify all names are correct:

```bash
# Check BigQuery tables
bq ls cricket_raw
bq ls cricket_staging
bq ls cricket_curated

# Verify table exists
bq show cricket_raw.batting_rankings

# Verify clustering
bq show --schema cricket_staging.fact_batting_rankings
```

---

## 🎉 Summary

✨ **ZERO HARDCODING** — All table/view names are variables  
✨ **FULLY CONFIGURABLE** — Customize via terraform.tfvars  
✨ **MULTI-ENVIRONMENT** — Easy dev/staging/prod setups  
✨ **CLUSTERING CONTROL** — Customize clustering columns  
✨ **CONSISTENT PATTERN** — Same approach as GCS/SQL placeholders  

---

**Status**: ✅ Complete - All bigquery.tf hardcoding removed  
**Variables Added**: 14 (6 table names + 6 view names + 2 clustering configs)  
**Files Updated**: 3 (variables.tf, bigquery.tf, tfvars.example)  

All BigQuery resource names are now fully dynamic! 🚀
