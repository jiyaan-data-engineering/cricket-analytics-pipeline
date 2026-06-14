# 🎯 GCP Project Names for All Environments

## Single GCP Project with Namespaced Resources

**Main GCP Project:** `cricbuzz-satish-dev`

All 3 environments (dev, staging, prod) are created within this SINGLE project using namespace prefixes.

---

## Development Environment (DEV)

**Project ID:** `cricbuzz-satish-dev`

**Namespace Prefix:** `dev_` (datasets) and `dev-` (buckets)

### GCS Buckets:
```
gs://dev-cricket-raw-data
gs://dev-cricket-dataflow-templates
gs://dev-cricket-dataflow-temp
gs://dev-cricket-tf-state
```

### BigQuery Datasets:
```
dev_cricket_raw
dev_cricket_staging
dev_cricket_curated
dev_cricket_audit_logs
```

### Service Account:
```
cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com
```

### Terraform Config:
```
infrastructure/terraform/environments/dev.tfvars
```

---

## Staging Environment (STG)

**Project ID:** `cricbuzz-satish-dev` (SAME PROJECT)

**Namespace Prefix:** `stg_` (datasets) and `stg-` (buckets)

### GCS Buckets:
```
gs://stg-cricket-raw-data
gs://stg-cricket-dataflow-templates
gs://stg-cricket-dataflow-temp
gs://stg-cricket-tf-state
```

### BigQuery Datasets:
```
stg_cricket_raw
stg_cricket_staging
stg_cricket_curated
stg_cricket_audit_logs
```

### Service Account:
```
cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com (shared)
```

### Terraform Config:
```
infrastructure/terraform/environments/stg.tfvars
```

---

## Production Environment (PROD)

**Project ID:** `cricbuzz-satish-dev` (SAME PROJECT)

**Namespace Prefix:** `prod_` (datasets) and `prod-` (buckets)

### GCS Buckets:
```
gs://prod-cricket-raw-data
gs://prod-cricket-dataflow-templates
gs://prod-cricket-dataflow-temp
gs://prod-cricket-tf-state
```

### BigQuery Datasets:
```
prod_cricket_raw
prod_cricket_staging
prod_cricket_curated
prod_cricket_audit_logs
```

### Service Account:
```
cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com (shared)
```

### Terraform Config:
```
infrastructure/terraform/environments/prod.tfvars
```

---

## Summary Table

| Aspect | Development | Staging | Production |
|--------|-------------|---------|-----------|
| **GCP Project** | cricbuzz-satish-dev | cricbuzz-satish-dev | cricbuzz-satish-dev |
| **Dataset Prefix** | dev_ | stg_ | prod_ |
| **Bucket Prefix** | dev- | stg- | prod- |
| **Service Account** | cricket-dataflow-sa (shared) | cricket-dataflow-sa (shared) | cricket-dataflow-sa (shared) |
| **Dataflow Workers** | 2 | 3 | 5 |
| **Monitoring** | Disabled | Limited | Full |
| **Backups** | No | Daily | Hourly |

---

## How They Work Together

```
GitHub Actions Workflow Push
         ↓
   develop branch
         ↓
   Deploy to DEV
   
   Create v1.0.0 tag
         ↓
   Deploy to STAGING
   
   Create release-v1.0.0 tag
         ↓
   Deploy to PRODUCTION
```

All three deployments go to the **same GCP project** (`cricbuzz-satish-dev`), but use different namespace prefixes to keep resources isolated.

---

## Commands to Use

### Deploy to DEV:
```bash
terraform apply -var-file="environments/dev.tfvars"
```

### Deploy to STAGING:
```bash
terraform apply -var-file="environments/stg.tfvars"
```

### Deploy to PRODUCTION:
```bash
terraform apply -var-file="environments/prod.tfvars"
```

All commands target the **same project** but create namespaced resources (dev_*, stg_*, prod_*).

---

## Benefits of Single Project with Namespaces

✅ **Cost Effective** - One project = lower overhead  
✅ **Easy Management** - All environments in one place  
✅ **Shared Resources** - Service accounts, APIs, billing  
✅ **Clear Isolation** - Prefix naming keeps resources distinct  
✅ **Simple Setup** - No need to manage multiple projects  

---

**Remember:** The project is `cricbuzz-satish-dev` for all environments!
