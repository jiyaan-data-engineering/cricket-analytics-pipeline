# 🔐 GitHub Secrets Setup Guide

Complete step-by-step guide to add all required secrets for multi-environment deployments using three separate GCP projects.

---

## 📋 Required Secrets (12 Total)

### **Development Environment (DEV_*)**
```
DEV_GCP_PROJECT_ID
DEV_SERVICE_ACCOUNT_EMAIL
DEV_WORKLOAD_IDENTITY_PROVIDER
DEV_TF_STATE_BUCKET
```

### **Staging Environment (STG_*)**
```
STG_GCP_PROJECT_ID
STG_SERVICE_ACCOUNT_EMAIL
STG_WORKLOAD_IDENTITY_PROVIDER
STG_TF_STATE_BUCKET
```

### **Production Environment (PROD_*)**
```
PROD_GCP_PROJECT_ID
PROD_SERVICE_ACCOUNT_EMAIL
PROD_WORKLOAD_IDENTITY_PROVIDER
PROD_TF_STATE_BUCKET
```

---

## 🔑 Where to Get These Values

### **1. GCP Project ID (per environment)**

For **DEV**:
```bash
gcloud config set project cricket-analytics-dev
gcloud config get-value project
# Output: cricket-analytics-dev
# Store as: DEV_GCP_PROJECT_ID = cricket-analytics-dev
```

For **STG**:
```bash
gcloud config set project cricket-analytics-stg
gcloud config get-value project
# Output: cricket-analytics-stg
# Store as: STG_GCP_PROJECT_ID = cricket-analytics-stg
```

For **PROD**:
```bash
gcloud config set project cricket-analytics-prod
gcloud config get-value project
# Output: cricket-analytics-prod
# Store as: PROD_GCP_PROJECT_ID = cricket-analytics-prod
```

### **2. Service Account Email (per environment)**

For **DEV**:
```bash
gcloud config set project cricket-analytics-dev
echo "cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com"
# Store as: DEV_SERVICE_ACCOUNT_EMAIL = cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com
```

For **STG**:
```bash
gcloud config set project cricket-analytics-stg
echo "cricket-dataflow-sa@cricket-analytics-stg.iam.gserviceaccount.com"
# Store as: STG_SERVICE_ACCOUNT_EMAIL = cricket-dataflow-sa@cricket-analytics-stg.iam.gserviceaccount.com
```

For **PROD**:
```bash
gcloud config set project cricket-analytics-prod
echo "cricket-dataflow-sa@cricket-analytics-prod.iam.gserviceaccount.com"
# Store as: PROD_SERVICE_ACCOUNT_EMAIL = cricket-dataflow-sa@cricket-analytics-prod.iam.gserviceaccount.com
```

### **3. Workload Identity Provider (per environment)**

For **DEV**:
```bash
gcloud config set project cricket-analytics-dev
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project=cricket-analytics-dev \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --format='value(name)'
# Output: projects/YOUR_DEV_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
# Store as: DEV_WORKLOAD_IDENTITY_PROVIDER = <full resource name>
```

For **STG**:
```bash
gcloud config set project cricket-analytics-stg
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project=cricket-analytics-stg \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --format='value(name)'
# Store as: STG_WORKLOAD_IDENTITY_PROVIDER = <full resource name>
```

For **PROD**:
```bash
gcloud config set project cricket-analytics-prod
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project=cricket-analytics-prod \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --format='value(name)'
# Store as: PROD_WORKLOAD_IDENTITY_PROVIDER = <full resource name>
```

### **4. Terraform State Bucket (per environment)**

For **DEV**:
```bash
gcloud config set project cricket-analytics-dev
gsutil ls
# Look for: gs://cricket-tf-state-dev
# Store as: DEV_TF_STATE_BUCKET = cricket-tf-state-dev
```

For **STG**:
```bash
gcloud config set project cricket-analytics-stg
gsutil ls
# Look for: gs://cricket-tf-state-stg
# Store as: STG_TF_STATE_BUCKET = cricket-tf-state-stg
```

For **PROD**:
```bash
gcloud config set project cricket-analytics-prod
gsutil ls
# Look for: gs://cricket-tf-state-prod
# Store as: PROD_TF_STATE_BUCKET = cricket-tf-state-prod
```

---

## 📝 Step-by-Step Setup in GitHub

### **Method 1: Web UI (Recommended)**

1. **Go to Repository Settings**
   - Open: `https://github.com/your-username/cricket-analytics-pipeline/settings`
   - Or: Click **Settings** tab in your repository

2. **Navigate to Secrets**
   - Left sidebar: Click **Secrets and variables**
   - Click **Actions**

3. **Add Each Secret**
   - Click **New repository secret**
   - Enter **Name**: (e.g., `DEV_GCP_PROJECT_ID`)
   - Enter **Value**: (e.g., `cricbuzz-satish-dev`)
   - Click **Add secret**
   - Repeat for all 12 secrets

### **Method 2: GitHub CLI**

```bash
# Login to GitHub CLI
gh auth login

# Navigate to repository
cd cricket-analytics-pipeline

# Add DEV secrets
gh secret set DEV_GCP_PROJECT_ID --body "cricket-analytics-dev"
gh secret set DEV_SERVICE_ACCOUNT_EMAIL --body "cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com"
gh secret set DEV_WORKLOAD_IDENTITY_PROVIDER --body "projects/YOUR_DEV_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider"
gh secret set DEV_TF_STATE_BUCKET --body "cricket-tf-state-dev"

# Add STG secrets
gh secret set STG_GCP_PROJECT_ID --body "cricket-analytics-stg"
gh secret set STG_SERVICE_ACCOUNT_EMAIL --body "cricket-dataflow-sa@cricket-analytics-stg.iam.gserviceaccount.com"
gh secret set STG_WORKLOAD_IDENTITY_PROVIDER --body "projects/YOUR_STG_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider"
gh secret set STG_TF_STATE_BUCKET --body "cricket-tf-state-stg"

# Add PROD secrets
gh secret set PROD_GCP_PROJECT_ID --body "cricket-analytics-prod"
gh secret set PROD_SERVICE_ACCOUNT_EMAIL --body "cricket-dataflow-sa@cricket-analytics-prod.iam.gserviceaccount.com"
gh secret set PROD_WORKLOAD_IDENTITY_PROVIDER --body "projects/YOUR_PROD_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider"
gh secret set PROD_TF_STATE_BUCKET --body "cricket-tf-state-prod"

# Verify all secrets are added
gh secret list
```

---

## 📋 Checklist: What to Add

### **Development Secrets (DEV_*)**

- [ ] **DEV_GCP_PROJECT_ID**
  - Value: `cricket-analytics-dev`
  - Description: Development GCP project ID

- [ ] **DEV_SERVICE_ACCOUNT_EMAIL**
  - Value: `cricket-dataflow-sa@cricket-analytics-dev.iam.gserviceaccount.com`
  - Description: Service account email for dev deployments

- [ ] **DEV_WORKLOAD_IDENTITY_PROVIDER**
  - Value: `projects/YOUR_DEV_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider`
  - Description: Workload Identity Provider for OIDC authentication (DEV)

- [ ] **DEV_TF_STATE_BUCKET**
  - Value: `cricket-tf-state-dev`
  - Description: GCS bucket for Terraform state (dev)

### **Staging Secrets (STG_*)**

- [ ] **STG_GCP_PROJECT_ID**
  - Value: `cricket-analytics-stg`
  - Description: Staging GCP project ID

- [ ] **STG_SERVICE_ACCOUNT_EMAIL**
  - Value: `cricket-dataflow-sa@cricket-analytics-stg.iam.gserviceaccount.com`
  - Description: Service account email for staging deployments

- [ ] **STG_WORKLOAD_IDENTITY_PROVIDER**
  - Value: `projects/YOUR_STG_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider`
  - Description: Workload Identity Provider for OIDC authentication (STG)

- [ ] **STG_TF_STATE_BUCKET**
  - Value: `cricket-tf-state-stg`
  - Description: GCS bucket for Terraform state (staging)

### **Production Secrets (PROD_*)**

- [ ] **PROD_GCP_PROJECT_ID**
  - Value: `cricket-analytics-prod`
  - Description: Production GCP project ID

- [ ] **PROD_SERVICE_ACCOUNT_EMAIL**
  - Value: `cricket-dataflow-sa@cricket-analytics-prod.iam.gserviceaccount.com`
  - Description: Service account email for production deployments

- [ ] **PROD_WORKLOAD_IDENTITY_PROVIDER**
  - Value: `projects/YOUR_PROD_PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider`
  - Description: Workload Identity Provider for OIDC authentication (PROD)

- [ ] **PROD_TF_STATE_BUCKET**
  - Value: `cricket-tf-state-prod`
  - Description: GCS bucket for Terraform state (production)

---

## 🔒 Security Best Practices

✅ **DO:**
- Use **environment-specific** values (dev ≠ stg ≠ prod)
- Keep secrets **secret** - never commit them
- Use **separate service accounts** per environment if possible
- **Rotate** credentials periodically
- **Audit** who has access to secrets

❌ **DON'T:**
- Commit secrets to the repository
- Share secrets in chat, email, or public channels
- Use the same credentials across all environments
- Store secrets in code or config files
- Give access to secrets to unauthorized users

---

## ✅ Verify Secrets Are Set Correctly

### **Via GitHub CLI**

```bash
# List all secrets (doesn't show values)
gh secret list

# Expected output:
# DEV_GCP_PROJECT_ID                          Updated 2026-06-14
# DEV_SERVICE_ACCOUNT_EMAIL                   Updated 2026-06-14
# DEV_WORKLOAD_IDENTITY_PROVIDER              Updated 2026-06-14
# DEV_TF_STATE_BUCKET                         Updated 2026-06-14
# STG_GCP_PROJECT_ID                          Updated 2026-06-14
# ... (and so on for all 12)
```

### **Via GitHub UI**

1. Go to **Settings → Secrets and variables → Actions**
2. You should see all 12 secrets listed
3. Click each one to verify it was added (values are hidden)

### **Via Workflow Logs**

After adding secrets:
1. Push to `develop` branch
2. Go to **Actions** tab
3. Click **Deploy to DEV** workflow
4. If secrets are correct: ✅ Deployment starts
5. If secrets are wrong: ❌ Authentication error in logs

---

## 🚀 Test the Secrets

Once all secrets are added, test them:

```bash
# 1. Push to develop to test DEV secrets
git push origin develop

# 2. Check Actions tab
# Go to: Actions → Deploy to DEV
# You should see the workflow running

# 3. If it fails, check the logs for authentication errors
# Click the failed job to see the error message
```

---

## 🆘 Troubleshooting

### **"Authentication failed" Error**

**Problem:** Workflow fails with authentication error

**Solutions:**
1. Verify secret names are EXACT (case-sensitive)
2. Verify secret values are correct (no extra spaces)
3. Verify service account has proper IAM roles
4. Check that Workload Identity Provider is configured in GCP

### **"Secret not found" Error**

**Problem:** Workflow says secret doesn't exist

**Solutions:**
1. Verify secret was added (check GitHub UI)
2. Verify the workflow is using correct secret name
3. Secrets are environment-specific, make sure using correct environment

### **"Invalid credential" Error**

**Problem:** GCP authentication fails

**Solutions:**
1. Verify service account email is correct
2. Verify Workload Identity Provider is set up
3. Verify service account has required IAM roles:
   - `roles/bigquery.admin`
   - `roles/storage.admin`
   - `roles/dataflow.admin`
   - `roles/compute.serviceAccount`

---

## 📞 Getting Help

1. **Check GitHub Secrets UI**: Settings → Secrets and variables → Actions
2. **Check Workflow Logs**: Actions → [Workflow] → [Run] → [Job]
3. **Check GCP Console**: Verify service accounts and permissions
4. **Check Terraform State**: Verify GCS buckets exist and are accessible

---

**Status:** Ready for secret setup! 🔐
