# Complete Deployment Guide

## Pre-Deployment Checklist

- [ ] GCP project created
- [ ] Billing enabled on GCP project
- [ ] RapidAPI account created + Cricbuzz Cricket API subscribed
- [ ] Local tools installed: gcloud CLI, Terraform, Docker, Python 3.11+
- [ ] Authenticated with GCP: `gcloud auth login`
- [ ] Default GCP project set: `gcloud config set project YOUR_PROJECT_ID`

## Deployment Steps

### 1. Prepare Configuration Files

#### 1.1 Create terraform/terraform.tfvars

```bash
cat > terraform/terraform.tfvars << 'EOF'
gcp_project_id       = "your-gcp-project-id"
gcp_region          = "us-central1"
gcp_zone            = "us-central1-a"
environment         = "dev"
bucket_prefix       = "cricket-analytics"
dataflow_machine_type = "n1-standard-2"
dataflow_num_workers = 2
dataflow_max_workers = 5
rapidapi_key        = "your-rapidapi-key-from-rapidapi.com"
EOF
```

#### 1.2 Update config/config.yaml

```bash
# Replace placeholders
sed -i 's/cricket-analytics-project/your-gcp-project-id/g' config/config.yaml
sed -i 's/${RAPIDAPI_KEY}/your-rapidapi-key/g' config/config.yaml
```

### 2. Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform working directory
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan -out=tfplan

# Apply changes (creates GCS buckets, BigQuery datasets, IAM roles, etc.)
terraform apply tfplan

# Save outputs
terraform output -json > outputs.json

cd ..
```

**This creates:**
- ✅ 3 GCS buckets (raw-data, dataflow-templates, dataflow-temp)
- ✅ 3 BigQuery datasets (cricket_raw, cricket_staging, cricket_curated)
- ✅ Service accounts (dataflow-sa, cloud-function-sa)
- ✅ Cloud Scheduler job (daily at 06:00 UTC)
- ✅ IAM roles and permissions
- ✅ Artifact Registry repository

### 3. Deploy Dataflow Flex Template

#### 3.1 Build and Push Docker Image

```bash
# Set variables
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"
export REGISTRY="${REGION}-docker.pkg.dev"
export REPOSITORY="cricket-dataflow-templates"
export IMAGE_NAME="batting-pipeline"

# Configure Docker authentication
gcloud auth configure-docker ${REGISTRY}

# Build Docker image
cd dataflow
docker build -t ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest .

# Push to Artifact Registry
docker push ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest

echo "✅ Docker image pushed: ${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest"
```

#### 3.2 Build Flex Template Metadata

```bash
# Build Flex Template
gcloud dataflow flex-template build \
  gs://cricket-analytics-dataflow-templates-${PROJECT_ID}/batting-pipeline \
  --image=${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest \
  --sdk-language=PYTHON \
  --flex-template-base-image=PYTHON3

echo "✅ Flex Template built at: gs://cricket-analytics-dataflow-templates-${PROJECT_ID}/batting-pipeline"

cd ..
```

### 4. Create BigQuery Tables and Views

```bash
# Set project context
export PROJECT_ID=$(gcloud config get-value project)

# Function to run SQL file with variable substitution
run_sql() {
  local file=$1
  sed "s/{PROJECT_ID}/${PROJECT_ID}/g" "$file" | bq query --use_legacy_sql=false --project_id=${PROJECT_ID}
}

cd bigquery/sql

echo "Creating RAW layer..."
run_sql 01_create_raw_table.sql

echo "Creating STAGING dimensions..."
run_sql 02_create_dim_player.sql
run_sql 03_create_dim_country.sql
run_sql 04_create_dim_format.sql
run_sql 05_create_dim_date.sql

echo "Creating STAGING fact table..."
run_sql 06_create_fact_batting.sql

echo "Creating CURATED views..."
run_sql 07_create_curated_views.sql

echo "✅ BigQuery tables and views created"

cd ../..
```

### 5. Deploy Cloud Function

The Terraform configuration deploys the Cloud Function, but to verify:

```bash
export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-central1"

# Check Cloud Function status
gcloud functions describe cricket-gcs-dataflow-trigger \
  --gen2 \
  --region ${REGION} \
  --project ${PROJECT_ID}

# View recent executions
gcloud functions logs read cricket-gcs-dataflow-trigger \
  --gen2 \
  --region ${REGION} \
  --limit 10

echo "✅ Cloud Function deployed"
```

### 6. Test the Pipeline

#### 6.1 Test Ingestion Script Locally

```bash
# Install dependencies
pip install -r ingestion/requirements.txt

# Set environment variable
export RAPIDAPI_KEY="your-rapidapi-key"
export GCP_PROJECT=$(gcloud config get-value project)

# Run ingestion
python ingestion/fetch_batting_rankings.py

# Check for CSV in GCS
gsutil ls gs://cricket-analytics-raw-data-${GCP_PROJECT}/batting/

echo "✅ Ingestion test complete"
```

#### 6.2 Test Cloud Function & Dataflow Integration

```bash
export PROJECT_ID=$(gcloud config get-value project)

# Create a test CSV file
cat > test_batting.csv << 'EOF'
rank,player_id,player_name,country,country_id,rating,points,best_rank,format,ingested_at
1,p123,Virat Kohli,India,ind,900.5,6000.0,1,TEST,2024-06-05T00:00:00
2,p456,Steve Smith,Australia,aus,890.2,5950.0,1,TEST,2024-06-05T00:00:00
EOF

# Upload to GCS (this triggers Cloud Function)
gsutil cp test_batting.csv \
  gs://cricket-analytics-raw-data-${PROJECT_ID}/batting/test_batting_20240605_120000.csv

# Wait 5 seconds for Cloud Function to trigger
sleep 5

# Check Cloud Function logs
gcloud functions logs read cricket-gcs-dataflow-trigger \
  --gen2 \
  --region us-central1 \
  --limit 20

# Check for Dataflow jobs
gcloud dataflow jobs list --region us-central1

echo "✅ Cloud Function & Dataflow integration test complete"
```

#### 6.3 Verify BigQuery Data

```bash
export PROJECT_ID=$(gcloud config get-value project)

# Query raw data
echo "Checking cricket_raw.batting_rankings:"
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) as total_records, FORMAT FROM \`${PROJECT_ID}.cricket_raw.batting_rankings\` GROUP BY FORMAT"

# Query curated views
echo "Checking cricket_curated.vw_current_rankings:"
bq query --use_legacy_sql=false \
  "SELECT * FROM \`${PROJECT_ID}.cricket_curated.vw_current_rankings\` LIMIT 5"

echo "✅ BigQuery verification complete"
```

### 7. Create Looker Studio Dashboard

1. Open [Looker Studio](https://lookerstudio.google.com/)
2. Click **+ Create** → **Report**
3. Add data source:
   - Click **Resource** → **Manage connected data sources**
   - Add **BigQuery** connector
   - Select your GCP project
   - Choose `cricket_curated` dataset
4. Create dashboard pages:

#### Page 1: Overview
- Add scorecard: "Total Players in Rankings" (COUNT from vw_current_rankings)
- Add table: vw_current_rankings (all columns, filtered by format)
- Add filter: Format dropdown

#### Page 2: Player Trends
- Add line chart: vw_ranking_trend (Date on X-axis, Rank on Y-axis)
- Add filter: Player Name text input
- Show rank movement over 90 days

#### Page 3: Top 10 by Format
- Add table: vw_top10_by_format
- Add filter: Format dropdown
- Show top 10 players per format

#### Page 4: Country Analysis
- Add bar chart: vw_country_summary (Country, Players in Top 50)
- Add pie chart: vw_country_summary (Country representation)
- Add metric: Average Rating by country

#### Page 5: Format Comparison
- Add table: vw_player_format_comparison
- Show same player's rank across Test/ODI/T20I

5. Share dashboard:
   - Click **Share** → Add email addresses
   - Set permissions (View/Edit)
   - Get shareable link

### 8. Set Up Monitoring & Alerts (Optional)

```bash
export PROJECT_ID=$(gcloud config get-value project)

# Create alert for failed Dataflow jobs
gcloud monitoring alert-policies create \
  --display-name="Dataflow Job Failure" \
  --condition="FAILED_JOB_COUNT > 0" \
  --notification-channels=${NOTIFICATION_CHANNEL_ID}

# Create alert for Cloud Function errors
gcloud monitoring alert-policies create \
  --display-name="Cloud Function Errors" \
  --condition="CLOUD_FUNCTION_ERROR_RATE > 0.1" \
  --notification-channels=${NOTIFICATION_CHANNEL_ID}

echo "✅ Monitoring alerts configured"
```

## Verification Checklist

After deployment, verify:

- [ ] GCS buckets created (cricket-analytics-raw-data-*, cricket-analytics-dataflow-templates-*, cricket-analytics-dataflow-temp-*)
- [ ] BigQuery datasets created (cricket_raw, cricket_staging, cricket_curated)
- [ ] BigQuery tables created (batting_rankings, dim_player, dim_country, dim_format, dim_date, fact_batting_rankings)
- [ ] BigQuery views created (5 curated views)
- [ ] Service accounts created with correct IAM roles
- [ ] Cloud Scheduler job created (daily at 06:00 UTC)
- [ ] Dataflow Flex Template built and stored in Artifact Registry
- [ ] Cloud Function deployed and connected to Eventarc
- [ ] Test run successful: ingestion → Dataflow → BigQuery
- [ ] Looker Studio dashboard created and connected
- [ ] No errors in Cloud Logging

## Post-Deployment Steps

### 1. Schedule First Full Run
```bash
export PROJECT_ID=$(gcloud config get-value project)

# Manually trigger Cloud Scheduler to test daily flow
gcloud scheduler jobs run cricket-daily-ingestion \
  --location us-central1 \
  --project ${PROJECT_ID}
```

### 2. Monitor Execution
```bash
# Watch ingestion logs
gcloud functions logs read cricket-gcs-dataflow-trigger --gen2 --tail

# Monitor Dataflow job
gcloud dataflow jobs list --region us-central1
```

### 3. Share Dashboard
- Get Looker Studio dashboard URL
- Share with stakeholders
- Set refresh schedule (recommended: 1 hour)

## Cleanup (If Needed)

To delete all resources:

```bash
cd terraform
terraform destroy
```

This removes:
- ❌ GCS buckets
- ❌ BigQuery datasets and tables
- ❌ Service accounts
- ❌ Cloud Scheduler jobs
- ❌ Cloud Functions
- ❌ Eventarc triggers
- ❌ IAM role bindings

⚠️ **Warning**: This is irreversible. Ensure data is backed up.

## Troubleshooting

### GCS Upload Doesn't Trigger Cloud Function
- Check Eventarc trigger: `gcloud eventarc triggers list --location us-central1`
- Verify file is in correct bucket and has `.csv` extension
- Check Cloud Function logs for errors

### Dataflow Job Fails
- Check job logs: `gcloud dataflow jobs show JOB_ID --region us-central1`
- Verify BigQuery dataset exists: `bq ls`
- Ensure service account has BigQuery Admin role

### BigQuery Queries Fail
- Check dataset permissions: `bq show cricket_raw`
- Verify table exists: `bq ls cricket_raw`
- Re-run SQL scripts with correct PROJECT_ID

### RapidAPI Errors
- Check API quota: https://rapidapi.com/developer/dashboard
- Verify API key in config.yaml
- Test API manually: curl with headers

## Support

For issues, check:
1. [README.md](README.md) - Architecture overview
2. Cloud Logging: `gcloud logging read`
3. Cloud Monitoring: GCP Console → Monitoring
4. GitHub Issues (if applicable)

---

**Deployment Status**: Complete ✅

Next: Monitor the pipeline and create Looker Studio dashboard
