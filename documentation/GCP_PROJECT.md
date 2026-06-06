# 🔧 GCP Project Setup & Prerequisites

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete GCP Setup Guide

Complete step-by-step guide for GCP project setup before deploying Cricket Analytics Pipeline.

---

## 📋 Prerequisites Checklist

- [ ] Google Cloud Account (free trial or paid)
- [ ] gcloud CLI installed
- [ ] Terraform >= 1.0 installed
- [ ] Python 3.11+ installed
- [ ] RapidAPI account with Cricbuzz API subscription
- [ ] Text editor for configuration files

---

## 🚀 Step 1: Create GCP Project

### Option A: Via Console

1. Go to https://console.cloud.google.com
2. Click "Select a Project" (top-left)
3. Click "NEW PROJECT"
4. Enter project name: `cricket-analytics`
5. Click "CREATE"
6. Wait for project creation (1-2 minutes)

### Option B: Via gcloud CLI

```bash
# Set project ID
export PROJECT_ID="cricket-analytics-$(date +%s)"

# Create project
gcloud projects create $PROJECT_ID \
  --name="Cricket Analytics Pipeline"

# Set as default
gcloud config set project $PROJECT_ID

# Verify
gcloud config list
```

---

## 💳 Step 2: Enable Billing

**Without billing, GCP services won't work!**

### Via Console

1. Go to https://console.cloud.google.com/billing
2. Click "LINK BILLING ACCOUNT"
3. Create new billing account (if needed)
4. Add payment method (credit/debit card)
5. Link to project

### Via CLI

```bash
# List billing accounts
gcloud billing accounts list

# Link to project
gcloud billing projects link $PROJECT_ID \
  --billing-account=<ACCOUNT_ID>
```

**Estimated cost**: $5-20/month (dev environment)

---

## ✅ Step 3: Enable Required APIs

All 10 APIs required by the pipeline:

```bash
# Enable all at once
gcloud services enable \
  storage.googleapis.com \
  bigquery.googleapis.com \
  dataflow.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudscheduler.googleapis.com \
  cloudrun.googleapis.com \
  artifactregistry.googleapis.com \
  eventarc.googleapis.com \
  logging.googleapis.com \
  compute.googleapis.com \
  composer.googleapis.com \
  iam.googleapis.com

# Verify
gcloud services list --enabled
```

---

## 👥 Step 4: Create Service Account (Optional but Recommended)

For local development:

```bash
# Create service account
gcloud iam service-accounts create cricket-dev \
  --display-name="Cricket Analytics Dev Account"

# Grant roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:cricket-dev@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/editor

# Create key
gcloud iam service-accounts keys create key.json \
  --iam-account=cricket-dev@$PROJECT_ID.iam.gserviceaccount.com

# Set credential file
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
```

---

## 🔑 Step 5: Configure gcloud CLI

```bash
# Login to gcloud
gcloud auth login

# Set default project
gcloud config set project $PROJECT_ID

# Verify configuration
gcloud config list
```

**Expected output**:
```
[core]
account = your-email@gmail.com
project = cricket-analytics-XXXX
region = us-central1
```

---

## 📝 Step 6: Set Up Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc

export GCP_PROJECT="your-project-id"
export GCP_REGION="us-central1"
export RAPIDAPI_KEY="your-rapidapi-key"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"  # Optional
```

**Verify**:
```bash
echo $GCP_PROJECT
echo $RAPIDAPI_KEY
```

---

## 🌍 Step 7: Create GCS Buckets (Manual or Terraform)

### Manual (via CLI)

```bash
# Create 3 buckets
gsutil mb -l us-central1 gs://cricket-raw-data-$PROJECT_ID
gsutil mb -l us-central1 gs://cricket-dataflow-templates-$PROJECT_ID
gsutil mb -l us-central1 gs://cricket-dataflow-temp-$PROJECT_ID

# Verify
gsutil ls
```

### Via Terraform

```hcl
# terraform/terraform.tfvars
gcp_project_id = "your-project-id"
gcp_region     = "us-central1"

# Then:
cd terraform
terraform init
terraform plan
terraform apply -target=google_storage_bucket.raw_data
```

---

## 📊 Step 8: Create BigQuery Datasets (Manual or Terraform)

### Manual (via CLI)

```bash
# Create 3 datasets
bq mk --dataset $PROJECT_ID:cricket_raw
bq mk --dataset $PROJECT_ID:cricket_staging
bq mk --dataset $PROJECT_ID:cricket_curated

# Verify
bq ls
```

### Via Terraform

```bash
terraform apply -target=google_bigquery_dataset.raw
terraform apply -target=google_bigquery_dataset.staging
terraform apply -target=google_bigquery_dataset.curated
```

---

## ✅ Step 9: Verification Checklist

```bash
# Verify gcloud authentication
gcloud auth list

# Verify project
gcloud config get-value project

# Verify APIs enabled
gcloud services list --enabled | grep -E "storage|bigquery|dataflow"

# Verify buckets
gsutil ls

# Verify datasets
bq ls

# Verify service accounts (if created)
gcloud iam service-accounts list
```

---

## 🔐 Security Best Practices

### 1. Service Accounts
```bash
# Create specific service accounts for each component
# Rather than using your personal account
gcloud iam service-accounts create cricket-dataflow-sa
gcloud iam service-accounts create cricket-function-sa
gcloud iam service-accounts create cricket-composer-sa
```

### 2. IAM Roles
```bash
# Grant minimal required permissions (principle of least privilege)
# Not full Editor role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:cricket-dataflow-sa@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/bigquery.dataEditor
```

### 3. API Keys
```bash
# NEVER commit API keys to Git
# Use environment variables or Secret Manager
export RAPIDAPI_KEY="your-key"

# Or use Google Secret Manager
gcloud secrets create rapidapi-key --data-file=-
```

### 4. Bucket Permissions
```bash
# Restrict bucket access
gsutil iam set - gs://cricket-raw-data-$PROJECT_ID < policy.json

# Never make buckets public
gsutil acl set private gs://cricket-raw-data-$PROJECT_ID
```

---

## 🚀 Next Steps

Once GCP project is ready:

1. [./CONFIG.md](../docs/CONFIG.md) - Configure config.yaml with your project ID
2. [GIT_SETUP.md](./GIT_SETUP.md) - Set up Git & GitHub
3. [TERRAFORM.md](./TERRAFORM.md) - Deploy infrastructure
4. [./RAPIDAPI_KEY_SETUP_GUIDE.md](./RAPIDAPI_KEY_SETUP_GUIDE.md) - Get RapidAPI key

---

## ❌ Troubleshooting

### Issue: API not enabled

```
Error: API [dataflow.googleapis.com] not enabled

Solution:
gcloud services enable dataflow.googleapis.com
```

### Issue: Permission denied

```
Error: Permission 'iam.serviceAccounts.actAs' denied

Solution:
Ensure service account has correct IAM roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:your-sa@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountUser
```

### Issue: Quota exceeded

```
Error: Quota 'COMPUTE_INSTANCES' exceeded

Solution:
1. Check current quotas: gcloud compute quotas list
2. Request quota increase in GCP Console
3. Or reduce resource count in Terraform
```

---

**Status**: ✅ GCP Project Setup Complete  
**Cost Estimate**: $5-20/month  
**Time Required**: 15-20 minutes  
**Last Updated**: 2026-06-07  

Ready to deploy! 🚀
