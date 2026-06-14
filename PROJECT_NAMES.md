# 🎯 GCP Project Names for All Environments

## Three Separate GCP Projects (Recommended)

One dedicated GCP project for each environment with meaningful names.

---

## 🟢 Development Environment (DEV)

**GCP Project ID:** `cricket-analytics-dev`

**Project Number:** (Get from GCP Console → Project Settings)

### GCS Buckets:
```
gs://cricket-raw-data-dev
gs://cricket-dataflow-templates-dev
gs://cricket-dataflow-temp-dev
gs://cricket-tf-state-dev
```

### BigQuery Datasets:
```
cricket_raw
cricket_staging
cricket_curated
cricket_audit_logs
```

### Service Accounts:
```
cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com
cricket-cloud-function-sa@cricket-analytics-dev.iam.gserviceaccount.com
cricket-cloud-run-sa@cricket-analytics-dev.iam.gserviceaccount.com
cricket-composer-sa@cricket-analytics-dev.iam.gserviceaccount.com
```

### Terraform Config:
```
infrastructure/terraform/environments/dev.tfvars
```

### GitHub Secrets (for DEV):
```
DEV_GCP_PROJECT_ID = cricket-analytics-dev
DEV_SERVICE_ACCOUNT_EMAIL = cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com
DEV_WORKLOAD_IDENTITY_PROVIDER = projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
DEV_TF_STATE_BUCKET = cricket-tf-state-dev
```

---

## 🟡 Staging Environment (STG)

**GCP Project ID:** `cricket-analytics-stg`

**Project Number:** (Get from GCP Console → Project Settings)

### GCS Buckets:
```
gs://cricket-raw-data-stg
gs://cricket-dataflow-templates-stg
gs://cricket-dataflow-temp-stg
gs://cricket-tf-state-stg
```

### BigQuery Datasets:
```
cricket_raw
cricket_staging
cricket_curated
cricket_audit_logs
```

### Service Accounts:
```
cricket-dataflow-sa@cricket-analytics-stg.iam.gserviceaccount.com
cricket-cloud-function-sa@cricket-analytics-stg.iam.gserviceaccount.com
cricket-cloud-run-sa@cricket-analytics-stg.iam.gserviceaccount.com
cricket-composer-sa@cricket-analytics-stg.iam.gserviceaccount.com
```

### Terraform Config:
```
infrastructure/terraform/environments/stg.tfvars
```

### GitHub Secrets (for STG):
```
STG_GCP_PROJECT_ID = cricket-analytics-stg
STG_SERVICE_ACCOUNT_EMAIL = cricket-dataflow-sa@cricket-analytics-stg.iam.gserviceaccount.com
STG_WORKLOAD_IDENTITY_PROVIDER = projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
STG_TF_STATE_BUCKET = cricket-tf-state-stg
```

---

## 🔴 Production Environment (PROD)

**GCP Project ID:** `cricket-analytics-prod`

**Project Number:** (Get from GCP Console → Project Settings)

### GCS Buckets:
```
gs://cricket-raw-data-prod
gs://cricket-dataflow-templates-prod
gs://cricket-dataflow-temp-prod
gs://cricket-tf-state-prod
```

### BigQuery Datasets:
```
cricket_raw
cricket_staging
cricket_curated
cricket_audit_logs
```

### Service Accounts:
```
cricket-dataflow-sa@cricket-analytics-prod.iam.gserviceaccount.com
cricket-cloud-function-sa@cricket-analytics-prod.iam.gserviceaccount.com
cricket-cloud-run-sa@cricket-analytics-prod.iam.gserviceaccount.com
cricket-composer-sa@cricket-analytics-prod.iam.gserviceaccount.com
```

### Terraform Config:
```
infrastructure/terraform/environments/prod.tfvars
```

### GitHub Secrets (for PROD):
```
PROD_GCP_PROJECT_ID = cricket-analytics-prod
PROD_SERVICE_ACCOUNT_EMAIL = cricket-dataflow-sa@cricket-analytics-prod.iam.gserviceaccount.com
PROD_WORKLOAD_IDENTITY_PROVIDER = projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
PROD_TF_STATE_BUCKET = cricket-tf-state-prod
```

---

## Summary Table

| Aspect | Development | Staging | Production |
|--------|-------------|---------|-----------|
| **GCP Project** | cricket-analytics-dev | cricket-analytics-stg | cricket-analytics-prod |
| **Dataset Names** | cricket_raw, cricket_staging, cricket_curated, cricket_audit_logs | Same | Same |
| **Bucket Prefix** | cricket-*-dev | cricket-*-stg | cricket-*-prod |
| **Service Accounts** | 4 per project | 4 per project | 4 per project |
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
   Deploy to cricket-analytics-dev (DEV)
   
   Create v1.0.0 tag
         ↓
   Deploy to cricket-analytics-stg (STAGING)
   
   Create release-v1.0.0 tag
         ↓
   Deploy to cricket-analytics-prod (PRODUCTION)
```

Each environment has its **own dedicated GCP project** with completely isolated resources.

---

## Commands to Use

### Deploy to DEV:
```bash
gcloud config set project cricket-analytics-dev
terraform apply -var-file="environments/dev.tfvars"
```

### Deploy to STAGING:
```bash
gcloud config set project cricket-analytics-stg
terraform apply -var-file="environments/stg.tfvars"
```

### Deploy to PRODUCTION:
```bash
gcloud config set project cricket-analytics-prod
terraform apply -var-file="environments/prod.tfvars"
```

Each command targets its **own GCP project** (`-dev`, `-stg`, `-prod`).

---

## Benefits of Separate Projects per Environment

✅ **Complete Isolation** - No risk of cross-environment data leaks  
✅ **Independent Billing** - Track costs per environment separately  
✅ **Separate IAM** - Different access controls for each environment  
✅ **Environment Protection** - Production project gets stricter controls  
✅ **Clear Boundaries** - No namespace conflicts or naming issues  
✅ **Organizational Clarity** - Easy to understand project structure  

---

**Remember:** Three separate GCP projects:
- 🟢 **Development**: `cricket-analytics-dev`
- 🟡 **Staging**: `cricket-analytics-stg`
- 🔴 **Production**: `cricket-analytics-prod`
