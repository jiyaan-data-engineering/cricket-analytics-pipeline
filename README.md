# Cricket Batting Rankings Data Pipeline

End-to-end GCP data engineering pipeline that ingests ICC Men's Batting Rankings from Cricbuzz API, processes it through Apache Beam Dataflow, and surfaces it in BigQuery with Medallion Architecture (Raw → Staging → Curated) for analytics and dashboard visualization.

## Architecture Overview

```
Cricbuzz API (RapidAPI)
    ↓
[ingestion/fetch_batting_rankings.py] → CSV to GCS
    ↓
GCS Object Finalized Event
    ↓
[cloud_function/main.py] → Triggers Dataflow
    ↓
[dataflow/pipeline.py] → Apache Beam
    ↓
BigQuery RAW LAYER (cricket_raw.batting_rankings)
    ↓
[Scheduled Queries] → Data Transformation
    ↓
BigQuery STAGING LAYER (Star Schema)
    ↓
BigQuery CURATED LAYER (Analytics Views)
    ↓
Looker Studio Dashboard
```

## Project Structure

```
cricket-analytics-pipeline/
├── config/
│   └── config.yaml                    # Configuration (API keys, buckets, datasets) - SOURCE OF TRUTH
│
├── ingestion/
│   ├── fetch_batting_rankings.py      # API ingestion script
│   └── requirements.txt
│
├── cloud_function/
│   ├── main.py                        # GCS trigger → Dataflow launcher
│   └── requirements.txt
│
├── dataflow/
│   ├── pipeline.py                    # Apache Beam Flex Template
│   ├── Dockerfile                     # Container for Flex Template
│   └── requirements.txt
│
├── bigquery/
│   ├── schemas/
│   │   └── raw_batting_rankings.json  # BQ schema (SOURCE OF TRUTH for table structure)
│   └── sql/
│       ├── 01_create_raw_table.sql    # Raw layer + vw_latest_raw
│       ├── 02_create_dim_player.sql   # Staging dimension
│       ├── 03_create_dim_country.sql  # Staging dimension
│       ├── 04_create_dim_format.sql   # Staging dimension
│       ├── 05_create_dim_date.sql     # Staging dimension
│       ├── 06_create_fact_batting.sql # Staging fact table
│       └── 07_create_curated_views.sql# Curated layer (5 views)
│
├── terraform/
│   ├── main.tf                        # Core GCP infrastructure (APIs, SAs, Cloud Function, Scheduler, Composer, Monitoring)
│   ├── gcs.tf                         # GCS buckets (reads from config/config.yaml)
│   ├── bigquery.tf                    # BigQuery datasets & tables (reads from SQL/schema files)
│   ├── cloud_composer.tf              # Cloud Composer configuration
│   ├── variables.tf                   # Configurable variables
│   ├── outputs.tf                     # Output values
│   └── terraform.tfvars               # (Create with your values)
│
├── README.md                          # Quick start & overview (THIS FILE)
└── [Other documentation files]
```

**Key Changes from Previous Structure:**
- `config/config.yaml` is now the **SOURCE OF TRUTH** for bucket and dataset names
- `terraform/gcs.tf` - NEW file that reads bucket names from config.yaml
- `terraform/bigquery.tf` - NEW file that reads schemas and SQL from existing files
- Refactored to **eliminate hardcoding** and **reduce duplication**

## Prerequisites

### Required Tools
- **Terraform** >= 1.0
- **Google Cloud SDK** (gcloud CLI)
- **Python** >= 3.11
- **RapidAPI Account** with Cricbuzz Cricket API subscription

### GCP Setup
1. Create a new GCP project
2. Enable billing
3. Set project as default:
   ```bash
   gcloud config set project YOUR_PROJECT_ID
   ```

### RapidAPI Setup
1. Sign up at https://rapidapi.com/
2. Subscribe to [Cricbuzz Cricket API](https://rapidapi.com/cricketapilive/api/cricbuzz-cricket)
3. Get your RapidAPI key from dashboard → My apps

## Installation & Deployment

### Step 1: Configure Variables

Create `terraform/terraform.tfvars`:
```hcl
gcp_project_id       = "your-gcp-project-id"
gcp_region          = "us-central1"
gcp_zone            = "us-central1-a"
environment         = "dev"
bucket_prefix       = "cricket-analytics"
dataflow_machine_type = "n1-standard-2"
dataflow_num_workers = 2
dataflow_max_workers = 5
rapidapi_key        = "your-rapidapi-key-here"
```

### Step 2: Set Environment Variables

```bash
# For ingestion script
export RAPIDAPI_KEY="your-rapidapi-key"
export GCP_PROJECT="your-gcp-project-id"
```

### Step 3: Update Configuration

Edit `config/config.yaml`:
```yaml
gcp:
  project_id: "your-gcp-project-id"
  region: "us-central1"

apis:
  rapidapi:
    api_key: "your-rapidapi-key"  # or use env var ${RAPIDAPI_KEY}
```

### Step 4: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

This creates:
- GCS buckets (raw data, templates, temp)
- BigQuery datasets (raw, staging, curated)
- Service accounts and IAM roles
- Cloud Scheduler job (daily 06:00 UTC)
- Eventarc trigger (GCS → Cloud Function)
- Cloud Function 2nd Gen
- Artifact Registry repository

### Step 5: Deploy Cloud Function

Package and deploy the Cloud Function:

```bash
# Create deployment package
cd cloud_function
pip install -r requirements.txt
cd ..
zip -r cloud-function-source.zip cloud_function/

# Upload to GCS
gsutil cp cloud-function-source.zip \
  gs://cricket-analytics-dataflow-templates-YOUR_PROJECT/

# Deploy via gcloud (Terraform does this, but manual deploy example)
gcloud functions deploy cricket-gcs-dataflow-trigger \
  --gen2 \
  --runtime python311 \
  --trigger-event google.cloud.storage.object.v1.finalized \
  --trigger-resource cricket-analytics-raw-data-YOUR_PROJECT \
  --entry-point process_batting_file \
  --region us-central1 \
  --service-account cricket-cloud-function-sa@YOUR_PROJECT.iam.gserviceaccount.com
```

### Step 6: Build & Push Dataflow Flex Template

```bash
# Set variables from config.yaml or terraform.tfvars
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"
export REGISTRY="${REGION}-docker.pkg.dev"

# Build Docker image
cd dataflow
docker build -t cricket-pipeline:latest .

# Tag for Artifact Registry (from terraform artifact_registry_name variable)
docker tag cricket-pipeline:latest \
  ${REGISTRY}/${PROJECT_ID}/cricket-docker/batting-pipeline:latest

# Configure Docker auth
gcloud auth configure-docker ${REGISTRY}

# Push to Artifact Registry
docker push ${REGISTRY}/${PROJECT_ID}/cricket-docker/batting-pipeline:latest

# Build Flex Template metadata (references gcs_templates_bucket_name from config.yaml)
gcloud dataflow flex-template build \
  gs://cricket-dataflow-templates/batting-pipeline/metadata \
  --image=${REGISTRY}/${PROJECT_ID}/cricket-docker/batting-pipeline:latest \
  --sdk-language=PYTHON
```

**Note**: Bucket name `cricket-dataflow-templates` comes from `config/config.yaml` (gcs.template_bucket).

### Step 7: Create BigQuery Tables and Views

```bash
# Set project ID
export PROJECT_ID=$(gcloud config get-value project)

# Replace {PROJECT_ID} placeholder in SQL files with actual project ID
cd bigquery/sql

# Function to run SQL with variable substitution
run_sql() {
  local file=$1
  echo "Running: $file"
  sed "s/{PROJECT_ID}/${PROJECT_ID}/g" "$file" | bq query --use_legacy_sql=false --project_id=${PROJECT_ID}
}

# Run all SQL scripts in order
run_sql 01_create_raw_table.sql
run_sql 02_create_dim_player.sql
run_sql 03_create_dim_country.sql
run_sql 04_create_dim_format.sql
run_sql 05_create_dim_date.sql
run_sql 06_create_fact_batting.sql
run_sql 07_create_curated_views.sql

cd ../..
```

**Note**: SQL files reference the schema from `bigquery/schemas/raw_batting_rankings.json`. Dataset names come from `config/config.yaml`.

## Testing & Verification

### Test 1: Run Ingestion Script Locally

```bash
cd ingestion
pip install -r requirements.txt
python fetch_batting_rankings.py
```

Expected output:
- Fetches rankings for Test, ODI, and T20I
- Creates CSV file with timestamp
- Uploads to `gs://cricket-analytics-raw-data-YOUR_PROJECT/batting/`
- Logs show record counts per format

### Test 2: Manual GCS File Upload (Cloud Function Trigger)

```bash
# Manually upload a test CSV to trigger Cloud Function
gsutil cp path/to/test.csv \
  gs://cricket-analytics-raw-data-YOUR_PROJECT/batting/

# Check Cloud Function logs
gcloud functions logs read cricket-gcs-dataflow-trigger \
  --gen2 \
  --region us-central1 \
  --limit 50
```

### Test 3: Monitor Dataflow Job

```bash
# List running jobs
gcloud dataflow jobs list --region us-central1

# Watch specific job
gcloud dataflow jobs show JOB_ID --region us-central1
```

### Test 4: Verify BigQuery Data

```bash
# Check raw data
bq query --use_legacy_sql=false \
  'SELECT COUNT(*), FORMAT FROM `PROJECT_ID.cricket_raw.batting_rankings` GROUP BY FORMAT'

# Check curated views
bq query --use_legacy_sql=false \
  'SELECT * FROM `PROJECT_ID.cricket_curated.vw_current_rankings` LIMIT 10'
```

## Daily Schedule & Automation

The pipeline runs automatically every day at **06:00 UTC** (configurable via config.yaml):

1. **Cloud Scheduler** triggers ingestion job (schedule from `config.yaml` → `terraform/variables.tf`)
2. **Ingestion Script** fetches data → uploads CSV to GCS bucket (name from `config.yaml`)
3. **GCS Finalized Event** → triggers Cloud Function (event-driven)
4. **Cloud Function** validates file and launches Dataflow Flex Template
5. **Dataflow Pipeline** reads CSV → validates → writes to BigQuery RAW layer (dataset from `config.yaml`)
6. **Scheduled Query** transforms RAW → STAGING (star schema, via SQL scripts in `bigquery/sql/`)
7. **Scheduled Query** generates CURATED views (via SQL scripts)
8. **Looker Studio** dashboard auto-refreshes (configurable)

To modify schedule, edit `config.yaml`:
```yaml
scheduling:
  ingestion_schedule: "0 6 * * *"  # Cron format - passed to Cloud Scheduler
```

All bucket names and dataset names come from:
- **Primary source**: `config/config.yaml`
- **Override source**: `terraform/terraform.tfvars` (optional)

## Creating the Looker Studio Dashboard

1. Go to [Looker Studio](https://lookerstudio.google.com/)
2. Create new report
3. Add data source → BigQuery → Select project → Choose `cricket_curated` dataset
4. Add pages and charts:
   - **Overview**: Table from `vw_current_rankings`, scorecard showing total players
   - **Player Trends**: Chart from `vw_ranking_trend` (line chart by date)
   - **Top 10 Analysis**: Table from `vw_top10_by_format` (filtered by format dropdown)
   - **Country Analysis**: Chart from `vw_country_summary` (bar chart)
   - **Format Comparison**: Table from `vw_player_format_comparison`
5. Share dashboard with stakeholders

## Data Model

### RAW Layer
- **Table**: `cricket_raw.batting_rankings`
- **Location**: Dataset name from `config.yaml` (bq_raw_dataset) + table from `variables.tf` (bq_raw_table_name)
- **Schema**: Defined in `bigquery/schemas/raw_batting_rankings.json` (loaded by terraform/bigquery.tf)
- **Partitioned by**: `DATE(ingested_at)` - 90 days retention
- **Clustered by**: `format`, `country`
- **Columns**: Exact API response + ingestion metadata (11 columns defined in Terraform)

### STAGING Layer (Star Schema)
Created via SQL scripts in `bigquery/sql/02_*.sql` through `06_*.sql`:

**Dimensions:**
- `dim_player` - player_id, name, country_id (SCD Type 1, MERGE logic in 02_create_dim_player.sql)
- `dim_country` - country_id, name, icc_code (created in 03_create_dim_country.sql)
- `dim_format` - format_id: 1=Test, 2=ODI, 3=T20I (static lookup in 04_create_dim_format.sql)
- `dim_date` - daily grain from 2015-2035 (7305 rows, created in 05_create_dim_date.sql)

**Facts:**
- `fact_batting_rankings` - daily snapshot (player_id FK, format_id FK, date_id FK, rank, rating, points, best_rank)
  - Partitioned by: loaded_at
  - Clustered by: format_id, country_id
  - Created via 06_create_fact_batting.sql with MERGE logic

### CURATED Layer (Views)
All 5 analytics views created via `bigquery/sql/07_create_curated_views.sql`:
- `vw_current_rankings` - Latest snapshot per player+format
- `vw_ranking_trend` - Historical progression (90 days)
- `vw_top10_by_format` - Top 10 players per format
- `vw_country_summary` - Country aggregates
- `vw_player_format_comparison` - Same player across formats

## Monitoring & Troubleshooting

### Cloud Logging

```bash
# View Cloud Function logs
gcloud functions logs read cricket-gcs-dataflow-trigger --gen2 --limit 50

# View Dataflow job logs
gcloud dataflow jobs show JOB_ID --region us-central1 --messages

# View Cloud Scheduler logs
gcloud scheduler jobs describe cricket-daily-ingestion \
  --location us-central1 \
  --format json | jq '.executionConfig'
```

### Common Issues

**Issue**: Dataflow job fails with "BigQuery table not found"
- **Solution**: Ensure all SQL scripts in `bigquery/sql/` have been executed

**Issue**: Cloud Function timeout
- **Solution**: Increase timeout in terraform/main.tf → `timeout_seconds`

**Issue**: RapidAPI rate limit exceeded
- **Solution**: Check RapidAPI dashboard, consider upgrading plan, add retry logic

**Issue**: GCS bucket names conflict
- **Solution**: Use unique bucket prefix in terraform.tfvars

## Cost Estimation

**Monthly costs (approximate, dev environment):**
- Cloud Storage: $0.02 (minimal raw data)
- BigQuery: $3-5 (on-demand queries, small datasets)
- Cloud Scheduler: $0.10 (1 job/day)
- Cloud Functions: $0.40 (daily invocations, free tier covers)
- Dataflow: $2-8 (depends on job duration, auto-scales)
- **Total**: ~$6-16/month

Production costs scale with data volume and query frequency.

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Run first ingestion
3. ✅ Verify BigQuery data
4. ✅ Create Looker Studio dashboard
5. 📊 Share dashboard with stakeholders
6. 📈 Monitor metrics and performance
7. 🔄 Optimize Dataflow job parallelism if needed
8. 🛡️ Set up alerts in Cloud Monitoring

## Support & References

- [RapidAPI Cricbuzz API Docs](https://rapidapi.com/cricketapilive/api/cricbuzz-cricket)
- [GCP Dataflow Documentation](https://cloud.google.com/dataflow/docs)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)
- [Looker Studio Help](https://support.google.com/looker-studio)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## License

This project is provided as-is for educational and commercial use.
