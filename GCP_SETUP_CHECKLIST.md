# 📋 GCP Setup Checklist for Multi-Environment Deployment

Complete checklist of all GCP resources and configurations needed for dev, staging, and production environments.

---

## 🎯 Overview

You need to set up:
- **1 GCP Project** (cricbuzz-satish-dev) - Used for all 3 environments
- **3 Environments** (dev/stg/prod) - Using namespace prefixes
- **12 Service Accounts** (4 per environment)
- **APIs** - Enable required GCP services
- **Workload Identity** - For GitHub Actions authentication
- **Storage & Data** - GCS buckets and BigQuery datasets
- **IAM Roles** - Proper permissions for each service account

---

## ✅ Phase 1: ONE-TIME SETUP (Single project)

### **1.1 Create GCP Project** (if not already done)
- [ ] Open Google Cloud Console: https://console.cloud.google.com
- [ ] Click "Select a Project" → "New Project"
- [ ] Project name: `cricket-analytics-platform`
- [ ] Note the **Project ID**: `cricbuzz-satish-dev` (or your project ID)
- [ ] Store in safe place - you'll need it repeatedly

**Get Project ID:**
```bash
gcloud config get-value project
# Output: cricbuzz-satish-dev
```

### **1.2 Enable Required APIs**
Enable these APIs in GCP Console or via gcloud:

```bash
gcloud services enable \
  bigquery.googleapis.com \
  storage-api.googleapis.com \
  dataflow.googleapis.com \
  cloudscheduler.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudrun.googleapis.com \
  composer.googleapis.com \
  artifactregistry.googleapis.com \
  eventarc.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  iam.googleapis.com \
  iap.googleapis.com
```

**Verify APIs are enabled:**
```bash
gcloud services list --enabled | grep -E "bigquery|storage|dataflow|scheduler|functions|run|composer"
```

- [ ] BigQuery API ✅
- [ ] Cloud Storage API ✅
- [ ] Dataflow API ✅
- [ ] Cloud Scheduler API ✅
- [ ] Cloud Functions API ✅
- [ ] Cloud Run API ✅
- [ ] Cloud Composer API ✅
- [ ] Artifact Registry API ✅
- [ ] Eventarc API ✅
- [ ] Cloud Logging API ✅
- [ ] Cloud Monitoring API ✅
- [ ] IAM API ✅

### **1.3 Set Up Workload Identity Federation (GitHub → GCP Auth)**

This allows GitHub Actions to authenticate without service account keys!

```bash
# Set variables
PROJECT_ID="cricbuzz-satish-dev"
POOL_NAME="github-actions-pool"
PROVIDER_NAME="github-provider"

# 1. Create Workload Identity Pool
gcloud iam workload-identity-pools create $POOL_NAME \
  --project=$PROJECT_ID \
  --location=global \
  --display-name="GitHub Actions Pool"

# 2. Get Pool Resource Name
POOL_RESOURCE=$(gcloud iam workload-identity-pools describe $POOL_NAME \
  --project=$PROJECT_ID \
  --location=global \
  --format='value(name)')

echo "Pool Resource: $POOL_RESOURCE"
# Output: projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool

# 3. Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc $PROVIDER_NAME \
  --project=$PROJECT_ID \
  --location=global \
  --workload-identity-pool=$POOL_NAME \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# 4. Get Provider Resource Name (you'll need this for GitHub Secrets!)
PROVIDER_RESOURCE=$(gcloud iam workload-identity-pools providers describe $PROVIDER_NAME \
  --project=$PROJECT_ID \
  --location=global \
  --workload-identity-pool=$POOL_NAME \
  --format='value(name)')

echo "Provider Resource: $PROVIDER_RESOURCE"
# Output: projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
```

**Save this Provider Resource** - You'll use it for all 3 environments!

- [ ] Workload Identity Pool created: `github-actions-pool`
- [ ] Workload Identity Provider created: `github-provider`
- [ ] Provider Resource saved: `projects/.../providers/github-provider`

---

## ✅ Phase 2: DEVELOPMENT ENVIRONMENT SETUP

### **2.1 Create Development Service Accounts**

**Service Account 1: Dataflow**
```bash
gcloud iam service-accounts create cricket-dataflow-sa \
  --project=cricbuzz-satish-dev \
  --display-name="Cricket Analytics Dataflow SA"

# Get email
gcloud iam service-accounts describe cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com \
  --project=cricbuzz-satish-dev

# Output: cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com
```

**Service Account 2: Cloud Function**
```bash
gcloud iam service-accounts create cricket-cloud-function-sa \
  --project=cricbuzz-satish-dev \
  --display-name="Cricket Analytics Cloud Function SA"
```

**Service Account 3: Cloud Run**
```bash
gcloud iam service-accounts create cricket-cloud-run-sa \
  --project=cricbuzz-satish-dev \
  --display-name="Cricket Analytics Cloud Run SA"
```

**Service Account 4: Cloud Composer**
```bash
gcloud iam service-accounts create cricket-composer-sa \
  --project=cricbuzz-satish-dev \
  --display-name="Cricket Analytics Cloud Composer SA"
```

- [ ] cricket-dataflow-sa created
- [ ] cricket-cloud-function-sa created
- [ ] cricket-cloud-run-sa created
- [ ] cricket-composer-sa created

### **2.2 Grant IAM Roles to Dataflow Service Account**

```bash
PROJECT_ID="cricbuzz-satish-dev"
SA_EMAIL="cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com"

# BigQuery Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/bigquery.admin

# Storage Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/storage.admin

# Dataflow Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/dataflow.admin

# Compute Instance Service Account
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/compute.instanceServiceAccount

# Dataflow Worker
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/dataflow.worker
```

- [ ] BigQuery Admin role granted to dataflow-sa
- [ ] Storage Admin role granted to dataflow-sa
- [ ] Dataflow Admin role granted to dataflow-sa
- [ ] Compute Instance Service Account role granted
- [ ] Dataflow Worker role granted

### **2.3 Grant IAM Roles to Cloud Function Service Account**

```bash
SA_EMAIL="cricket-cloud-function-sa@cricbuzz-satish-dev.iam.gserviceaccount.com"

# Dataflow Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/dataflow.admin

# Service Account User (to impersonate dataflow SA)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/iam.serviceAccountUser
```

- [ ] Dataflow Admin role granted to cloud-function-sa
- [ ] Service Account User role granted to cloud-function-sa

### **2.4 Grant IAM Roles to Cloud Composer Service Account**

```bash
SA_EMAIL="cricket-composer-sa@cricbuzz-satish-dev.iam.gserviceaccount.com"

# BigQuery Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/bigquery.admin

# Storage Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/storage.admin

# Dataflow Admin
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$SA_EMAIL \
  --role=roles/dataflow.admin
```

- [ ] BigQuery Admin role granted to composer-sa
- [ ] Storage Admin role granted to composer-sa
- [ ] Dataflow Admin role granted to composer-sa

### **2.5 Set Up GitHub Actions Authentication (DEV)**

Allow GitHub to assume the dataflow service account:

```bash
GITHUB_REPO="your-username/cricket-analytics-pipeline"
PROVIDER_RESOURCE="projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider"

gcloud iam service-accounts add-iam-policy-binding \
  cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com \
  --project=cricbuzz-satish-dev \
  --role=roles/iam.workloadIdentityUser \
  --condition='resource.name.startsWith("principalSet://goog/github/repo/$GITHUB_REPO")' \
  --member=principalSet://goog/github/repo/$GITHUB_REPO
```

- [ ] GitHub Actions allowed to use dataflow-sa (DEV)

### **2.6 Create GCS Buckets (DEV)**

```bash
PROJECT_ID="cricbuzz-satish-dev"

# Raw Data Bucket
gsutil mb -p $PROJECT_ID -l us-central1 gs://dev-cricket-raw-data

# Dataflow Templates Bucket
gsutil mb -p $PROJECT_ID -l us-central1 gs://dev-cricket-dataflow-templates

# Dataflow Temp Bucket
gsutil mb -p $PROJECT_ID -l us-central1 gs://dev-cricket-dataflow-temp

# Terraform State Bucket
gsutil mb -p $PROJECT_ID -l us-central1 gs://dev-cricket-tf-state

# Enable versioning on state bucket
gsutil versioning set on gs://dev-cricket-tf-state
```

**Verify buckets:**
```bash
gsutil ls | grep dev-cricket
```

- [ ] gs://dev-cricket-raw-data created
- [ ] gs://dev-cricket-dataflow-templates created
- [ ] gs://dev-cricket-dataflow-temp created
- [ ] gs://dev-cricket-tf-state created with versioning

### **2.7 Create BigQuery Datasets (DEV)**

```bash
PROJECT_ID="cricbuzz-satish-dev"

# Raw Dataset
bq mk --project_id=$PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Raw data layer - DEV" \
  dev_cricket_raw

# Staging Dataset
bq mk --project_id=$PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Staging layer - DEV" \
  dev_cricket_staging

# Curated Dataset
bq mk --project_id=$PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Curated layer - DEV" \
  dev_cricket_curated

# Audit Logs Dataset
bq mk --project_id=$PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Audit logs - DEV" \
  dev_cricket_audit_logs
```

**Verify datasets:**
```bash
bq ls --project_id=$PROJECT_ID | grep dev_
```

- [ ] dev_cricket_raw dataset created
- [ ] dev_cricket_staging dataset created
- [ ] dev_cricket_curated dataset created
- [ ] dev_cricket_audit_logs dataset created

---

## ✅ Phase 3: STAGING ENVIRONMENT SETUP

Repeat Phase 2 but with `stg-` prefix instead of `dev-`:

- [ ] cricket-dataflow-sa service account (or create new if needed)
- [ ] gs://stg-cricket-raw-data bucket
- [ ] gs://stg-cricket-dataflow-templates bucket
- [ ] gs://stg-cricket-dataflow-temp bucket
- [ ] gs://stg-cricket-tf-state bucket (with versioning)
- [ ] stg_cricket_raw dataset
- [ ] stg_cricket_staging dataset
- [ ] stg_cricket_curated dataset
- [ ] stg_cricket_audit_logs dataset
- [ ] GitHub Actions authentication set up (STG)

---

## ✅ Phase 4: PRODUCTION ENVIRONMENT SETUP

Repeat Phase 2 but with `prod-` prefix instead of `dev-`:

- [ ] cricket-dataflow-sa service account (or create new if needed)
- [ ] gs://prod-cricket-raw-data bucket (with versioning enabled)
- [ ] gs://prod-cricket-dataflow-templates bucket (with versioning)
- [ ] gs://prod-cricket-dataflow-temp bucket
- [ ] gs://prod-cricket-tf-state bucket (with versioning)
- [ ] prod_cricket_raw dataset
- [ ] prod_cricket_staging dataset
- [ ] prod_cricket_curated dataset
- [ ] prod_cricket_audit_logs dataset
- [ ] GitHub Actions authentication set up (PROD)
- [ ] Enable backups for prod datasets
- [ ] Enable monitoring/alerts for prod

---

## 📋 VERIFICATION CHECKLIST

### **APIs Check**
```bash
gcloud services list --enabled | grep -E "bigquery|storage|dataflow|scheduler|functions|run|composer"
```
- [ ] All 12 APIs are enabled

### **Service Accounts Check**
```bash
gcloud iam service-accounts list --filter="displayName:cricket"
```
Should show:
- [ ] cricket-dataflow-sa
- [ ] cricket-cloud-function-sa
- [ ] cricket-cloud-run-sa
- [ ] cricket-composer-sa

### **GCS Buckets Check**
```bash
gsutil ls | grep cricket
```
Should show:
- [ ] dev-cricket-* (4 buckets)
- [ ] stg-cricket-* (4 buckets)
- [ ] prod-cricket-* (4 buckets)

### **BigQuery Datasets Check**
```bash
bq ls --project_id=cricbuzz-satish-dev
```
Should show:
- [ ] dev_cricket_raw, dev_cricket_staging, dev_cricket_curated, dev_cricket_audit_logs
- [ ] stg_cricket_raw, stg_cricket_staging, stg_cricket_curated, stg_cricket_audit_logs
- [ ] prod_cricket_raw, prod_cricket_staging, prod_cricket_curated, prod_cricket_audit_logs

### **IAM Roles Check**
```bash
gcloud projects get-iam-policy cricbuzz-satish-dev \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:cricket-dataflow-sa*"
```
Should show multiple roles granted

### **Workload Identity Check**
```bash
gcloud iam workload-identity-pools describe github-actions-pool \
  --project=cricbuzz-satish-dev \
  --location=global
```
- [ ] Pool exists and is configured

---

## 🔐 Gather Values for GitHub Secrets

Once all GCP setup is complete, gather these values:

### **For DEV Environment:**
```bash
# 1. Project ID
gcloud config get-value project
# Copy: DEV_GCP_PROJECT_ID

# 2. Service Account Email
gcloud iam service-accounts describe cricket-dataflow-sa@cricbuzz-satish-dev.iam.gserviceaccount.com --format='value(email)'
# Copy: DEV_SERVICE_ACCOUNT_EMAIL

# 3. Workload Identity Provider (same for all envs)
gcloud iam workload-identity-pools providers describe github-provider \
  --project=cricbuzz-satish-dev \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --format='value(name)'
# Copy: DEV_WORKLOAD_IDENTITY_PROVIDER

# 4. Terraform State Bucket
gsutil ls | grep dev.*tf-state
# Copy: DEV_TF_STATE_BUCKET (e.g., dev-cricket-tf-state)
```

**Repeat for STG and PROD** with stg-/prod- prefixes

- [ ] DEV_GCP_PROJECT_ID: ___________________________
- [ ] DEV_SERVICE_ACCOUNT_EMAIL: ___________________________
- [ ] DEV_WORKLOAD_IDENTITY_PROVIDER: ___________________________
- [ ] DEV_TF_STATE_BUCKET: ___________________________
- [ ] STG_GCP_PROJECT_ID: ___________________________
- [ ] STG_SERVICE_ACCOUNT_EMAIL: ___________________________
- [ ] STG_WORKLOAD_IDENTITY_PROVIDER: ___________________________
- [ ] STG_TF_STATE_BUCKET: ___________________________
- [ ] PROD_GCP_PROJECT_ID: ___________________________
- [ ] PROD_SERVICE_ACCOUNT_EMAIL: ___________________________
- [ ] PROD_WORKLOAD_IDENTITY_PROVIDER: ___________________________
- [ ] PROD_TF_STATE_BUCKET: ___________________________

---

## 🎯 Summary

### **One-Time Setup (Phase 1)**
- [ ] GCP Project created
- [ ] 12 APIs enabled
- [ ] Workload Identity Pool created
- [ ] Workload Identity Provider created

### **Per-Environment Setup (Phases 2-4)**
- [ ] 4 Service Accounts created per environment
- [ ] IAM Roles granted to service accounts
- [ ] GitHub Actions authentication configured
- [ ] 4 GCS Buckets created per environment
- [ ] 4 BigQuery Datasets created per environment

### **Verification (Phase 5)**
- [ ] All APIs enabled
- [ ] All service accounts created
- [ ] All buckets created
- [ ] All datasets created
- [ ] All IAM roles granted
- [ ] Workload Identity configured

### **GitHub Secrets**
- [ ] All 12 secrets values gathered
- [ ] Ready to add to GitHub

---

## 📞 Troubleshooting

**Issue: Permission Denied**
- Solution: Ensure your user account has Owner or Editor role in GCP

**Issue: Bucket Already Exists**
- Solution: Either use different bucket name or delete existing bucket first

**Issue: API Not Enabled**
- Solution: Run `gcloud services enable [API_NAME]`

**Issue: Service Account Creation Fails**
- Solution: Check if account already exists with `gcloud iam service-accounts list`

---

**Status:** Ready to start GCP setup! 🚀

**Next:** Follow this checklist phase by phase, then add the 12 secrets to GitHub.
