# 🏗️ Cricket Analytics Pipeline - Best Architecture

## Architecture Overview: FULLY COMPOSED-ORCHESTRATED PIPELINE

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLOUD SCHEDULER (Daily 05:00 UTC)                   │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CLOUD COMPOSER (Apache Airflow 2)                      │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │ DAG: cricket_analytics_full_pipeline (06:00 UTC - on-demand create) │  │
│  │                                                                      │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │ PHASE 1: RAW LAYER INGESTION                               │   │  │
│  │  ├─────────────────────────────────────────────────────────────┤   │  │
│  │  │ ├─ Task: fetch_cricbuzz_api                                │   │  │
│  │  │ │  └─ Call Cricbuzz API (TEST, ODI, T20I)                │   │  │
│  │  │ │     └─ Push CSV to GCS bucket                          │   │  │
│  │  │ │        └─ gs://cricket-raw-data-prod/batting/*.csv    │   │  │
│  │  │ │                                                         │   │  │
│  │  │ ├─ Task: launch_dataflow_raw                             │   │  │
│  │  │ │  └─ Dataflow Flex Template (Apache Beam)              │   │  │
│  │  │ │     ├─ Read: CSV from GCS                            │   │  │
│  │  │ │     ├─ Parse & Validate                              │   │  │
│  │  │ │     └─ Write: BigQuery Raw Layer                     │   │  │
│  │  │ │        └─ cricket_raw.batting_rankings               │   │  │
│  │  │ │           (partitioned by DATE, clustered)           │   │  │
│  │  │ │                                                       │   │  │
│  │  │ └─ Task: validate_raw_data                             │   │  │
│  │  │    └─ Quality checks (row count, nulls)               │   │  │
│  │  │       └─ Store validation logs in audit_logs          │   │  │
│  │  └─────────────────────────────────────────────────────────┘   │  │
│  │                          ▼ (Success)                            │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │ PHASE 2: STAGING LAYER TRANSFORMATION (Star Schema)        │   │  │
│  │  ├─────────────────────────────────────────────────────────────┤   │  │
│  │  │ ├─ Task: create_dim_player                                 │   │  │
│  │  │ │  └─ MERGE from raw → cricket_staging.dim_player        │   │  │
│  │  │ │     (SCD Type 1: overwrite)                             │   │  │
│  │  │ │                                                          │   │  │
│  │  │ ├─ Task: create_dim_country                               │   │  │
│  │  │ │  └─ MERGE from raw → cricket_staging.dim_country       │   │  │
│  │  │ │                                                          │   │  │
│  │  │ ├─ Task: create_dim_format                                │   │  │
│  │  │ │  └─ MERGE → cricket_staging.dim_format                 │   │  │
│  │  │ │                                                          │   │  │
│  │  │ ├─ Task: create_dim_date                                  │   │  │
│  │  │ │  └─ MERGE → cricket_staging.dim_date                   │   │  │
│  │  │ │                                                          │   │  │
│  │  │ └─ Task: create_fact_batting                              │   │  │
│  │  │    └─ MERGE from raw + dims → cricket_staging.fact_*    │   │  │
│  │  │       (Composite key: date-player-format)                │   │  │
│  │  └─────────────────────────────────────────────────────────────┘   │  │
│  │                          ▼ (Success)                            │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │ PHASE 3: CURATED LAYER (Analytics Views)                   │   │  │
│  │  ├─────────────────────────────────────────────────────────────┤   │  │
│  │  │ ├─ Task: create_vw_latest_rankings                         │   │  │
│  │  │ │  └─ CREATE OR REPLACE VIEW cricket_curated.vw_*         │   │  │
│  │  │ │     (Latest rank/rating per player+format)              │   │  │
│  │  │ │                                                          │   │  │
│  │  │ ├─ Task: create_vw_ranking_trend                          │   │  │
│  │  │ │  └─ 90-day history with LAG() for rank changes         │   │  │
│  │  │ │                                                          │   │  │
│  │  │ ├─ Task: create_vw_top10                                  │   │  │
│  │  │ │  └─ Top 10 batsmen per format                           │   │  │
│  │  │ │                                                          │   │  │
│  │  │ ├─ Task: create_vw_country_stats                          │   │  │
│  │  │ │  └─ Country-level aggregates                            │   │  │
│  │  │ │                                                          │   │  │
│  │  │ └─ Task: create_vw_format_comparison                      │   │  │
│  │  │    └─ Cross-format pivot (test_rank, odi_rank, t20_rank) │   │  │
│  │  └─────────────────────────────────────────────────────────────┘   │  │
│  │                          ▼ (Success)                            │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │ PHASE 4: REPORTING & REFRESH                               │   │  │
│  │  ├─────────────────────────────────────────────────────────────┤   │  │
│  │  │ ├─ Task: refresh_looker_studio                             │   │  │
│  │  │ │  └─ Trigger dashboard refresh (webhooks/APIs)           │   │  │
│  │  │ │                                                          │   │  │
│  │  │ ├─ Task: generate_data_quality_report                     │   │  │
│  │  │ │  └─ Audit logs → cricket_audit_logs.pipeline_runs      │   │  │
│  │  │ │                                                          │   │  │
│  │  │ └─ Task: notify_completion                                │   │  │
│  │  │    └─ Success email/Slack notification                    │   │  │
│  │  └─────────────────────────────────────────────────────────────┘   │  │
│  │                                                                  │  │
│  │  COMPLETE AUDIT TRAIL in Airflow UI                           │  │
│  │  ├─ Task execution logs                                       │  │
│  │  ├─ Data lineage (which task → which BQ table)              │  │
│  │  ├─ Performance metrics (duration, retries)                  │  │
│  │  └─ SLA monitoring                                           │  │
│  │                                                                  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  RESOURCE LIFECYCLE MANAGEMENT:                                        │
│  ├─ On-demand Composer creation (save $150/day)                       │
│  ├─ Auto-cleanup after completion                                     │
│  └─ Cost: ~$0.30/run (~$9/month)                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
        ┌──────────────────────────────────────┐
        │     BIGQUERY DATA WAREHOUSE          │
        ├──────────────────────────────────────┤
        │ RAW LAYER (Transactional)            │
        │ ├─ batting_rankings (partitioned)    │
        │ └─ vw_latest_raw (debug view)        │
        │                                      │
        │ STAGING LAYER (Star Schema)          │
        │ ├─ dim_player                        │
        │ ├─ dim_country                       │
        │ ├─ dim_format                        │
        │ ├─ dim_date                          │
        │ └─ fact_batting_rankings             │
        │                                      │
        │ CURATED LAYER (Analytics Ready)      │
        │ ├─ vw_latest_rankings                │
        │ ├─ vw_ranking_trend                  │
        │ ├─ vw_top10_by_format                │
        │ ├─ vw_country_summary                │
        │ └─ vw_ranking_comparison             │
        │                                      │
        │ AUDIT LAYER (Compliance)             │
        │ └─ pipeline_runs (all metadata)      │
        └──────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │      LOOKER STUDIO DASHBOARDS        │
        ├──────────────────────────────────────┤
        │ • Current Rankings                   │
        │ • 90-Day Trends                      │
        │ • Top 10 Players                     │
        │ • Country Statistics                 │
        │ • Format Comparison                  │
        │ • Data Quality Metrics               │
        └──────────────────────────────────────┘
```

---

## 🎯 Key Features of This Architecture

### 1. **Single Orchestrator (Composer Only)**
- All phases managed in ONE Airflow DAG
- Sequential task groups ensure proper data flow
- Complete audit trail in Airflow UI
- No external triggers or dependencies

### 2. **Data Flow Isolation**
- Each layer independent but dependent on previous
- Raw → Staging → Curated → Dashboard
- Idempotent operations (MERGE, CREATE OR REPLACE)
- Safe for re-runs and backfills

### 3. **Cost Optimization**
- On-demand Composer creation (saves $150/day)
- Auto-cleanup after pipeline completes
- Estimated cost: **$0.30/run** (~$9/month with daily runs)

### 4. **Observability & Compliance**
- Airflow UI shows complete execution history
- Data lineage tracking (which task → which BQ table)
- Audit logs for all pipeline runs
- SLA monitoring and alerting
- Quality metrics in dashboard

### 5. **Scalability**
- Dataflow auto-scales workers (2-5 workers)
- BigQuery handles 300-500 daily records easily
- Partitioning & clustering for query performance
- View-based analytics don't bloat warehouse

---

## 📊 Pipeline Sequence Diagram

```
Cloud Scheduler (05:00 UTC)
    ↓
Start Composer Creation (15 min)
    ↓
DAG Execution:
    Phase 1 (5 min):  API → CSV → Dataflow → BQ Raw
    Phase 2 (20 min): Raw → Staging (MERGE dim + fact)
    Phase 3 (5 min):  Staging → Curated (CREATE VIEW)
    Phase 4 (2 min):  Audit logs + Dashboard refresh
    ↓
Stop Composer (5 min)
    ↓
Total: ~52 minutes, $0.30 cost, 100% automated
```

---

## 🚀 Deployment Command

```bash
# Tag and push to trigger full automation
git tag release-v1.0.0
git push origin release-v1.0.0

# GitHub Actions automatically:
# 1. Creates Terraform infrastructure
# 2. Builds Dataflow Flex Template
# 3. Deploys Composer DAGs
# 4. Configures Cloud Scheduler
# 5. Sets up BigQuery tables
```

---

## ✅ Checklist: Fully Automated End-to-End

- ✅ **GCS Bucket**: Auto-created (Terraform)
- ✅ **Dataflow Template**: Auto-built (Cloud Build) + deployed
- ✅ **BigQuery Raw**: Auto-created, auto-populated
- ✅ **BigQuery Staging**: Auto-created, auto-transformed
- ✅ **BigQuery Curated**: Auto-created, auto-refreshed
- ✅ **Cloud Composer**: Auto-creates on-demand
- ✅ **Cloud Scheduler**: Auto-configured (daily 05:00 UTC)
- ✅ **Looker Studio**: Auto-refreshed after pipeline completes
- ✅ **Audit Logging**: All operations logged
- ✅ **Cost Optimization**: 98% savings via on-demand Composer

**ZERO MANUAL STEPS AFTER DEPLOYMENT** ✨
