# 🤖 AUTOMATIC DEPLOYMENT GUIDE

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete Automation Setup

Complete guide for FULLY AUTOMATED deployment - deploy everything with ONE command!

---

## 📋 THREE WAYS TO DEPLOY (Choose One)

### **Option 1: Local Script (Fastest for Testing)**
Runs on your computer - all automation happens locally.

**Time**: 40-50 minutes  
**Best For**: First-time setup, development, testing

### **Option 2: GitHub Actions (Best for Production)**
Fully automated CI/CD - deploys automatically when you push to GitHub.

**Time**: ~1 hour (automated)  
**Best For**: Production, teams, automatic daily runs

### **Option 3: Manual Steps (For Learning)**
Follow step-by-step if you want to understand each component.

**Time**: 60+ minutes  
**Best For**: Learning, debugging, understanding

---

## 🚀 **OPTION 1: LOCAL AUTOMATIC DEPLOYMENT (Recommended for Start)**

### **Prerequisites**
```bash
✅ GCP Account with billing enabled
✅ GCP Project created
✅ RapidAPI account with Cricbuzz subscription
✅ Git installed
✅ gcloud CLI installed
✅ Terraform >= 1.0 installed
✅ Docker installed
✅ Python 3.11+
✅ Repository cloned locally
```

### **Windows PowerShell - ONE COMMAND DEPLOYMENT**

```powershell
# 1. Open PowerShell as Administrator

# 2. Navigate to project
cd C:\path\to\cricket-analytics-pipeline

# 3. Run automatic deployment (choose method A or B)

# METHOD A: Interactive (prompts for credentials)
.\DEPLOY_AUTOMATIC.ps1

# METHOD B: With parameters (no prompts)
.\DEPLOY_AUTOMATIC.ps1 `
  -GCP_PROJECT_ID "your-gcp-project-id" `
  -RAPIDAPI_KEY "your-rapidapi-key"

# 4. Wait for completion (40-50 minutes)
# 5. Follow instructions in final summary
```

**What It Does Automatically:**
```
✅ Authenticates with Google Cloud
✅ Sets environment variables
✅ Deploys Terraform infrastructure (15-20 min)
   - GCS buckets (3)
   - BigQuery datasets (3)
   - Service accounts (3)
   - Cloud Function, Scheduler, Composer
✅ Creates BigQuery tables & views (5 min)
✅ Builds Docker image (5 min)
✅ Pushes to Artifact Registry (5 min)
✅ Creates Dataflow template (5 min)
✅ Fetches data from API (2-3 min)
✅ Verifies deployment (2 min)
```

### **Linux/Mac - ONE COMMAND DEPLOYMENT**

```bash
# 1. Open Terminal

# 2. Navigate to project
cd ~/path/to/cricket-analytics-pipeline

# 3. Make script executable
chmod +x DEPLOY_AUTOMATIC.sh

# 4. Run automatic deployment (choose method A or B)

# METHOD A: Interactive (prompts for credentials)
./DEPLOY_AUTOMATIC.sh

# METHOD B: With parameters (no prompts)
./DEPLOY_AUTOMATIC.sh "your-gcp-project-id" "your-rapidapi-key"

# 5. Wait for completion (40-50 minutes)
# 6. Follow instructions in final summary
```

**What It Does Automatically:** (Same as Windows)

---

## ⚡ **OPTION 2: GITHUB ACTIONS (PRODUCTION DEPLOYMENT)**

### **Setup GitHub Actions CI/CD**

#### **Step 1: Create GitHub Secrets**

```bash
# Go to: GitHub.com → Your Repository → Settings → Secrets and variables → Actions

# Add these secrets:

1. GCP_PROJECT_ID
   Value: your-gcp-project-id

2. RAPIDAPI_KEY
   Value: your-rapidapi-key
```

#### **Step 2: Configure OIDC authentication**

Use GitHub Actions Workload Identity Federation instead of a service account key.

```bash
# 1. Create a service account in GCP Console
# 2. Grant the service account only the roles your deployment needs
# 3. Create a Workload Identity Pool and GitHub OIDC provider
# 4. Bind the provider to the service account with roles/iam.workloadIdentityUser
# 5. Update the GitHub Actions workflow to use workload_identity_provider
#    and service_account_email instead of credentials_json
```

#### **Step 3: Trigger Automatic Deployment**

**Option A: Automatic (on every push)**
```bash
# Just push to main branch
git push origin main

# GitHub Actions automatically:
# ✅ Starts deployment
# ✅ Deploys infrastructure
# ✅ Creates BigQuery objects
# ✅ Builds Dataflow template
# ✅ Ingests data
# ✅ Verifies everything
# Time: ~1 hour
```

**Option B: Manual Trigger**
```
1. Go to: GitHub.com → Your Repository → Actions
2. Click: "🤖 Automated Deployment Pipeline"
3. Click: "Run workflow" → "Run workflow"
4. Wait ~1 hour for completion
```

### **Monitor GitHub Actions Deployment**

```
1. Go to: Repository → Actions tab
2. Click on active workflow
3. See real-time logs for:
   - Terraform deployment
   - BigQuery setup
   - Dataflow template
   - Data ingestion
   - Verification
```

---

## 📊 **DEPLOYMENT FLOW COMPARISON**

```
LOCAL SCRIPT                          GITHUB ACTIONS
────────────────────────────────────────────────────────────
Run locally on your computer           Runs on GitHub servers
Manual trigger (you run it)            Auto-trigger (on push)
Real-time output visible              View in GitHub Actions tab
Can pause/resume                      Runs continuously
40-50 minutes                         ~1 hour
Best for testing                      Best for production
```

---

## ✅ **WHAT GETS CREATED**

### **Automatically Deployed Resources: 50+**

```
☁️ GOOGLE CLOUD STORAGE (3 buckets)
   ├─ cricket-raw-data-{PROJECT_ID}
   ├─ cricket-dataflow-templates-{PROJECT_ID}
   └─ cricket-dataflow-temp-{PROJECT_ID}

📊 BIGQUERY (3 datasets, 12 objects)
   ├─ cricket_raw
   │  ├─ batting_rankings (table)
   │  └─ vw_latest_raw (view)
   ├─ cricket_staging
   │  ├─ dim_player (table)
   │  ├─ dim_country (table)
   │  ├─ dim_format (table)
   │  ├─ dim_date (table)
   │  └─ fact_batting_rankings (table)
   └─ cricket_curated
      ├─ vw_batting_rankings_latest
      ├─ vw_batting_rankings_90day_trend
      ├─ vw_top_10_batsmen_by_format
      ├─ vw_batting_statistics_by_country
      └─ vw_ranking_comparison_cross_format

🔄 DATAFLOW
   ├─ Docker image in Artifact Registry
   ├─ Flex Template metadata
   └─ Automated data processing

⚙️ SERVICE ACCOUNTS & IAM (3 accounts, 12+ roles)
   ├─ cricket-dataflow-sa
   ├─ cricket-cloud-function-sa
   └─ cricket-composer-sa

🌬️ CLOUD COMPOSER (Airflow)
   └─ cricket-analytics-composer environment

☁️ CLOUD FUNCTION
   └─ cricket-gcs-dataflow-trigger

📅 CLOUD SCHEDULER
   └─ cricket-daily-ingestion job

🐳 ARTIFACT REGISTRY
   └─ Docker repository

📋 & MONITORING
   ├─ Cloud Logging
   ├─ Cloud Monitoring
   └─ Audit Logs
```

---

## 🔍 **MONITORING DEPLOYMENT PROGRESS**

### **Local Script - Watch Console Output**
```
Real-time output shows:
✅ Each step completion
✅ Resource creation status
✅ Data processing progress
✅ Final summary with links
```

### **GitHub Actions - Check Workflow**
```
1. Go to: Repository → Actions
2. Click on "🤖 Automated Deployment Pipeline" workflow
3. See real-time logs:
   - Terraform validation & apply
   - BigQuery SQL execution
   - Docker build & push
   - Data ingestion
   - Verification results
```

---

## ⏱️ **TIMING BREAKDOWN**

```
LOCAL DEPLOYMENT:
├─ Setup & Auth          2 min
├─ Terraform             15-20 min  ⏳ Longest step
├─ BigQuery              5 min
├─ Docker build          5 min
├─ Docker push           5 min
├─ Dataflow template     5 min
├─ Data ingestion        2-3 min    ⚡ Triggers automation
├─ Dataflow processing   3-5 min    (runs in background)
└─ Verification          2 min
──────────────────────────────────
TOTAL:                    40-50 min

GITHUB ACTIONS:
(Similar but on GitHub servers, ~1 hour total)
```

---

## 📱 **AFTER DEPLOYMENT**

### **What Happens Automatically**

```
FIRST RUN (After deployment):
1. Ingestion script fetches data (2-3 min)
2. CSV uploaded to GCS (30 sec)
3. Cloud Function triggered automatically
4. Dataflow job launches automatically
5. Data processed and written to BigQuery (3-5 min)
6. Analytics views refreshed (auto)

DAILY (Every day at 06:00 UTC):
Cloud Scheduler → Airflow DAG → 
  Ingestion → Dataflow → BigQuery → 
    Analytics Views → Ready for Dashboard
```

---

## 🔧 **TROUBLESHOOTING AUTOMATIC DEPLOYMENT**

### **Issue: Terraform fails**
```
Check:
1. GCP_PROJECT_ID is correct
2. Billing is enabled
3. Appropriate APIs are enabled
4. Service account has sufficient permissions

Solution:
Run: gcloud auth login
Then: gcloud config set project YOUR_PROJECT_ID
```

### **Issue: Docker push fails**
```
Check:
1. Docker is running
2. Artifact Registry API enabled
3. Service account has storage.admin role

Solution:
Run: gcloud auth configure-docker us-central1-docker.pkg.dev
```

### **Issue: BigQuery creation fails**
```
Check:
1. Datasets exist in BigQuery
2. No naming conflicts
3. Service account has BigQuery admin role

Solution:
Check manually in GCP Console: BigQuery → Datasets
```

### **Issue: Data not appearing in BigQuery**
```
Check:
1. Dataflow job is running (check Cloud Logging)
2. Ingestion script executed successfully
3. GCS bucket has CSV files

Solution:
Wait 5-10 minutes for Dataflow to process
Check: https://console.cloud.google.com/dataflow
```

---

## ✨ **BEST PRACTICES**

### **Local Script**
```
✅ Use for first-time setup
✅ Test infrastructure changes locally
✅ Debug issues with real-time output
✅ Control exact timing
✅ Keep credentials secure (never commit)
```

### **GitHub Actions**
```
✅ Use for production deployments
✅ Automatic on every push
✅ Full audit trail in GitHub
✅ Team collaboration friendly
✅ Secrets managed securely by GitHub
```

---

## 📚 **QUICK START DECISION TREE**

```
Do you want to deploy NOW?
│
├─ YES, locally (first time)
│  └─ Run: .\DEPLOY_AUTOMATIC.ps1 (Windows)
│     or:  ./DEPLOY_AUTOMATIC.sh (Linux/Mac)
│
├─ YES, via GitHub Actions
│  ├─ Add GitHub Secrets
│  ├─ Push to main branch
│  └─ Watch Actions tab
│
└─ NO, learn step-by-step
   └─ Follow: STEP-BY-STEP guide
      (See SETUP_GCP_SECURE.sh docs)
```

---

## 📞 **SUPPORT**

```
Issue                          Solution
──────────────────────────────────────────────────────────
Script fails to run             Check all prerequisites
Missing credentials            Review GCP setup guide
Terraform errors               Check GCP permissions
BigQuery errors                Verify datasets exist
Dataflow issues                Check Cloud Logging
GitHub Actions failing         Check GitHub Secrets
```

---

## 🎉 **SUMMARY**

**Three ways to deploy - pick your comfort level:**

1. **LOCAL SCRIPT** - Most control, real-time feedback
   ```powershell
   .\DEPLOY_AUTOMATIC.ps1
   ```

2. **GITHUB ACTIONS** - Most automated, production-ready
   ```
   Push to main → Automatic deployment
   ```

3. **STEP-BY-STEP** - Most learning, most manual work
   ```
   Follow individual scripts
   ```

All three create the SAME result: Complete, functioning data pipeline! ✅

---

**Status**: ✅ Complete Automatic Deployment Setup  
**Time to Deploy**: 40-50 minutes  
**Result**: Production-ready pipeline!  

🚀 **Ready to deploy? Choose your method and go!**
