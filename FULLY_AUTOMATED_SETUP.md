# 🤖 Fully Automated Two-Phase Pipeline Setup

Complete automation with **zero manual intervention** required.

---

## Quick Start

### Option A: Deploy Cloud Function (Recommended)

```bash
# Deploy auto orchestrator function
gcloud functions deploy auto-orchestrator \
  --runtime python311 \
  --trigger-topic cricket-pipeline \
  --entry-point auto_run_pipeline_pubsub \
  --source pipeline/cloud_function/ \
  --region us-central1 \
  --project cricket-analytics-prod \
  --env-vars GCP_PROJECT_ID=cricket-analytics-prod,GCP_REGION=us-central1

# Test function immediately
gcloud functions call auto-orchestrator \
  --region us-central1 \
  --project cricket-analytics-prod
```

### Option B: Run Script Directly

```bash
# Make script executable
chmod +x scripts/auto-phase1-phase2.sh

# Run fully automated pipeline
./scripts/auto-phase1-phase2.sh cricket-analytics-prod us-central1
```

---

## Automated Cloud Scheduler Setup

Schedule the pipeline to run **automatically every day** (no user action needed).

```bash
PROJECT_ID="cricket-analytics-prod"
REGION="us-central1"
SCHEDULE="0 5 * * *"  # Daily at 05:00 UTC (adjust as needed)

# Create Cloud Scheduler job
gcloud scheduler jobs create pubsub auto-pipeline \
  --schedule="$SCHEDULE" \
  --topic=cricket-pipeline \
  --message-body='{}' \
  --location=$REGION \
  --project=$PROJECT_ID

# Enable the job
gcloud scheduler jobs resume auto-pipeline \
  --location=$REGION \
  --project=$PROJECT_ID
```

---

## What Happens Automatically

### Timeline (Hourly Breakdown)

```
05:00 UTC - Cloud Scheduler triggers pipeline
    ↓
05:01 - Cloud Function starts
    ├─ PHASE 1: Create Composer (10-15 min)
    ├─ Config saved to GCS automatically
    │
05:15 - PHASE 2: Auto-runs with Phase 1 output
    ├─ Deploys DAGs automatically
    ├─ Triggers DAG execution automatically
    ├─ Monitors completion (up to 60 min)
    │
06:15 - PHASE 3: Auto-cleanup
    ├─ Deletes Composer environment
    ├─ Saves GCS state
    ├─ Stops billing (saves ~$150/day)
    │
06:20 - Pipeline complete
    ├─ BigQuery updated with new data
    ├─ Looker Studio auto-refreshed
    └─ Ready for next scheduled run
```

---

## Architecture Diagram

```
Cloud Scheduler (Daily 05:00 UTC)
    ↓ (Pub/Sub trigger)
Cloud Function: auto-orchestrator
    ├─────────────────────────────────────────────┐
    │                                             │
    ├─ PHASE 1 (10-15 min)                       │
    │  ├─ Create Composer                        │
    │  ├─ Save config to GCS                     │
    │  └─ Return config for Phase 2              │
    │         ↓                                   │
    ├─ PHASE 2 (20-30 min) [Auto-triggered]      │
    │  ├─ Deploy DAGs                            │
    │  ├─ Run cricket_analytics_dag              │
    │  ├─ Monitor execution (60 min max)         │
    │  └─ Collect metrics                        │
    │         ↓                                   │
    ├─ PHASE 3 (5 min)                           │
    │  ├─ Delete Composer                        │
    │  ├─ Stop billing                           │
    │  └─ Return to idle                         │
    │         ↓                                   │
    └──────────────────────────────────────────────┘
                    ↓
            BigQuery Updated
                    ↓
            Looker Studio Refreshed
                    ↓
        ✅ Fully Automated Complete!
```

---

## Monitoring & Logs

### View Function Execution Logs

```bash
# Real-time logs
gcloud functions logs read auto-orchestrator \
  --region us-central1 \
  --project cricket-analytics-prod \
  --limit 50 \
  --follow
```

### Monitor Cloud Scheduler

```bash
# View job details
gcloud scheduler jobs describe auto-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod

# View execution history
gcloud scheduler jobs list-runs auto-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod
```

### Check BigQuery Results

```bash
# Count records ingested today
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) as record_count FROM `cricket-analytics-prod.cricket_raw.batting_rankings` WHERE DATE(ingested_at) = CURRENT_DATE()'

# Check staging transformations
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) as record_count FROM `cricket-analytics-prod.cricket_staging.fact_batting_rankings` WHERE DATE(loaded_at) = CURRENT_DATE()'
```

---

## Cost Breakdown

### Daily Cost

```
Phase 1 (Create Composer):      $0.10
Phase 2 (Run Pipeline):         $0.15
Phase 3 (Delete Composer):      $0.05
─────────────────────────────────────
Total per run:                  $0.30

Daily (1 run):                  $0.30
Monthly (30 runs):              $9.00
Annual (365 runs):              $109.50
```

### Comparison

| Model | Cost | Savings |
|-------|------|---------|
| Permanent Composer | $540/month | - |
| Automated Pipeline | $9/month | **$531/month (98% savings!)** |

---

## Configuration

### Edit Schedule

```bash
# Change to run daily at 02:00 UTC
gcloud scheduler jobs update pubsub auto-pipeline \
  --schedule "0 2 * * *" \
  --location us-central1 \
  --project cricket-analytics-prod

# Change to run twice daily (02:00 and 14:00 UTC)
# Create another job:
gcloud scheduler jobs create pubsub auto-pipeline-2 \
  --schedule "0 14 * * *" \
  --topic cricket-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod
```

### Pause/Resume Pipeline

```bash
# Pause automation
gcloud scheduler jobs pause auto-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod

# Resume automation
gcloud scheduler jobs resume auto-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod
```

---

## Troubleshooting

### Pipeline Didn't Run

Check logs:
```bash
gcloud functions logs read auto-orchestrator \
  --region us-central1 \
  --limit 100
```

Check Cloud Scheduler:
```bash
gcloud scheduler jobs list \
  --location us-central1 \
  --project cricket-analytics-prod
```

### Cloud Composer Stuck

```bash
# Check Composer environment
gcloud composer environments list \
  --project cricket-analytics-prod

# Delete stuck environment manually
gcloud composer environments delete \
  <env-name> \
  --project cricket-analytics-prod \
  --location us-central1
```

### DAG Not Running

```bash
# Check Composer logs
gcloud composer environments logs read \
  <env-name> \
  --project cricket-analytics-prod

# Check Airflow UI manually
gcloud composer environments describe <env-name> \
  --location us-central1 \
  --format="value(config.airflowUri)"
```

---

## Rollback / Emergency

### Stop All Automated Runs

```bash
gcloud scheduler jobs pause auto-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod
```

### Manual Trigger (Testing)

```bash
# Trigger pipeline immediately
gcloud scheduler jobs run auto-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod
```

### Delete Everything

```bash
# Delete Cloud Function
gcloud functions delete auto-orchestrator \
  --region us-central1 \
  --project cricket-analytics-prod

# Delete Cloud Scheduler job
gcloud scheduler jobs delete auto-pipeline \
  --location us-central1 \
  --project cricket-analytics-prod

# Delete any leftover Composer environments
gcloud composer environments delete \
  cricket-analytics-composer-* \
  --project cricket-analytics-prod \
  --location us-central1
```

---

## ✅ You're Done!

Your cricket analytics pipeline now runs **fully automatically**:

- ✅ No manual scripts
- ✅ No manual Cloud Composer creation
- ✅ No manual DAG deployment
- ✅ No manual monitoring
- ✅ Auto-cleanup & cost savings
- ✅ Daily data updates
- ✅ Zero human intervention

**The pipeline runs, processes data, and cleans up itself. You just monitor the results!** 🤖🚀
