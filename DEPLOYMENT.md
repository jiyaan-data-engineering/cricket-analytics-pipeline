# Cricket Analytics Pipeline - Deployment Guide

## Quick Start

### 1. Prerequisites
- GCP Project: `cricket-analytics-prod`
- Service Account with necessary permissions
- `gcloud` CLI installed and authenticated
- Terraform state bucket: `cricket-tf-state-prod`
- GitHub secrets configured (see `.github/workflows/deploy-prod.yml`)

### 2. Deploy Infrastructure

The infrastructure is automatically deployed via GitHub Actions when you create a release tag:

```bash
git tag release-v1.9.0
git push origin release-v1.9.0
```

This triggers the full pipeline:
1. **Validation** — Terraform format & validation
2. **Security** — Secret scanning & TFLint checks
3. **Plan** — Terraform plan review
4. **Cost Estimation** — Monthly cost breakdown
5. **Manual Approval** — Required in GitHub UI
6. **Apply** — Creates all GCP infrastructure
7. **BigQuery Setup** — Runs all SQL scripts
8. **Health Checks** — Verifies deployment

### 3. Deploy Cloud Composer (AFTER infrastructure is ready)

Once the workflow completes, deploy Cloud Composer using the provided script:

```bash
./scripts/deploy-composer.sh cricket-analytics-prod us-central1
```

This:
- Creates a 3-node Cloud Composer environment
- Configures Airflow environment variables
- Deploys both Airflow DAGs
- Outputs the Airflow UI URL

**Note**: Takes 10-15 minutes to complete. This is done manually because Terraform provider has formatting issues with this complex resource.

## Architecture

```
Cloud Scheduler (06:00 UTC)
    ↓
Cloud Run / API Ingestion
    → Cricbuzz API
    → CSV to GCS
        ↓
Eventarc (GCS finalized)
    ↓
Cloud Function
    → Launches Dataflow
        ↓
Dataflow (Apache Beam)
    → Parses CSV
    → Writes to BigQuery RAW
        ↓
BigQuery STAGING (Scheduled Query 08:00 UTC)
    → dim_player, dim_country, dim_format, dim_date
    → fact_batting_rankings
        ↓
BigQuery CURATED (Views)
    → Analytics views for Looker Studio
        ↓
Cloud Composer / Airflow (06:00 UTC Daily)
    → Full orchestration with monitoring
    → Data quality checks
    → Alerting
```

## Project Structure

```
cricket-analytics-pipeline/
├── .github/
│   └── workflows/
│       └── deploy-prod.yml          # Main CI/CD pipeline
├── infrastructure/
│   └── terraform/
│       ├── main.tf                  # GCP resources
│       ├── variables.tf
│       ├── outputs.tf
│       └── environments/
│           └── prod.tfvars
├── pipeline/
│   ├── bigquery/
│   │   └── sql/                     # BigQuery DDL scripts
│   ├── dataflow/
│   │   └── pipeline.py              # Apache Beam processing
│   ├── airflow/
│   │   └── dags/                    # Airflow DAGs
│   ├── cloud_function/
│   │   └── main.py                  # Event-driven trigger
│   └── ingestion/
│       └── fetch_batting_rankings.py # API ingestion
└── scripts/
    └── deploy-composer.sh            # Cloud Composer deployment
```

## Resource Inventory

### GCS Buckets
- `cricket-raw-data-prod` — Raw CSV uploads
- `cricket-dataflow-templates-prod` — Dataflow Flex Template
- `cricket-dataflow-temp-prod` — Dataflow scratch space
- `cricket-tf-state-prod` — Terraform state (not created by TF)

### BigQuery Datasets
- `cricket_raw` — Raw data table + debug views
- `cricket_staging` — Star schema (dimensions + facts)
- `cricket_curated` — Analytics views
- `cricket_audit_logs` — Pipeline audit trail

### Service Accounts
- `cricket-dataflow-sa@...` — Dataflow execution (created manually)
- `cricket-cloud-function-sa@...` — Cloud Function execution
- `cricket-cloud-run-sa@...` — Cloud Run execution
- `cricket-composer-sa@...` — Cloud Composer execution

## Manual Steps

These require manual setup (not automated by Terraform):

### 1. Build & Deploy Dataflow Flex Template
```bash
gcloud builds submit \
  --config=pipeline/dataflow/cloudbuild.yaml \
  --project=cricket-analytics-prod \
  gs://cricket-dataflow-templates-prod/flex-template.yaml
```

### 2. Create Cloud Function
```bash
gcloud functions deploy cricket-dataflow-trigger \
  --runtime python3.11 \
  --trigger-event-type google.cloud.storage.object.v1.finalized \
  --trigger-resource cricket-raw-data-prod \
  --entry-point process_batting_file \
  --source=pipeline/cloud_function \
  --project=cricket-analytics-prod
```

### 3. Create Cloud Scheduler Job
```bash
gcloud scheduler jobs create http cricket-ingestion \
  --schedule "0 6 * * *" \
  --uri "https://your-cloud-run-url" \
  --http-method POST \
  --project=cricket-analytics-prod
```

### 4. Deploy Cloud Composer
```bash
./scripts/deploy-composer.sh cricket-analytics-prod us-central1
```

### 5. Create Looker Studio Dashboard
Connect to `cricket_curated` dataset for analytics:

1. Go to [Looker Studio](https://lookerstudio.google.com)
2. Click **Create** → **Report**
3. Connect to BigQuery:
   - Click **Create new data source**
   - Choose **BigQuery**
   - Select `cricket-analytics-prod` project
   - Select `cricket_curated` dataset
4. Add visualizations using these views:
   - `vw_batting_rankings_latest` — Current rankings table
   - `vw_batting_rankings_90day_trend` — Trend over 90 days
   - `vw_top_10_batsmen_by_format` — Top 10 per format (Test/ODI/T20I)
   - `vw_batting_statistics_by_country` — Country aggregates
   - `vw_ranking_comparison_cross_format` — Multi-format comparison
5. Configure auto-refresh (daily at 09:00 UTC, after BigQuery scheduled query)
6. Share dashboard with stakeholders

## Monitoring & Alerting

- **BigQuery** — Check `cricket_raw.batting_rankings` for daily row counts
- **Cloud Logging** — Monitor Dataflow, Cloud Function, Cloud Run
- **Cloud Monitoring** — View metrics dashboards for all resources
- **Airflow UI** — Access via the URL output by `deploy-composer.sh`

## Cost Breakdown

| Service | Estimated Monthly Cost |
|---------|----------------------|
| BigQuery | $50–200 |
| Cloud Storage | $20–50 |
| Dataflow | $300–500 |
| Cloud Composer | $1,500–2,000 |
| Cloud Function | $5–10 |
| Cloud Scheduler | <$1 |
| **Total** | **~$1,900–2,800** |

## Troubleshooting

### Terraform formatting issues
- Ensure all `*.tf` files pass: `terraform fmt -check -recursive infrastructure/terraform/`

### BigQuery SQL errors
- Check dataset names match: `cricket_raw`, `cricket_staging`, `cricket_curated`
- Verify service account has BigQuery Editor role

### Dataflow template errors
- Ensure Docker image is pushed to Artifact Registry
- Check input/output GCS buckets exist and are accessible

### Cloud Composer DAG deployment errors
- Verify environment exists: `gcloud composer environments list --location us-central1`
- Check DAG syntax: `python -m py_compile pipeline/airflow/dags/*.py`
- Review Airflow logs in Cloud Composer environment

## Support

For questions or issues, check:
1. GitHub Actions workflow logs
2. Cloud Logging dashboard for your project
3. BigQuery job history for SQL errors
4. Airflow UI for DAG execution history
