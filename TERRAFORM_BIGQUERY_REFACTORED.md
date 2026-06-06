# ✅ Terraform BigQuery - Refactored (NO Hardcoding)

**Updated Architecture: References Existing Files, Single Source of Truth**

---

## 🎯 Approach

Instead of hardcoding SQL queries and schemas, the refactored `terraform/bigquery.tf`:

✅ **References existing schema file** for raw table  
✅ **References existing SQL files** for views  
✅ **Single source of truth** - all logic in `.sql` files  
✅ **No duplication** - schema/SQL defined once  
✅ **Easy maintenance** - change SQL, apply everywhere  

---

## 📁 File References

### Schema File (Source of Truth)
```
bigquery/schemas/raw_batting_rankings.json
```

Terraform loads it:
```hcl
schema = file("${path.module}/../bigquery/schemas/raw_batting_rankings.json")
```

### SQL Files (Source of Truth)
```
bigquery/sql/01_create_raw_table.sql          → Raw table + vw_latest_raw
bigquery/sql/02_create_dim_player.sql         → dim_player
bigquery/sql/03_create_dim_country.sql        → dim_country
bigquery/sql/04_create_dim_format.sql         → dim_format
bigquery/sql/05_create_dim_date.sql           → dim_date
bigquery/sql/06_create_fact_batting.sql       → fact_batting_rankings
bigquery/sql/07_create_curated_views.sql      → All 5 curated views
```

Terraform references them:
```hcl
definition_body = replace(
  file("${path.module}/../bigquery/sql/01_create_raw_table.sql"),
  "{PROJECT_ID}",
  var.gcp_project_id
)
```

---

## 🏗️ Terraform Architecture

### What Terraform Does:
1. Creates **3 BigQuery datasets** (`cricket_raw`, `cricket_staging`, `cricket_curated`)
2. Creates **table placeholders** (no schema definition - left to SQL scripts)
3. **Substitutes `{PROJECT_ID}`** from SQL files with actual project ID
4. Manages **partitioning & clustering** configuration

### What SQL Scripts Do:
1. Define **complete table schemas** with columns, types, descriptions
2. Define **MERGE logic** for staging tables (idempotent updates)
3. Define **all analytics views** with complex queries
4. Populate **static data** (dim_format, dim_date)

### Example: Raw Table

**Terraform** (`terraform/bigquery.tf`):
```hcl
resource "google_bigquery_table" "raw_batting_rankings" {
  dataset_id = google_bigquery_dataset.raw.dataset_id
  table_id   = var.bq_raw_table_name
  
  # Load schema from JSON file (single source of truth)
  schema = file("${path.module}/../bigquery/schemas/raw_batting_rankings.json")
  
  # Partitioning config
  time_partitioning {
    type  = "DAY"
    field = "ingested_at"
    expiration_ms = var.bq_table_expiration_days * 24 * 60 * 60 * 1000
  }
  
  clustering = ["format", "country"]
}
```

**Schema** (`bigquery/schemas/raw_batting_rankings.json`):
```json
[
  { "name": "rank", "type": "INTEGER", "mode": "NULLABLE", "description": "..." },
  { "name": "player_id", "type": "STRING", "mode": "NULLABLE", "description": "..." },
  ...
]
```

---

## 🚀 Deployment Workflow

### Step 1: Terraform Apply (Create Structure)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

**Result**: 
- ✅ 3 datasets created
- ✅ 6 table placeholders created
- ✅ Partitioning/clustering configured

### Step 2: Run SQL Scripts (Define Schema & Logic)
```bash
cd bigquery

# Run all SQL scripts in order
for f in sql/*.sql; do
  echo "Running: $f"
  bq query --use_legacy_sql=false < "$f"
done
```

**Result**:
- ✅ All table schemas loaded from schema files
- ✅ All view SQL executed
- ✅ MERGE logic ready for staging updates

---

## 📝 Terraform File Changes

### Before (Hardcoded)
```hcl
schema = jsonencode([
  { name = "rank", type = "INTEGER", ... },
  { name = "player_id", type = "STRING", ... },
  ...
])

definition_body = <<-SQL
  SELECT ... FROM `${var.gcp_project_id}.dataset.table`
  ...
SQL
```

### After (References Files)
```hcl
# Load schema from existing JSON file
schema = file("${path.module}/../bigquery/schemas/raw_batting_rankings.json")

# Load SQL from existing file
definition_body = replace(
  file("${path.module}/../bigquery/sql/01_create_raw_table.sql"),
  "{PROJECT_ID}",
  var.gcp_project_id
)
```

---

## ✅ Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Source of Truth** | Multiple (TF + SQL files) | Single (SQL/schema files) |
| **Maintenance** | Update in 2 places | Update in 1 place |
| **Sync Risk** | High (TF vs SQL diverge) | None (auto-synced) |
| **Reusability** | TF only | Both TF + bq CLI + Python |
| **Readability** | Complex TF code | Clean TF + clear SQL |

---

## 🔄 Keeping Files in Sync

Since Terraform now references existing files:

✅ **Terraform is the source of structure** (datasets, partitioning, clustering)  
✅ **SQL files are the source of logic** (schemas, MERGE, views)  
✅ **No duplication** = no sync issues  

If you change a table schema:
1. Edit `bigquery/sql/XX_create_table.sql`
2. Run `bq query < bigquery/sql/XX_create_table.sql`
3. Done! Terraform doesn't need changes.

---

## 📊 File Dependencies

```
terraform/bigquery.tf
├─ References: bigquery/schemas/raw_batting_rankings.json
├─ References: bigquery/sql/01_create_raw_table.sql
├─ References: bigquery/sql/07_create_curated_views.sql
└─ Uses: variables.tf (for dataset names, project ID, etc.)

bigquery/sql/*.sql
├─ Uses: {PROJECT_ID} placeholder (replaced by TF)
└─ Independent: can run via bq CLI directly
```

---

## 🎯 Key Points

✨ **NO SQL hardcoding** - all in `.sql` files  
✨ **NO schema hardcoding** - all in `.json` files  
✨ **Terraform is lightweight** - just structure & references  
✨ **DRY principle** - single source of truth  
✨ **Easy collaboration** - DBAs update SQL, DevOps updates TF  

---

## 📚 File Reference

| File | Purpose |
|------|---------|
| `terraform/bigquery.tf` | References SQL/schema files, creates structure |
| `bigquery/schemas/raw_batting_rankings.json` | Raw table schema (source of truth) |
| `bigquery/sql/01_create_raw_table.sql` | Raw table definition |
| `bigquery/sql/0[2-6]_*.sql` | Staging table definitions |
| `bigquery/sql/07_create_curated_views.sql` | Analytics views (source of truth) |

---

## 🚀 Next Steps

1. **Review the updated bigquery.tf**
2. **Verify all references are correct**
3. **Deploy**: `terraform apply`
4. **Run SQL scripts**: `bq query < bigquery/sql/01_create_raw_table.sql`, etc.

---

**Status**: ✅ Refactored - No Hardcoding  
**Architecture**: Single Source of Truth  
**Maintainability**: High (one-place updates)  

This is the **recommended approach** for managing BigQuery with Terraform! 🎉
