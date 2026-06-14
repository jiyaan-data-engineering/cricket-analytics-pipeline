# 📋 GCP Setup Checklist for Multi-Environment Deployment

Complete checklist of all GCP resources and configurations needed for dev, staging, and production environments using **THREE separate GCP projects**.

---

## 🎯 Overview

You need to set up:
- **3 GCP Projects** (separate projects for each environment)
  - `cricket-analytics-dev` (Development)
  - `cricket-analytics-stg` (Staging)
  - `cricket-analytics-prod` (Production)
- **Service Accounts** (4 per project)
- **APIs** - Enable required GCP services in each project
- **Workload Identity** - For GitHub Actions authentication (per project)
- **Storage & Data** - GCS buckets and BigQuery datasets (per project)
- **IAM Roles** - Proper permissions for each service account

---

## ✅ Phase 1: CREATE THREE GCP PROJECTS

### **1.1 Create Development Project (cricket-analytics-dev)**

```bash
# Set organization/folder if needed (optional)
FOLDER_ID="YOUR_FOLDER_ID"  # Leave empty if using org root

# Create project
gcloud projects create cricket-analytics-dev \
  --name="Cricket Analytics - Development" \
  --set-as-default

# Get Project ID and Number
DEV_PROJECT_ID=$(gcloud config get-value project)
DEV_PROJECT_NUMBER=$(gcloud projects describe $DEV_PROJECT_ID --format='value(projectNumber)')

echo "DEV Project ID: $DEV_PROJECT_ID"
echo "DEV Project Number: $DEV_PROJECT_NUMBER"
```

- [ ] `cricket-analytics-dev` project created
- [ ] Project ID saved: ___________________________
- [ ] Project Number saved: ___________________________

### **1.2 Create Staging Project (cricket-analytics-stg)**

```bash
gcloud projects create cricket-analytics-stg \
  --name="Cricket Analytics - Staging"

STG_PROJECT_ID="cricket-analytics-stg"
STG_PROJECT_NUMBER=$(gcloud projects describe $STG_PROJECT_ID --format='value(projectNumber)')

echo "STG Project ID: $STG_PROJECT_ID"
echo "STG Project Number: $STG_PROJECT_NUMBER"
```

- [ ] `cricket-analytics-stg` project created
- [ ] Project ID saved: ___________________________
- [ ] Project Number saved: ___________________________

### **1.3 Create Production Project (cricket-analytics-prod)**

```bash
gcloud projects create cricket-analytics-prod \
  --name="Cricket Analytics - Production"

PROD_PROJECT_ID="cricket-analytics-prod"
PROD_PROJECT_NUMBER=$(gcloud projects describe $PROD_PROJECT_ID --format='value(projectNumber)')

echo "PROD Project ID: $PROD_PROJECT_ID"
echo "PROD Project Number: $PROD_PROJECT_NUMBER"
```

- [ ] `cricket-analytics-prod` project created
- [ ] Project ID saved: ___________________________
- [ ] Project Number saved: ___________________________

---

## ✅ Phase 2: DEVELOPMENT ENVIRONMENT SETUP

### **2.1 Enable APIs in Development Project**

```bash
# Switch to DEV project
gcloud config set project cricket-analytics-dev

# Enable all required APIs
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

# Verify APIs
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

### **2.2 Set Up Workload Identity Federation (Development)**

```bash
DEV_PROJECT_ID="cricket-analytics-dev"
POOL_NAME="github-actions-pool"
PROVIDER_NAME="github-provider"

# 1. Create Workload Identity Pool
gcloud iam workload-identity-pools create $POOL_NAME \
  --project=$DEV_PROJECT_ID \
  --location=global \
  --display-name="GitHub Actions Pool"

# 2. Get Pool Resource Name
POOL_RESOURCE=$(gcloud iam workload-identity-pools describe $POOL_NAME \
  --project=$DEV_PROJECT_ID \
  --location=global \
  --format='value(name)')

echo "DEV Pool Resource: $POOL_RESOURCE"

# 3. Create Workload Identity Provider
gcloud iam workload-identity-pools providers create-oidc $PROVIDER_NAME \
  --project=$DEV_PROJECT_ID \
  --location=global \
  --workload-identity-pool=$POOL_NAME \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# 4. Get Provider Resource Name
DEV_PROVIDER_RESOURCE=$(gcloud iam workload-identity-pools providers describe $PROVIDER_NAME \
  --project=$DEV_PROJECT_ID \
  --location=global \
  --workload-identity-pool=$POOL_NAME \
  --format='value(name)')

echo "DEV Provider Resource: $DEV_PROVIDER_RESOURCE"
```

- [ ] Workload Identity Pool created: `github-actions-pool`
- [ ] Workload Identity Provider created: `github-provider`
- [ ] DEV Provider Resource saved: ___________________________

### **2.3 Create Service Accounts (Development)**

```bash
DEV_PROJECT_ID="cricket-analytics-dev"

# Dataflow Service Account
gcloud iam service-accounts create cricket-dataflow-sa \
  --project=$DEV_PROJECT_ID \
  --display-name="Cricket Analytics Dataflow SA"

# Cloud Function Service Account
gcloud iam service-accounts create cricket-cloud-function-sa \
  --project=$DEV_PROJECT_ID \
  --display-name="Cricket Analytics Cloud Function SA"

# Cloud Run Service Account
gcloud iam service-accounts create cricket-cloud-run-sa \
  --project=$DEV_PROJECT_ID \
  --display-name="Cricket Analytics Cloud Run SA"

# Cloud Composer Service Account
gcloud iam service-accounts create cricket-composer-sa \
  --project=$DEV_PROJECT_ID \
  --display-name="Cricket Analytics Cloud Composer SA"
```

- [ ] cricket-dataflow-sa created
- [ ] cricket-cloud-function-sa created
- [ ] cricket-cloud-run-sa created
- [ ] cricket-composer-sa created

### **2.4 Grant IAM Roles to Service Accounts (Development)**

```bash
DEV_PROJECT_ID="cricket-analytics-dev"
DATAFLOW_SA="cricket-dataflow-sa@${DEV_PROJECT_ID}.iam.gserviceaccount.com"
CF_SA="cricket-cloud-function-sa@${DEV_PROJECT_ID}.iam.gserviceaccount.com"
COMPOSER_SA="cricket-composer-sa@${DEV_PROJECT_ID}.iam.gserviceaccount.com"

# Dataflow SA roles
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$DATAFLOW_SA --role=roles/bigquery.admin
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$DATAFLOW_SA --role=roles/storage.admin
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$DATAFLOW_SA --role=roles/dataflow.admin
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$DATAFLOW_SA --role=roles/compute.instanceServiceAccount
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$DATAFLOW_SA --role=roles/dataflow.worker

# Cloud Function SA roles
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$CF_SA --role=roles/dataflow.admin
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$CF_SA --role=roles/iam.serviceAccountUser

# Cloud Composer SA roles
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$COMPOSER_SA --role=roles/bigquery.admin
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$COMPOSER_SA --role=roles/storage.admin
gcloud projects add-iam-policy-binding $DEV_PROJECT_ID \
  --member=serviceAccount:$COMPOSER_SA --role=roles/dataflow.admin
```

- [ ] Dataflow SA: BigQuery Admin, Storage Admin, Dataflow Admin, Compute Instance SA, Dataflow Worker
- [ ] Cloud Function SA: Dataflow Admin, Service Account User
- [ ] Cloud Composer SA: BigQuery Admin, Storage Admin, Dataflow Admin

### **2.5 Set Up GitHub Actions Authentication (Development)**

```bash
DEV_PROJECT_ID="cricket-analytics-dev"
GITHUB_REPO="your-username/cricket-analytics-pipeline"
DEV_PROVIDER_RESOURCE="projects/YOUR_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider"

gcloud iam service-accounts add-iam-policy-binding \
  cricket-dataflow-sa@${DEV_PROJECT_ID}.iam.gserviceaccount.com \
  --project=$DEV_PROJECT_ID \
  --role=roles/iam.workloadIdentityUser \
  --condition='resource.name.startsWith("principalSet://goog/github/repo/$GITHUB_REPO")' \
  --member=principalSet://goog/github/repo/$GITHUB_REPO
```

- [ ] GitHub Actions allowed to use dataflow-sa (DEV)

### **2.6 Create GCS Buckets (Development)**

```bash
DEV_PROJECT_ID="cricket-analytics-dev"

gsutil mb -p $DEV_PROJECT_ID -l us-central1 gs://cricket-raw-data-dev
gsutil mb -p $DEV_PROJECT_ID -l us-central1 gs://cricket-dataflow-templates-dev
gsutil mb -p $DEV_PROJECT_ID -l us-central1 gs://cricket-dataflow-temp-dev
gsutil mb -p $DEV_PROJECT_ID -l us-central1 gs://cricket-tf-state-dev

# Enable versioning on state bucket
gsutil versioning set on gs://cricket-tf-state-dev

# Verify
gsutil ls -p $DEV_PROJECT_ID | grep cricket
```

- [ ] gs://cricket-raw-data-dev created
- [ ] gs://cricket-dataflow-templates-dev created
- [ ] gs://cricket-dataflow-temp-dev created
- [ ] gs://cricket-tf-state-dev created with versioning

### **2.7 Create BigQuery Datasets (Development)**

```bash
DEV_PROJECT_ID="cricket-analytics-dev"

bq mk --project_id=$DEV_PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Raw data layer - DEV" \
  cricket_raw

bq mk --project_id=$DEV_PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Staging layer - DEV" \
  cricket_staging

bq mk --project_id=$DEV_PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Curated layer - DEV" \
  cricket_curated

bq mk --project_id=$DEV_PROJECT_ID \
  --dataset \
  --location=us-central1 \
  --description="Audit logs - DEV" \
  cricket_audit_logs

# Verify
bq ls --project_id=$DEV_PROJECT_ID
```

- [ ] cricket_raw dataset created
- [ ] cricket_staging dataset created
- [ ] cricket_curated dataset created
- [ ] cricket_audit_logs dataset created

---

## ✅ Phase 3: STAGING ENVIRONMENT SETUP

Repeat Phase 2 with `cricket-analytics-stg` project:

```bash
# Switch to STG project
gcloud config set project cricket-analytics-stg

# Run the same steps as Phase 2.1 through 2.7, but with:
# - Project ID: cricket-analytics-stg
# - Bucket names: cricket-*-stg (not -dev)
```

- [ ] All APIs enabled in cricket-analytics-stg
- [ ] Workload Identity Pool & Provider created (STG)
- [ ] 4 Service Accounts created (STG)
- [ ] IAM Roles granted to all SAs (STG)
- [ ] GitHub Actions authentication set up (STG)
- [ ] 4 GCS Buckets created (STG)
- [ ] 4 BigQuery Datasets created (STG)
- [ ] STG Provider Resource saved: ___________________________

---

## ✅ Phase 4: PRODUCTION ENVIRONMENT SETUP

Repeat Phase 2 with `cricket-analytics-prod` project:

```bash
# Switch to PROD project
gcloud config set project cricket-analytics-prod

# Run the same steps as Phase 2.1 through 2.7, but with:
# - Project ID: cricket-analytics-prod
# - Bucket names: cricket-*-prod (not -dev)
```

**Additional PROD-only steps:**

```bash
PROD_PROJECT_ID="cricket-analytics-prod"

# Enable versioning on all prod buckets (for backup)
gsutil versioning set on gs://cricket-raw-data-prod
gsutil versioning set on gs://cricket-dataflow-templates-prod
```

- [ ] All APIs enabled in cricket-analytics-prod
- [ ] Workload Identity Pool & Provider created (PROD)
- [ ] 4 Service Accounts created (PROD)
- [ ] IAM Roles granted to all SAs (PROD)
- [ ] GitHub Actions authentication set up (PROD)
- [ ] 4 GCS Buckets created (PROD) with versioning
- [ ] 4 BigQuery Datasets created (PROD)
- [ ] PROD Provider Resource saved: ___________________________

---

## 📋 VERIFICATION CHECKLIST

### **Projects Check**
```bash
gcloud projects list --filter="name:cricket-analytics"
```

Should show:
- [ ] cricket-analytics-dev
- [ ] cricket-analytics-stg
- [ ] cricket-analytics-prod

### **APIs Check (per project)**
```bash
# For each project
gcloud config set project cricket-analytics-dev
gcloud services list --enabled | grep -E "bigquery|storage|dataflow|scheduler|functions|run|composer"
```

- [ ] All 12 APIs enabled in DEV
- [ ] All 12 APIs enabled in STG
- [ ] All 12 APIs enabled in PROD

### **Service Accounts Check (per project)**
```bash
gcloud config set project cricket-analytics-dev
gcloud iam service-accounts list --filter="displayName:cricket"
```

Should show 4 service accounts in each project:
- [ ] cricket-dataflow-sa
- [ ] cricket-cloud-function-sa
- [ ] cricket-cloud-run-sa
- [ ] cricket-composer-sa

### **GCS Buckets Check (per project)**
```bash
gcloud config set project cricket-analytics-dev
gsutil ls -p cricket-analytics-dev
```

Should show:
- [ ] cricket-raw-data-dev
- [ ] cricket-dataflow-templates-dev
- [ ] cricket-dataflow-temp-dev
- [ ] cricket-tf-state-dev

**Repeat for -stg and -prod**

### **BigQuery Datasets Check (per project)**
```bash
gcloud config set project cricket-analytics-dev
bq ls --project_id=cricket-analytics-dev
```

Should show:
- [ ] cricket_raw
- [ ] cricket_staging
- [ ] cricket_curated
- [ ] cricket_audit_logs

**Repeat for -stg and -prod**

---

## 🔐 Gather Values for GitHub Secrets

Once all GCP setup is complete, gather these values for each project:

### **For DEV Environment:**
```bash
gcloud config set project cricket-analytics-dev

# 1. Project ID
DEV_PROJECT_ID=$(gcloud config get-value project)
echo "DEV_GCP_PROJECT_ID: $DEV_PROJECT_ID"

# 2. Service Account Email
echo "DEV_SERVICE_ACCOUNT_EMAIL: cricket-dataflow-sa@${DEV_PROJECT_ID}.iam.gserviceaccount.com"

# 3. Workload Identity Provider
gcloud iam workload-identity-pools providers describe github-provider \
  --project=$DEV_PROJECT_ID \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --format='value(name)'

# 4. Terraform State Bucket
echo "DEV_TF_STATE_BUCKET: cricket-tf-state-dev"
```

### **For STG Environment:**
```bash
gcloud config set project cricket-analytics-stg

# Repeat same commands for STG
```

### **For PROD Environment:**
```bash
gcloud config set project cricket-analytics-prod

# Repeat same commands for PROD
```

**Record these values:**

- [ ] DEV_GCP_PROJECT_ID: cricket-analytics-dev
- [ ] DEV_SERVICE_ACCOUNT_EMAIL: cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com
- [ ] DEV_WORKLOAD_IDENTITY_PROVIDER: ___________________________
- [ ] DEV_TF_STATE_BUCKET: cricket-tf-state-dev
- [ ] STG_GCP_PROJECT_ID: cricket-analytics-stg
- [ ] STG_SERVICE_ACCOUNT_EMAIL: cricket-dataflow-sa@cricket-analytics-stg.iam.gserviceaccount.com
- [ ] STG_WORKLOAD_IDENTITY_PROVIDER: ___________________________
- [ ] STG_TF_STATE_BUCKET: cricket-tf-state-stg
- [ ] PROD_GCP_PROJECT_ID: cricket-analytics-prod
- [ ] PROD_SERVICE_ACCOUNT_EMAIL: cricket-dataflow-sa@cricket-analytics-prod.iam.gserviceaccount.com
- [ ] PROD_WORKLOAD_IDENTITY_PROVIDER: ___________________________
- [ ] PROD_TF_STATE_BUCKET: cricket-tf-state-prod

---

## 🎯 Summary

### **One-Time Setup per Project**
- [ ] GCP Project created
- [ ] 12 APIs enabled
- [ ] Workload Identity Pool created
- [ ] Workload Identity Provider created

### **Per-Project Setup**
- [ ] 4 Service Accounts created
- [ ] IAM Roles granted to service accounts
- [ ] GitHub Actions authentication configured
- [ ] 4 GCS Buckets created
- [ ] 4 BigQuery Datasets created

### **Verification**
- [ ] All 3 projects exist
- [ ] All APIs enabled in each project
- [ ] All service accounts created per project
- [ ] All buckets created per project
- [ ] All datasets created per project
- [ ] All IAM roles granted per project
- [ ] Workload Identity configured per project

### **GitHub Secrets (12 Total)**
- [ ] All 12 secrets values gathered (4 per environment × 3 environments)
- [ ] Ready to add to GitHub (see GITHUB_SECRETS_SETUP.md)

---

## 📞 Troubleshooting

**Issue: Permission Denied**
- Solution: Ensure your user account has Owner or Editor role on the GCP projects/folder/organization

**Issue: Project Already Exists**
- Solution: Use different project names or contact administrator to use existing projects

**Issue: API Not Enabled**
- Solution: Run `gcloud services enable [API_NAME]` in the correct project

**Issue: Service Account Creation Fails**
- Solution: Check if account already exists with `gcloud iam service-accounts list`

**Issue: Bucket Name Conflicts**
- Solution: Bucket names must be globally unique; prepend your username or organization ID if needed

---

**Status:** Ready to start GCP setup! 🚀

**Next Steps:**
1. Follow this checklist phase by phase (Phase 1 → Phase 2 → Phase 3 → Phase 4)
2. Verify all resources in Phase 5
3. Gather GitHub Secrets values
4. Add 12 secrets to GitHub (see GITHUB_SECRETS_SETUP.md)
