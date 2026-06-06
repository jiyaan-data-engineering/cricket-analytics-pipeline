# Cricket Analytics Pipeline - Architecture Document

## Executive Summary

A **production-grade, real-time GCP data pipeline** that ingests ICC Men's Batting Rankings from the Cricbuzz API, transforms it through a medallion architecture (Raw → Staging → Curated), and surfaces insights via Looker Studio dashboards.

**Key Features:**
- ✅ Fully automated daily ingestion and processing
- ✅ Scalable Apache Beam/Dataflow pipeline
- ✅ Star schema dimensional modeling
- ✅ Real-time dashboard analytics
- ✅ Infrastructure-as-Code (Terraform)
- ✅ Production-ready logging and monitoring

---

## System Architecture

### High-Level Data Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           DATA INGESTION LAYER                            │
│                                                                           │
│  Cricbuzz API (RapidAPI)                                                 │
│    ↓                                                                       │
│  [fetch_batting_rankings.py]                                             │
│    • Fetches Test, ODI, T20I rankings                                    │
│    • Converts JSON → CSV                                                  │
│    • Uploads to GCS: gs://cricket-raw-data/batting/                     │
│    • Triggered daily @ 06:00 UTC by Cloud Scheduler                      │
│    • Runs as Cloud Run job                                               │
└──────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────┐
│                           TRIGGER & ORCHESTRATION LAYER                   │
│                                                                           │
│  GCS Object Finalized Event                                               │
│    ↓                                                                       │
│  [Eventarc Trigger]                                                       │
│    • Listens to: gs://cricket-raw-data/batting/*.csv                    │
│    • Invokes Cloud Function on file upload                               │
│    ↓                                                                       │
│  [Cloud Function - 2nd Gen]                                              │
│    • Validates file path matches batting/ prefix                         │
│    • Extracts GCS file URI                                               │
│    • Calls Dataflow API to launch Flex Template job                      │
│    • Passes input file path as parameter                                 │
└──────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────┐
│                           PROCESSING LAYER (BATCH)                        │
│                                                                           │
│  [Apache Beam Dataflow - Flex Template]                                  │
│    • ReadFromGCS: Reads CSV from gs://cricket-raw-data/batting/*.csv    │
│    • ParseCSV: Converts CSV → structured records                         │
│    • Schema Validation: Type casting and validation                      │
│    • WriteToBigQuery: Appends to cricket_raw.batting_rankings            │
│    • Auto-scales: 2-5 workers based on load                              │
│    • Monitoring: Cloud Logging integration                               │
│    • Duration: ~5-10 minutes per run                                     │
└──────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────┐
│                    BIGQUERY DATA WAREHOUSE LAYER                          │
│                                                                           │
│  ╔═══════════════════════════════════════════════════════════════╗      │
│  ║  RAW LAYER (Dataset: cricket_raw)                             ║      │
│  ║  Table: batting_rankings                                      ║      │
│  ║  • Exact copy of ingested data + metadata                    ║      │
│  ║  • Partitioned by: DATE(ingested_at)                         ║      │
│  ║  • Clustered by: format, country                             ║      │
│  ║  • Retention: 90 days                                        ║      │
│  ║  • Columns: rank, player_id, player_name, country, rating,  ║      │
│  ║             points, best_rank, format, ingested_at, ...      ║      │
│  ╚═══════════════════════════════════════════════════════════════╝      │
│                                    ↓                                      │
│                    [Scheduled Query: Daily @ 08:00 UTC]                   │
│                                    ↓                                      │
│  ╔═══════════════════════════════════════════════════════════════╗      │
│  ║  STAGING LAYER (Dataset: cricket_staging)                    ║      │
│  ║  STAR SCHEMA DIMENSIONS:                                     ║      │
│  ║  • dim_player      (player_id, name, country_id)             ║      │
│  ║  • dim_country     (country_id, name, icc_code)              ║      │
│  ║  • dim_format      (format_id, format_name)                  ║      │
│  ║  • dim_date        (date_id, date, week, month, year)        ║      │
│  ║                                                               ║      │
│  ║  FACT TABLE:                                                 ║      │
│  ║  • fact_batting_rankings                                     ║      │
│  ║    (player_id FK, format_id FK, date_id FK, ...)             ║      │
│  ║                                                               ║      │
│  ║  Data Refresh: MERGE (UPSERT) after each raw load            ║      │
│  ║  Partitioned by: loaded_at                                   ║      │
│  ║  Clustered by: format_id, country_id                         ║      │
│  ╚═══════════════════════════════════════════════════════════════╝      │
│                                    ↓                                      │
│                        [BigQuery Views Created]                           │
│                                    ↓                                      │
│  ╔═══════════════════════════════════════════════════════════════╗      │
│  ║  CURATED LAYER (Dataset: cricket_curated)                    ║      │
│  ║  Analytics-Ready Views:                                      ║      │
│  ║  1. vw_current_rankings                                      ║      │
│  ║     - Latest rank/rating per player+format                   ║      │
│  ║     - Filtered by CURRENT_DATE()                             ║      │
│  ║                                                               ║      │
│  ║  2. vw_ranking_trend                                         ║      │
│  ║     - Historical progression (90 days)                       ║      │
│  ║     - LAG window for rank changes                            ║      │
│  ║                                                               ║      │
│  ║  3. vw_top10_by_format                                       ║      │
│  ║     - Top 10 players per format                              ║      │
│  ║                                                               ║      │
│  ║  4. vw_country_summary                                       ║      │
│  ║     - Country aggregates (top 50 players)                    ║      │
│  ║     - Count of top-10, avg rating                            ║      │
│  ║                                                               ║      │
│  ║  5. vw_player_format_comparison                              ║      │
│  ║     - Same player's rank across Test/ODI/T20I                ║      │
│  ║                                                               ║      │
│  ║  Query Pattern: SELECT from fact + dimensions, JOIN with     ║      │
│  ║  date for time-series; materializes on-demand                ║      │
│  ╚═══════════════════════════════════════════════════════════════╝      │
└──────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌──────────────────────────────────────────────────────────────────────────┐
│                       ANALYTICS & VISUALIZATION LAYER                     │
│                                                                           │
│  [Looker Studio Dashboard]                                               │
│    • Connected to cricket_curated dataset via BigQuery connector         │
│    • Auto-refreshes every 60 minutes (configurable)                      │
│    • Pages:                                                              │
│      1. Overview: Top-N rankings, scorecard metrics                      │
│      2. Player Trends: Line chart of rank progression                    │
│      3. Top 10: Table with filters by format                             │
│      4. Country Analysis: Bar chart, pie charts                          │
│      5. Format Comparison: Player comparison across formats              │
│    • Shared with stakeholders via public/private links                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

### Cloud Services
| Component | Service | Details |
|-----------|---------|---------|
| **Ingestion** | Cloud Run + Cloud Scheduler | Python script runs daily, uploads CSV to GCS |
| **Storage (Raw)** | Google Cloud Storage | `cricket-raw-data` bucket, 90-day retention |
| **Orchestration** | Eventarc + Cloud Functions | Event-driven trigger for Dataflow jobs |
| **Processing** | Dataflow (Apache Beam) | Flex Template, auto-scaling 2-5 workers |
| **Data Warehouse** | BigQuery | 3 datasets: raw, staging, curated |
| **Analytics** | Looker Studio | Connected dashboards for stakeholders |
| **Container Registry** | Artifact Registry | Stores Flex Template Docker images |
| **Infrastructure** | Terraform | Infrastructure-as-Code for all resources |
| **Monitoring** | Cloud Logging + Cloud Monitoring | Logs all pipeline stages |

### Programming Languages & Frameworks
- **Python 3.11** — Ingestion, Cloud Function, Dataflow
- **Apache Beam** — Data transformation pipeline
- **Terraform (HCL)** — Infrastructure provisioning
- **SQL (BigQuery)** — Data transformation and analytics
- **Docker** — Container image for Flex Template

---

## Data Model

### Raw Layer (cricket_raw)

**Table: batting_rankings**
- Partitioned: `DATE(ingested_at)`
- Clustered: `format`, `country`
- 90-day retention
- Exact source schema + metadata fields

```
rank INT64
player_id STRING
player_name STRING
country STRING
country_id STRING
rating FLOAT64
points FLOAT64
best_rank INT64
format STRING
ingested_at TIMESTAMP
source_file STRING
```

### Staging Layer (cricket_staging) - Star Schema

**Dimensions:**
1. **dim_player** — Unique players
   - player_id (PK)
   - player_name
   - country_id (FK)
   - last_updated

2. **dim_country** — Cricket-playing nations
   - country_id (PK)
   - country_name
   - icc_code
   - last_updated

3. **dim_format** — Cricket formats (Test, ODI, T20I)
   - format_id (PK): 1=Test, 2=ODI, 3=T20I
   - format_name
   - description

4. **dim_date** — Time dimension (20 years: 2015-2035)
   - date_id (PK)
   - full_date
   - year, quarter, month, week, day
   - day_name, month_name

**Fact Table:**
- **fact_batting_rankings** — Daily snapshot
  - player_id FK
  - country_id FK
  - format_id FK
  - date_id FK
  - rank
  - rating
  - points
  - best_rank
  - source_file
  - loaded_at (partition)

### Curated Layer (cricket_curated) - Analytics Views

| View | Purpose | Key Columns |
|------|---------|------------|
| `vw_current_rankings` | Latest standings | player_name, country_name, format_name, current_rank, current_rating |
| `vw_ranking_trend` | 90-day history | player_name, full_date, rank, rank_change |
| `vw_top10_by_format` | Top performers | rank_position, player_name, format_name, current_rating |
| `vw_country_summary` | Country stats | country_name, players_in_top50, avg_rating |
| `vw_player_format_comparison` | Multi-format analysis | player_name, test_rank, odi_rank, t20i_rank |

---

## Operational Details

### Daily Execution Timeline

```
06:00 UTC  - Cloud Scheduler triggers ingestion job
           ↓
06:02 UTC  - Ingestion script runs
           ├─ Fetches RapidAPI (Test, ODI, T20I)
           ├─ Converts to CSV
           ├─ Uploads to gs://cricket-raw-data/batting/
           
06:05 UTC  - GCS object finalized event triggers
           ↓
06:06 UTC  - Cloud Function invoked
           ├─ Validates file path
           ├─ Calls Dataflow API
           
06:08 UTC  - Dataflow job launched
           ├─ Reads CSV from GCS
           ├─ Parses and validates
           ├─ Writes to BigQuery RAW
           └─ Takes 5-10 minutes
           
06:18 UTC  - Dataflow job completes
           ↓
08:00 UTC  - Scheduled Query runs
           ├─ Transforms RAW → STAGING
           ├─ MERGE into dimensions
           ├─ MERGE into fact table
           ├─ Refreshes curated views
           └─ Takes 2-5 minutes
           
08:05 UTC  - Looker Studio auto-refreshes
           └─ Dashboard shows latest data
```

### Scaling & Performance

| Component | Capacity | Notes |
|-----------|----------|-------|
| **Dataflow** | 2-5 workers | Auto-scales based on data volume |
| **BigQuery** | Unlimited | On-demand pricing, 90-day retention in raw |
| **Cloud Function** | 10 concurrent | Easily handles daily trigger |
| **Looker Studio** | Unlimited viewers | Supports unlimited dashboard shares |
| **Data Volume** | 50-200 records/day | Each format: ~100 ranked players |

### Fault Tolerance

| Failure Scenario | Mitigation |
|-----------------|-----------|
| **API Rate Limit** | Retry logic in ingestion script |
| **Cloud Function Timeout** | Terraform sets 600s timeout |
| **Dataflow Job Failure** | Cloud Logging captures details, can manually rerun |
| **BigQuery Table Exists** | Pipeline uses WRITE_APPEND, idempotent |
| **Scheduled Query Fails** | BQ scheduler retries, sends email alert |

---

## Security & Compliance

### Authentication & Authorization

- **Service Accounts** (least privilege):
  - `cricket-dataflow-sa`: BigQuery Admin, Storage Admin, Dataflow Worker
  - `cricket-cloud-function-sa`: Dataflow Admin, Storage Reader

- **RapidAPI Key**: Stored in Terraform variables (sensitive), injected as environment variable

### Data Privacy

- **PII Handling**: No sensitive personal data (only public cricket rankings)
- **Data Retention**: RAW layer auto-deletes after 90 days
- **Network**: All traffic within GCP (no external data egress)

### Audit & Compliance

- **Cloud Logging**: All operations logged automatically
- **IAM Roles**: Service accounts scoped to minimum permissions
- **Data Lineage**: Tracked via `source_file`, `ingested_at` metadata
- **Scheduling**: Immutable historical records in BigQuery

---

## Cost Analysis

### Estimated Monthly Costs (Dev Environment)

| Service | Usage | Cost |
|---------|-------|------|
| **GCS** | 100 MB raw data | $0.02 |
| **BigQuery** | 100 GB dataset, queries | $3-5 |
| **Dataflow** | 1 job/day × 10 min | $2-3 |
| **Cloud Functions** | 1 invocation/day | $0.10 |
| **Cloud Scheduler** | 1 job/day | $0.10 |
| **Cloud Run** | 1 invocation/day | $0.10 |
| **Looker Studio** | Dashboards (free tier) | $0 |
| **Total** | | **$5-9/month** |

*Pricing increases with:*
- Data volume (bigger CSV files)
- Query frequency (more dashboards/users)
- Worker parallelism (more Dataflow workers)

---

## Monitoring & Observability

### Key Metrics

1. **Ingestion**
   - Records fetched per format
   - API response time
   - CSV upload time

2. **Dataflow**
   - Job duration
   - Worker utilization
   - Records processed
   - Error count/rate

3. **BigQuery**
   - Table row count per dataset
   - Query execution time
   - Cost per dataset

4. **Dashboard**
   - View count
   - User engagement
   - Data freshness

### Logging

All components log to **Cloud Logging**:
- Ingestion script: Python logging
- Cloud Function: `google.cloud.logging` SDK
- Dataflow: Beam job logs
- BigQuery: Query execution logs
- Scheduled Queries: Step logs

### Alerts (Optional)

Configure alerts for:
- Dataflow job failures
- Cloud Function errors (>10% error rate)
- BigQuery quota exceeded
- API rate limit warnings

---

## Disaster Recovery

### Backup Strategy

- **BigQuery Auto-Snapshots**: Dataset snapshots every 7 days
- **GCS Versioning**: Enable in raw data bucket for 30 days
- **Terraform State**: Store in Cloud Storage with versioning

### Recovery Procedures

| Scenario | Recovery |
|----------|----------|
| Lost raw data | Restore from snapshot, re-run Dataflow |
| Corrupted staging | TRUNCATE table, re-run scheduled query |
| Dashboard broken | Check BigQuery connectivity, reload dashboard |

---

## Future Enhancements

1. **Real-Time Streaming** (Optional)
   - Replace batch with Pub/Sub → Dataflow streaming
   - 5-minute latency instead of daily

2. **ML Predictions**
   - Predict player rank movements
   - Anomaly detection for unusual changes

3. **Multiple Data Sources**
   - ESPN Cricket API
   - Custom player statistics
   - Social sentiment analysis

4. **Advanced Dashboards**
   - Player comparison tool
   - Forecast models
   - Historical trend analysis

5. **Data Federation**
   - BigQuery Omni for multi-cloud
   - Connect to data lakes (S3, ADLS)

---

## Support & Maintenance

### Runbooks

- **Pipeline stuck**: Check Cloud Logging, inspect latest Dataflow job
- **Data quality issue**: Query raw data, check RapidAPI response
- **Dashboard not updating**: Verify scheduled query execution

### Documentation
- [README.md](README.md) — Quick start & overview
- [DEPLOYMENT.md](DEPLOYMENT.md) — Step-by-step setup
- [ARCHITECTURE.md](ARCHITECTURE.md) — This document

### SLA

| Component | Target | Notes |
|-----------|--------|-------|
| **Availability** | 99.5% | GCP managed services |
| **Data Freshness** | 24 hours | Daily ingestion at 06:00 UTC |
| **Query Response** | <5 seconds | BigQuery on-demand |
| **Dashboard Load** | <3 seconds | Looker Studio cached |

---

## Conclusion

This architecture provides a **scalable, maintainable, and cost-effective** solution for cricket analytics on GCP. It follows industry best practices for data engineering:

✅ Medallion architecture (separation of concerns)
✅ Infrastructure-as-Code (reproducible deployments)
✅ Event-driven orchestration (serverless, no manual intervention)
✅ Star schema modeling (optimized for analytics)
✅ Comprehensive logging (operational visibility)
✅ Security by default (least privilege IAM)

The pipeline is production-ready and can be extended with additional data sources, real-time streaming, or advanced analytics as needs evolve.

---

**Last Updated**: June 2024
**Version**: 1.0
**Author**: Claude Code
