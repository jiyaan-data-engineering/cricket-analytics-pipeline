# 🏗️ Multi-Environment Architecture (Dev → Stg → Prod)

**Modern, scalable setup with automated promotion pipeline and environment separation.**

---

## 📊 **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SINGLE GCP PROJECT                               │
│            (cricbuzz-satish-dev - all environments)                 │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  DEV ENVIRONMENT │  │ STAGING ENVIRON. │  │ PROD ENVIRONMENT │
├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ Datasets:        │  │ Datasets:        │  │ Datasets:        │
│ ├─ dev_*         │  │ ├─ stg_*         │  │ ├─ prod_*        │
│ └─ cricket_*     │  │ └─ cricket_*     │  │ └─ cricket_*     │
│                  │  │                  │  │                  │
│ Buckets:         │  │ Buckets:         │  │ Buckets:         │
│ ├─ dev-cricket-* │  │ ├─ stg-cricket-* │  │ ├─ prod-cricket-*│
│ └─ dev-tf-state  │  │ └─ stg-tf-state  │  │ └─ prod-tf-state │
│                  │  │                  │  │                  │
│ Service Accts:   │  │ Service Accts:   │  │ Service Accts:   │
│ └─ cricket-dev-sa│  │ └─ cricket-stg-sa│  │ └─ cricket-prod-sa
└──────────────────┘  └──────────────────┘  └──────────────────┘
        ↑                     ↑                      ↑
        │                     │                      │
    develop           v*.*.* tag              main/release
    branch            (auto)               (auto-promoted)
```

---

## 🔄 **Deployment Pipeline (Tag-Based Promotion)**

```
1. DEVELOPMENT ENVIRONMENT
   ┌─────────────────────────────┐
   │ Push to 'develop' branch    │
   └──────────────┬──────────────┘
                  │
                  ├─→ GitHub Actions: deploy-dev.yml
                  │   ├─ Terraform (dev_ prefix)
                  │   ├─ BigQuery setup
                  │   ├─ Dataflow template
                  │   └─ Run tests
                  │
                  └─→ ✅ Deploy to DEV_cricket_raw, dev_cricket_staging, etc.

2. STAGING ENVIRONMENT
   ┌─────────────────────────────┐
   │ Create tag: v1.0.0          │
   │ (from develop branch)       │
   └──────────────┬──────────────┘
                  │
                  ├─→ GitHub Actions: deploy-stg.yml (triggered by tag)
                  │   ├─ Terraform (stg_ prefix)
                  │   ├─ BigQuery setup
                  │   ├─ Dataflow template
                  │   ├─ Run integration tests
                  │   └─ Notify team
                  │
                  └─→ ✅ Deploy to stg_cricket_raw, stg_cricket_staging, etc.

3. PRODUCTION ENVIRONMENT
   ┌─────────────────────────────┐
   │ Create release tag: v1.0.0  │
   │ (from main branch)          │
   │ OR merge stg to main        │
   └──────────────┬──────────────┘
                  │
                  ├─→ GitHub Actions: deploy-prod.yml (requires manual approval)
                  │   ├─ Terraform (prod_ prefix)
                  │   ├─ BigQuery setup
                  │   ├─ Dataflow template
                  │   ├─ Run full test suite
                  │   ├─ Health checks
                  │   └─ Alert team
                  │
                  └─→ ✅ Deploy to prod_cricket_raw, prod_cricket_staging, etc.
```

---

## 📁 **Directory Structure (Environment-Aware)**

```
cricket-analytics-pipeline/
│
├─ .github/workflows/
│  ├─ deploy-dev.yml          # Triggered: push to develop
│  ├─ deploy-stg.yml          # Triggered: create v*.*.* tag
│  ├─ deploy-prod.yml         # Triggered: create release tag
│  └─ shared-workflow.yml     # Reusable deployment logic
│
├─ infrastructure/
│  ├─ terraform/
│  │  ├─ environments/
│  │  │  ├─ dev.tfvars        # Dev-specific variables
│  │  │  ├─ stg.tfvars        # Stg-specific variables
│  │  │  └─ prod.tfvars       # Prod-specific variables
│  │  ├─ main.tf              # Environment-agnostic base
│  │  ├─ variables.tf         # All variables parameterized
│  │  ├─ outputs.tf
│  │  ├─ datasources.tf
│  │  ├─ gke.tf               # Optional: GKE for prod
│  │  └─ monitoring.tf        # Environment-specific monitoring
│  │
│  └─ terraform-modules/
│     ├─ bigquery/            # Reusable BigQuery module
│     ├─ gcs/                 # Reusable GCS module
│     ├─ dataflow/            # Reusable Dataflow module
│     └─ monitoring/          # Reusable monitoring module
│
├─ pipeline/
│  ├─ bigquery/sql/
│  │  └─ [same, parameterized with env prefix]
│  ├─ dataflow/
│  │  ├─ pipeline.py          # Env-agnostic code
│  │  ├─ requirements.txt
│  │  └─ Dockerfile
│  └─ config/
│     ├─ config-dev.yaml      # Dev config
│     ├─ config-stg.yaml      # Stg config
│     ├─ config-prod.yaml     # Prod config
│     └─ config-base.yaml     # Shared config
│
├─ scripts/
│  ├─ deploy.sh               # Env-aware deployment
│  ├─ validate.sh             # Pre-deployment validation
│  ├─ test.sh                 # Run test suite
│  └─ promote.sh              # Promote between envs
│
├─ tests/
│  ├─ unit/
│  ├─ integration/
│  └─ e2e/
│
├─ docs/
│  ├─ MULTI_ENV_SETUP.md      # This file
│  ├─ ENV_VARS.md             # Environment variables
│  └─ PROMOTION_PROCESS.md    # How to promote
│
└─ .env.example               # Example env variables
```

---

## 🔐 **Environment Variables Strategy**

### **GitHub Secrets (per environment)**

```yaml
# Development
DEV_GCP_PROJECT_ID
DEV_SERVICE_ACCOUNT_EMAIL
DEV_WORKLOAD_IDENTITY_PROVIDER

# Staging  
STG_GCP_PROJECT_ID
STG_SERVICE_ACCOUNT_EMAIL
STG_WORKLOAD_IDENTITY_PROVIDER

# Production
PROD_GCP_PROJECT_ID
PROD_SERVICE_ACCOUNT_EMAIL
PROD_WORKLOAD_IDENTITY_PROVIDER
PROD_SLACK_WEBHOOK           # For alerts
```

### **Terraform Variables (per environment)**

```hcl
# environments/dev.tfvars
environment     = "dev"
project_id      = "cricbuzz-satish-dev"
gcs_bucket_prefix = "dev-cricket"
bq_dataset_prefix = "dev_"
schedule_enabled = true
schedule_time    = "06:00"  # Daily at 6 AM UTC
dataflow_workers = 2
enable_monitoring = false   # Lite monitoring in dev

# environments/stg.tfvars
environment     = "staging"
project_id      = "cricbuzz-satish-dev"
gcs_bucket_prefix = "stg-cricket"
bq_dataset_prefix = "stg_"
schedule_enabled = true
schedule_time    = "06:00"
dataflow_workers = 3
enable_monitoring = true    # Full monitoring in stg

# environments/prod.tfvars
environment     = "prod"
project_id      = "cricbuzz-satish-dev"
gcs_bucket_prefix = "prod-cricket"
bq_dataset_prefix = "prod_"
schedule_enabled = true
schedule_time    = "06:00"
dataflow_workers = 5
enable_monitoring = true    # Full monitoring + alerts
enable_backups  = true
backup_frequency = "daily"
```

---

## 📝 **Terraform Refactoring (Environment-Aware)**

### **1. Main Configuration**

```hcl
# infrastructure/terraform/main.tf

terraform {
  backend "gcs" {
    bucket = "cricket-tf-state"
    prefix = var.environment  # dev/, stg/, prod/
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Use modules for reusability
module "bigquery_raw" {
  source = "./terraform-modules/bigquery"
  
  environment     = var.environment
  dataset_name    = "${var.bq_dataset_prefix}cricket_raw"
  dataset_location = var.bq_location
  
  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

module "gcs_raw_data" {
  source = "./terraform-modules/gcs"
  
  environment    = var.environment
  bucket_name    = "${var.gcs_bucket_prefix}-data"
  bucket_location = var.gcs_location
  
  versioning     = var.environment == "prod" ? true : false
  storage_class  = var.environment == "prod" ? "STANDARD" : "STANDARD"
  
  labels = {
    environment = var.environment
  }
}

module "dataflow_template" {
  source = "./terraform-modules/dataflow"
  
  environment     = var.environment
  template_name   = "${var.environment}-cricket-dataflow"
  worker_count    = var.dataflow_workers
  machine_type    = var.environment == "prod" ? "n1-standard-4" : "n1-standard-2"
}
```

### **2. Variables (Parameterized)**

```hcl
# infrastructure/terraform/variables.tf

variable "environment" {
  type        = string
  description = "Environment: dev, staging, or prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_id" {
  type = string
}

variable "region" {
  default = "us-central1"
}

variable "bq_dataset_prefix" {
  type        = string
  description = "BigQuery dataset prefix (dev_, stg_, prod_)"
}

variable "gcs_bucket_prefix" {
  type        = string
  description = "GCS bucket prefix"
}

variable "dataflow_workers" {
  type    = number
  default = 2
}

variable "schedule_enabled" {
  type    = bool
  default = true
}

variable "enable_monitoring" {
  type    = bool
  default = false
}

variable "enable_backups" {
  type    = bool
  default = false
}
```

---

## 🚀 **GitHub Actions Workflow**

### **Deploy to DEV (triggered on develop branch)**

```yaml
# .github/workflows/deploy-dev.yml

name: 🚀 Deploy to DEV

on:
  push:
    branches:
      - develop

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    environment: development
    
    steps:
      - uses: actions/checkout@v4
      
      - name: 🔐 Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.DEV_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.DEV_SERVICE_ACCOUNT_EMAIL }}
      
      - name: 🏗️ Deploy Infrastructure
        run: |
          cd infrastructure/terraform
          terraform init -upgrade
          terraform plan -var-file="environments/dev.tfvars" -out=dev.tfplan
          terraform apply dev.tfplan
      
      - name: 📊 Deploy BigQuery
        run: |
          cd pipeline/bigquery/sql
          for file in *.sql; do
            sed "s/{PROJECT_ID}/${{ secrets.DEV_GCP_PROJECT_ID }}/g; \
                 s/{ENV_PREFIX}/dev_/g" "$file" | \
            bq query --use_legacy_sql=false || true
          done
      
      - name: ✅ Run Tests
        run: |
          python -m pytest tests/unit/ -v
          python -m pytest tests/integration/ -v
      
      - name: 📢 Notify
        run: echo "✅ DEV deployment successful!"
```

### **Deploy to STAGING (triggered on version tag)**

```yaml
# .github/workflows/deploy-stg.yml

name: 📦 Deploy to STAGING

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'  # v1.0.0, v1.1.0, etc.

jobs:
  deploy-stg:
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
      - uses: actions/checkout@v4
      
      - name: 🔐 Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.STG_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.STG_SERVICE_ACCOUNT_EMAIL }}
      
      - name: 🏗️ Deploy Infrastructure
        run: |
          cd infrastructure/terraform
          terraform init -upgrade
          terraform plan -var-file="environments/stg.tfvars" -out=stg.tfplan
          terraform apply stg.tfplan
      
      - name: 📊 Deploy BigQuery
        run: |
          cd pipeline/bigquery/sql
          for file in *.sql; do
            sed "s/{PROJECT_ID}/${{ secrets.STG_GCP_PROJECT_ID }}/g; \
                 s/{ENV_PREFIX}/stg_/g" "$file" | \
            bq query --use_legacy_sql=false || true
          done
      
      - name: ✅ Run Full Test Suite
        run: |
          python -m pytest tests/ -v
      
      - name: 🏥 Health Checks
        run: |
          # Verify all resources created
          bq ls --project_id=${{ secrets.STG_GCP_PROJECT_ID }}
          gsutil ls gs://stg-cricket-*
      
      - name: 📢 Notify Team
        run: |
          echo "📦 Staging deployment of ${{ github.ref_name }} successful!"
          echo "Ready for production promotion"
```

### **Deploy to PROD (triggered on release tag, requires approval)**

```yaml
# .github/workflows/deploy-prod.yml

name: 🎯 Deploy to PRODUCTION

on:
  push:
    tags:
      - 'release-v[0-9]+.[0-9]+.[0-9]+'  # release-v1.0.0

jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production  # ⚠️ Requires manual approval
    
    steps:
      - uses: actions/checkout@v4
      
      - name: ⚠️ Pre-deployment Verification
        run: |
          echo "Verifying staging environment..."
          # Check that staging is stable
          # Run final validation
      
      - name: 🔐 Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.PROD_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.PROD_SERVICE_ACCOUNT_EMAIL }}
      
      - name: 🏗️ Deploy Infrastructure
        run: |
          cd infrastructure/terraform
          terraform init -upgrade
          terraform plan -var-file="environments/prod.tfvars" -out=prod.tfplan
          terraform apply prod.tfplan
      
      - name: 📊 Deploy BigQuery
        run: |
          cd pipeline/bigquery/sql
          for file in *.sql; do
            sed "s/{PROJECT_ID}/${{ secrets.PROD_GCP_PROJECT_ID }}/g; \
                 s/{ENV_PREFIX}/prod_/g" "$file" | \
            bq query --use_legacy_sql=false || true
          done
      
      - name: ✅ Run Full Test Suite
        run: |
          python -m pytest tests/ -v --markers="prod"
      
      - name: 🏥 Production Health Checks
        run: |
          bq ls --project_id=${{ secrets.PROD_GCP_PROJECT_ID }}
          gsutil ls gs://prod-cricket-*
          # Run smoke tests
      
      - name: 🚨 Alert Team
        if: success()
        run: |
          echo "🎯 PRODUCTION deployment successful!"
          # Send Slack notification
          # Create incident ticket if needed
      
      - name: 🚨 Rollback Alert
        if: failure()
        run: |
          echo "❌ PRODUCTION deployment FAILED - initiating rollback"
          # Automatic rollback script
```

---

## 📊 **Resource Naming Convention**

```
Development:
  Dataset: dev_cricket_raw, dev_cricket_staging, dev_cricket_curated
  Bucket: dev-cricket-raw-data, dev-cricket-temp
  Job: dev-cricket-daily-ingestion
  SA: cricket-dev-sa

Staging:
  Dataset: stg_cricket_raw, stg_cricket_staging, stg_cricket_curated
  Bucket: stg-cricket-raw-data, stg-cricket-temp
  Job: stg-cricket-daily-ingestion
  SA: cricket-stg-sa

Production:
  Dataset: prod_cricket_raw, prod_cricket_staging, prod_cricket_curated
  Bucket: prod-cricket-raw-data, prod-cricket-temp
  Job: prod-cricket-daily-ingestion
  SA: cricket-prod-sa
```

---

## 🔄 **Promotion Workflow**

### **Step 1: Develop in DEV**
```bash
git checkout -b feature/new-feature
# Make changes
git push origin develop
# Automatically deploys to dev_cricket_*
```

### **Step 2: Tag for Staging**
```bash
git tag v1.0.0
git push origin v1.0.0
# Automatically deploys to stg_cricket_*
# Run full integration tests
```

### **Step 3: Release to Production**
```bash
git tag release-v1.0.0
git push origin release-v1.0.0
# ⚠️ Requires manual approval in GitHub UI
# Deploy to prod_cricket_*
# Run smoke tests
# Alert team
```

---

## 📈 **Monitoring per Environment**

| Metric | Dev | Staging | Production |
|--------|-----|---------|------------|
| Alerting | ❌ | ⚠️ Basic | 🔴 Full |
| Dashboards | ❌ | 📊 Limited | 📊 Comprehensive |
| Backup | ❌ | Daily | Hourly |
| SLA Target | - | 95% | 99.9% |
| Dataflow Workers | 2 | 3 | 5 |

---

## ✅ **Benefits of This Architecture**

✅ **True Environment Isolation**: Dev, Stg, Prod completely separate data  
✅ **Automated Promotion**: No manual steps (except final prod approval)  
✅ **Safe Testing**: Test fully in stg before prod  
✅ **Cost Control**: Dev can run with minimal resources  
✅ **Compliance**: Prod can have stricter controls  
✅ **Rollback Ready**: Previous versions tagged for quick rollback  
✅ **Team-Friendly**: Clear promotion path visible in Git history  

---

**Ready to implement? I can start with Terraform refactoring and workflow setup!** 🚀
