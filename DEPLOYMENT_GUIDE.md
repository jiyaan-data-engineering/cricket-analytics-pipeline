# Complete Deployment Guide 🚀

## **You Have 4 Ways to Deploy:**

---

## **Option 1: Automatic Deployment (RECOMMENDED) ✅**

### **The Pipeline Runs Automatically Every Day at 06:00 UTC**

#### **No Action Needed!** The system is already configured to:

1. ✅ Cloud Scheduler triggers at 06:00 UTC
2. ✅ Cloud Run fetches cricket data
3. ✅ Dataflow processes it
4. ✅ BigQuery stores it
5. ✅ Dashboard shows results

#### **How to Monitor:**

```bash
# Check Cloud Scheduler status
gcloud scheduler jobs list --project=cricbuzz-satish-dev

# View job execution history
gcloud scheduler jobs describe cricket-daily-ingestion \
  --project=cricbuzz-satish-dev \
  --location=us-central1

# Check logs
gcloud logging read "resource.type=cloud_scheduler_job" \
  --project=cricbuzz-satish-dev \
  --limit=20
```

#### **What Happens Daily:**

```
06:00 UTC ┌─ Cloud Scheduler fires
          ├─ Cloud Run starts (1-2 min)
          ├─ API fetches 300-500 records
          ├─ GCS upload (1 min)
          ├─ Cloud Function triggered
          ├─ Dataflow processes (5-10 min)
          ├─ BigQuery insert (instant)
          └─ ✅ Complete (~13 min total)

Result: Fresh cricket data in BigQuery every morning!
```

---

## **Option 2: Manual Trigger (One-Time) 🎯**

### **Run the pipeline immediately (without waiting for 06:00 UTC)**

#### **Step 1: Set Environment Variables**

```bash
export GCP_PROJECT_ID="cricbuzz-satish-dev"
export GCP_REGION="us-central1"
export RAPIDAPI_KEY="your-api-key-here"
```

#### **Step 2: Run Data Ingestion**

```bash
# Clone/Navigate to repo
cd /path/to/cricket-analytics-pipeline

# Run ingestion script
python pipeline/ingestion/fetch_batting_rankings.py
```

#### **What It Does:**

```
✅ Step 1: Connect to Cricbuzz API
   └─ Fetch Test rankings
   └─ Fetch ODI rankings
   └─ Fetch T20I rankings

✅ Step 2: Process Data
   └─ Parse JSON responses
   └─ Convert to CSV
   └─ Add metadata

✅ Step 3: Upload to GCS
   └─ gs://cricket-analytics-raw-data/batting/
   └─ Filename: batting_rankings_YYYY-MM-DD_HHmmss.csv

✅ Step 4: GCS Event
   └─ Finalization event triggers
   └─ Cloud Function invoked
   └─ Dataflow job launches

✅ Step 5: Data Processing
   └─ CSV validation
   └─ Schema checking
   └─ Type conversion

✅ Step 6: BigQuery Load
   └─ Insert into cricket_raw.batting_rankings
   └─ ✅ Complete!

Time: ~15-20 minutes total
```

---

## **Option 3: Cloud Scheduler Manual Trigger ⏰**

### **Trigger the scheduled job immediately from GCP**

#### **Via gcloud CLI:**

```bash
# Force run the scheduler job NOW
gcloud scheduler jobs run cricket-daily-ingestion \
  --project=cricbuzz-satish-dev \
  --location=us-central1
```

#### **Via GCP Console:**

1. Go to **Cloud Console**
2. Navigation → **Cloud Scheduler**
3. Find: **cricket-daily-ingestion**
4. Click: **Force run** (play button)
5. Wait ~15 minutes
6. Check **Cloud Logging** for completion

#### **Monitor the Run:**

```bash
# Watch logs in real-time
gcloud logging read "resource.type=cloud_scheduler_job" \
  --project=cricbuzz-satish-dev \
  --limit=50 \
  --follow
```

---

## **Option 4: Cloud Composer/Airflow DAG Trigger 🔄**

### **Trigger the complete Airflow DAG**

#### **Via gcloud CLI:**

```bash
# Trigger the cricket_analytics_dag
gcloud composer environments run cricket-analytics-composer \
  --project=cricbuzz-satish-dev \
  --location=us-central1 \
  dags trigger -- cricket_analytics_dag
```

#### **Via Airflow UI:**

1. Go to **Cloud Composer** in GCP Console
2. Click: **Open Airflow UI**
3. Find: **cricket_analytics_dag**
4. Click: **Trigger DAG** (play button)
5. Wait for execution
6. Monitor in Airflow UI

#### **DAG Tasks:**

```
cricket_analytics_dag
├─ ingestion_tg
│  └─ fetch_rankings (fetch API data)
├─ processing_tg
│  └─ dataflow_job (run Dataflow)
├─ validation_tg
│  └─ quality_checks (data quality)
├─ staging_transformation
│  ├─ load_dimensions (dim tables)
│  └─ load_facts (fact table)
└─ notify_completion
   └─ send_notification (log completion)
```

---

## **Complete Deployment Checklist ✅**

### **Pre-Deployment (One-Time Setup)**

- [x] GCP Project created (`cricbuzz-satish-dev`)
- [x] Terraform infrastructure deployed (all 43 resources)
- [x] BigQuery datasets created (raw, staging, curated)
- [x] GCS buckets created (5 total)
- [x] Cloud Scheduler configured (06:00 UTC daily)
- [x] Cloud Composer environment ready
- [x] Service accounts with IAM roles assigned
- [x] GitHub repository set up with CI/CD
- [x] Code pushed to main branch
- [ ] **Get RapidAPI key** ← You need to do this!

### **Deployment Steps**

#### **Step 1: Get RapidAPI Key (5 minutes)**

```bash
# 1. Go to: https://rapidapi.com/cricketapi/api/cricbuzz-cricket
# 2. Click "Subscribe" (free tier: 100 requests/day)
# 3. Go to Dashboard
# 4. Copy your API key
# 5. Set it as environment variable:

export RAPIDAPI_KEY="your-key-here"

# 6. Save to GitHub Secrets (for CI/CD):
gh secret set RAPIDAPI_KEY --body "your-key-here"
```

#### **Step 2: Test Local Run (10 minutes)**

```bash
# Clone the repository
git clone https://github.com/jiyaan-data-engineering/cricket-analytics-pipeline.git
cd cricket-analytics-pipeline

# Set environment variables
export GCP_PROJECT_ID="cricbuzz-satish-dev"
export GCP_REGION="us-central1"
export RAPIDAPI_KEY="your-api-key"

# Run the ingestion pipeline
python pipeline/ingestion/fetch_batting_rankings.py

# Expected output:
# ✅ Fetching TEST batting rankings...
# ✅ Fetching ODI batting rankings...
# ✅ Fetching T20I batting rankings...
# ✅ 300-500 records processed
# ✅ CSV uploaded to GCS
# ✅ Pipeline complete!
```

#### **Step 3: Verify Data in BigQuery (5 minutes)**

```bash
# Query the raw table
bq query --use_legacy_sql=false << 'EOF'
SELECT 
  COUNT(*) as total_records,
  COUNT(DISTINCT format) as formats,
  COUNT(DISTINCT player_id) as players,
  MAX(ingested_at) as last_ingestion
FROM `cricbuzz-satish-dev.cricket_raw.batting_rankings`;
EOF

# Expected output:
# +---------------+--------+---------+----------------------------+
# | total_records | formats | players | last_ingestion             |
# +---------------+--------+---------+----------------------------+
# | 300-500       | 3       | 100+    | 2026-06-14 06:15:32 UTC    |
# +---------------+--------+---------+----------------------------+
```

#### **Step 4: Create Looker Studio Dashboard (5 minutes)**

```
1. Go to: https://lookerstudio.google.com/
2. Click: Create → Report
3. Connect to BigQuery
4. Select: cricket_raw.batting_rankings table
5. Add visualizations (follow docs/LOOKER_STUDIO_SETUP.md)
6. Save dashboard
```

#### **Step 5: Enable Automatic Scheduling ✅**

```bash
# The system is already configured!
# Cloud Scheduler will run at 06:00 UTC automatically

# To verify:
gcloud scheduler jobs list --project=cricbuzz-satish-dev

# Expected output:
# ID: cricket-daily-ingestion
# SCHEDULE: 0 6 * * * (Every day at 06:00 UTC)
# STATUS: ENABLED
# TIMEZONE: UTC
```

---

## **Deployment Timeline**

### **Day 1: Setup**
```
06:00 - Get RapidAPI key (5 min)
06:05 - Test local run (10 min)
06:15 - Verify BigQuery data (5 min)
06:20 - Create dashboard (5 min)
06:25 - ✅ COMPLETE!
```

### **Day 2 Onwards: Automatic**
```
06:00 UTC - Pipeline runs automatically
06:01-06:14 - Data flows through pipeline
06:15 - Fresh data in BigQuery
06:15 - Dashboard updates automatically
```

---

## **Production Deployment Checklist**

| Task | Status | Command |
|------|--------|---------|
| Infrastructure deployed | ✅ | Terraform done |
| Code committed | ✅ | Git push done |
| CI/CD configured | ✅ | GitHub Actions ready |
| RapidAPI key obtained | ⏳ | You need to do this |
| Local test run | ⏳ | `python pipeline/ingestion/...` |
| Data verified in BQ | ⏳ | `bq query ...` |
| Dashboard created | ⏳ | Looker Studio |
| Monitoring set up | ✅ | Cloud Logging active |
| Scheduled daily | ✅ | Cloud Scheduler ready |
| **STATUS** | **⏳ READY** | **Get API key & test** |

---

## **Monitoring Deployment**

### **Real-Time Monitoring**

```bash
# Watch Cloud Scheduler logs
gcloud logging read "resource.type=cloud_scheduler_job" \
  --project=cricbuzz-satish-dev \
  --follow

# Watch Dataflow jobs
gcloud dataflow jobs list \
  --project=cricbuzz-satish-dev \
  --filter="state:RUNNING OR state:DONE"

# Monitor BigQuery table growth
bq query --use_legacy_sql=false << 'EOF'
SELECT 
  DATE(ingested_at) as ingestion_date,
  COUNT(*) as records_count
FROM `cricbuzz-satish-dev.cricket_raw.batting_rankings`
GROUP BY ingestion_date
ORDER BY ingestion_date DESC
LIMIT 30;
EOF
```

### **Health Check Dashboard**

Create in Cloud Console → Monitoring:

```
Metric 1: Cloud Scheduler Job Success Rate
  └─ Should be 100%

Metric 2: Dataflow Job Failure Rate
  └─ Should be 0%

Metric 3: BigQuery Insert Success
  └─ Should be 100%

Metric 4: Data Latency
  └─ Should be < 15 minutes from API fetch to BQ
```

---

## **Rollback / Troubleshooting**

### **If Pipeline Fails:**

1. **Check Cloud Logging**
   ```bash
   gcloud logging read "severity>=ERROR" \
     --project=cricbuzz-satish-dev \
     --limit=50
   ```

2. **Verify RapidAPI Key**
   ```bash
   # Check if key is valid
   curl -X GET "https://cricbuzz-cricket.p.rapidapi.com/stats/v1/rankings/batsmen?formatType=test" \
     -H "x-rapidapi-key: YOUR_KEY" \
     -H "x-rapidapi-host: cricbuzz-cricket.p.rapidapi.com"
   ```

3. **Check BigQuery Quota**
   ```bash
   bq show --project_id=cricbuzz-satish-dev
   ```

4. **Restart Dataflow Job**
   ```bash
   gcloud dataflow jobs cancel <JOB_ID> \
     --project=cricbuzz-satish-dev
   
   # Manually trigger again
   python pipeline/ingestion/fetch_batting_rankings.py
   ```

---

## **Cost Tracking**

### **Monitor GCP Costs**

```bash
# Check BigQuery costs
bq query --use_legacy_sql=false << 'EOF'
SELECT
  CURRENT_DATE() as date,
  SUM(size_bytes) / POW(10,9) as gb_stored,
  SUM(bytes_billed) / POW(10,9) * 6.25 as estimated_cost_usd
FROM `cricbuzz-satish-dev.__TABLES_SUMMARY__`;
EOF

# Expected monthly cost: $5-9
```

---

## **Quick Reference**

### **One-Command Deployment**

```bash
# Complete end-to-end test
export RAPIDAPI_KEY="your-key" && \
export GCP_PROJECT_ID="cricbuzz-satish-dev" && \
python pipeline/ingestion/fetch_batting_rankings.py && \
echo "✅ Pipeline complete! Check BigQuery and Looker Studio"
```

### **Verify Everything Works**

```bash
# 1. Data ingested
bq query --use_legacy_sql=false "SELECT COUNT(*) FROM \`cricbuzz-satish-dev.cricket_raw.batting_rankings\` LIMIT 1"

# 2. Dashboard accessible
echo "Go to: https://lookerstudio.google.com/"

# 3. Monitoring logs
gcloud logging read --project=cricbuzz-satish-dev --limit=5

# 4. Schedule confirmed
gcloud scheduler jobs list --project=cricbuzz-satish-dev
```

---

## **Success Criteria ✅**

You'll know deployment is successful when:

- ✅ Data appears in `cricket_raw.batting_rankings`
- ✅ Looker Studio dashboard shows cricket rankings
- ✅ Cloud Logging shows no errors
- ✅ Pipeline completes in < 15 minutes
- ✅ Runs automatically at 06:00 UTC daily

---

## **You're All Set! 🎉**

Your deployment is:
- ✅ **Infrastructure:** Live (Terraform)
- ✅ **Code:** Ready (GitHub)
- ✅ **CI/CD:** Automated (GitHub Actions)
- ✅ **Monitoring:** Active (Cloud Logging)
- ⏳ **Real Data:** Waiting for RapidAPI key

**Next Step:** Get RapidAPI key and run Step 2!

