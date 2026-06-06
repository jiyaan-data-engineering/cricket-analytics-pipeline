# ✅ Terraform GCS Buckets - Refactored (NO Hardcoding)

**Updated Architecture: References config.yaml, Single Source of Truth**

---

## 🎯 Approach

Instead of hardcoding bucket names and configurations in Terraform, the refactored `terraform/gcs.tf`:

✅ **References config.yaml** for bucket names  
✅ **References variables.tf** for overrides  
✅ **Single source of truth** - all configs in `config.yaml`  
✅ **No duplication** - config file is central  
✅ **Easy maintenance** - change config once, Terraform uses it  

---

## 📁 File References

### Configuration File (Source of Truth)
```
config/config.yaml
```

Section:
```yaml
gcs:
  raw_bucket: "cricket-raw-data"
  raw_prefix: "batting/"
  template_bucket: "cricket-analytics-dataflow-templates"
  temp_bucket: "cricket-analytics-dataflow-temp"
```

### Terraform File (References Config)
```
terraform/gcs.tf
```

Reads config:
```hcl
locals {
  config = yamldecode(file("${path.module}/../config/config.yaml"))
  gcs_config = local.config.gcs
  
  # Use config values, with Terraform overrides allowed
  raw_bucket_name = var.gcs_raw_bucket_name != "" ? 
    var.gcs_raw_bucket_name : 
    local.gcs_config.raw_bucket
}
```

---

## 🏗️ Architecture

```
config/config.yaml
├─ gcs section with bucket names
└─ Single source of truth for all bucket configs

terraform/gcs.tf
├─ Reads config/config.yaml
├─ Loads bucket names from config
├─ Allows overrides via terraform.tfvars
└─ Creates all 3 GCS buckets

terraform/main.tf
├─ Removed hardcoded GCS bucket definitions
├─ References gcs.tf resources
└─ Comments point to gcs.tf

terraform/variables.tf
├─ Allows bucket name overrides
├─ Optional - use config.yaml by default
└─ Terraform.tfvars can override
```

---

## 🔄 Configuration Hierarchy

```
1. config/config.yaml (default)
   ↓
2. terraform/variables.tf (override capability)
   ↓
3. terraform/terraform.tfvars (actual values)
   ↓
4. terraform/gcs.tf (uses above)
   ↓
5. GCS buckets created
```

---

## 📊 Before vs After

### Before (Hardcoded in main.tf)
```hcl
resource "google_storage_bucket" "raw_data" {
  name = var.gcs_raw_bucket_name  # No reference to config
  # ... other settings hardcoded
}

resource "google_storage_bucket" "dataflow_templates" {
  name = var.gcs_templates_bucket_name  # Duplicate bucket creation
  # ... other settings hardcoded
}
```

### After (References config.yaml)
```hcl
locals {
  config = yamldecode(file("${path.module}/../config/config.yaml"))
  gcs_config = local.config.gcs
  
  raw_bucket_name = var.gcs_raw_bucket_name != "" ? 
    var.gcs_raw_bucket_name : 
    local.gcs_config.raw_bucket  # Uses config.yaml!
}

resource "google_storage_bucket" "raw_data" {
  name = local.raw_bucket_name  # From config.yaml
  description = "Source: config/config.yaml (gcs.raw_bucket)"
}
```

---

## ✨ Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Source of Truth** | variables.tf | config.yaml |
| **Config Location** | Terraform vars | YAML file |
| **Easy Updates** | Edit TF vars | Edit config.yaml |
| **Reusability** | TF only | Both TF + ingestion script |
| **Maintainability** | Lower | Higher |
| **Duplication** | High | None |

---

## 🚀 3 GCS Buckets Created

### 1. Raw Data Bucket
```yaml
# From config.yaml
raw_bucket: "cricket-raw-data"
raw_prefix: "batting/"
```

**Terraform**:
```hcl
resource "google_storage_bucket" "raw_data" {
  name = local.raw_bucket_name  # From config
  description = "Source: config/config.yaml (gcs.raw_bucket)"
  
  # Lifecycle: 90-day retention (from variables)
  lifecycle {
    rule {
      age = var.bq_table_expiration_days
    }
  }
}
```

**Purpose**: Landing zone for CSV files from ingestion

---

### 2. Dataflow Templates Bucket
```yaml
# From config.yaml
template_bucket: "cricket-analytics-dataflow-templates"
```

**Terraform**:
```hcl
resource "google_storage_bucket" "dataflow_templates" {
  name = local.templates_bucket_name  # From config
  description = "Source: config/config.yaml (gcs.template_bucket)"
  
  versioning {
    enabled = true  # Keep version history
  }
}
```

**Purpose**: Stores Dataflow Flex Template Docker images

---

### 3. Dataflow Temp Bucket
```yaml
# From config.yaml
temp_bucket: "cricket-analytics-dataflow-temp"
```

**Terraform**:
```hcl
resource "google_storage_bucket" "dataflow_temp" {
  name = local.temp_bucket_name  # From config
  description = "Source: config/config.yaml (gcs.temp_bucket)"
  
  # Lifecycle: 7-day cleanup
  lifecycle {
    rule {
      age = 7  # Auto-cleanup after 7 days
    }
  }
}
```

**Purpose**: Temporary working directory for Dataflow jobs

---

## 📋 Files Updated

✅ **terraform/gcs.tf** - NEW file (refactored)  
✅ **terraform/main.tf** - Updated to remove hardcoded GCS buckets  
✅ **TERRAFORM_GCS_REFACTORED.md** - This documentation  

---

## 🎯 Key Points

✨ **Single Source of Truth** - config.yaml is the main config  
✨ **Terraform Override** - Can override via terraform.tfvars  
✨ **No Hardcoding** - Bucket names in config, not TF code  
✨ **Shared Config** - Both ingestion script and TF use config.yaml  
✨ **Easy Maintenance** - Change bucket names once in config  

---

## 🚀 Deployment Workflow

### Update Bucket Names
1. Edit `config/config.yaml`
   ```yaml
   gcs:
     raw_bucket: "my-raw-bucket"  # Change here
     template_bucket: "my-templates"
     temp_bucket: "my-temp"
   ```

2. Run Terraform
   ```bash
   terraform apply
   ```

3. Buckets created with new names automatically!

### Override via Terraform (Optional)
1. Edit `terraform/terraform.tfvars`
   ```hcl
   gcs_raw_bucket_name = "override-raw-bucket"
   ```

2. Run Terraform
   ```bash
   terraform apply  # Uses override value
   ```

---

## 📊 Configuration Summary

```
config.yaml contains:
├─ raw_bucket: "cricket-raw-data"
├─ raw_prefix: "batting/"
├─ template_bucket: "cricket-analytics-dataflow-templates"
└─ temp_bucket: "cricket-analytics-dataflow-temp"

gcs.tf reads above and creates:
├─ google_storage_bucket.raw_data
├─ google_storage_bucket.dataflow_templates
└─ google_storage_bucket.dataflow_temp

Outputs:
├─ raw_bucket_name
├─ templates_bucket_name
├─ temp_bucket_name
└─ gcs_summary (all buckets from config)
```

---

## ✅ Benefits Summary

| Feature | Benefit |
|---------|---------|
| **References config.yaml** | Single point of change |
| **Allows TF overrides** | Flexibility when needed |
| **No hardcoding** | Cleaner Terraform code |
| **Shared config** | Ingestion script uses same config |
| **Easy maintenance** | Update config, Terraform applies |
| **Consistent** | Same pattern as BigQuery refactor |

---

## 📚 Related Files

| File | Purpose |
|------|---------|
| `config/config.yaml` | GCS bucket names (source of truth) |
| `terraform/gcs.tf` | GCS bucket resources |
| `terraform/main.tf` | Updated to reference gcs.tf |
| `terraform/variables.tf` | Optional overrides |
| `ingestion/fetch_batting_rankings.py` | Uses config.yaml for bucket names |

---

**Status**: ✅ Refactored - No Hardcoding  
**Pattern**: Same as BigQuery refactoring  
**Architecture**: Single source of truth (config.yaml)  

This is the **recommended approach** for managing GCS buckets with Terraform! 🎉
