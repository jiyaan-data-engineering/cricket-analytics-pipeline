#!/bin/bash
# Quick deployment script for Cricket Analytics Pipeline
# Usage: ./deploy.sh <GCP_PROJECT_ID> <RAPIDAPI_KEY>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate inputs
if [ $# -lt 2 ]; then
    echo "Usage: $0 <GCP_PROJECT_ID> <RAPIDAPI_KEY>"
    echo "Example: $0 my-gcp-project abc123xyz789"
    exit 1
fi

PROJECT_ID=$1
RAPIDAPI_KEY=$2
REGION="us-central1"
ZONE="us-central1-a"

echo -e "${GREEN}=== Cricket Analytics Pipeline Deployment ===${NC}"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"

# Step 1: Authenticate with GCP
echo -e "\n${YELLOW}Step 1: Setting up GCP authentication...${NC}"
gcloud config set project $PROJECT_ID
gcloud auth application-default login

# Step 2: Enable required APIs
echo -e "\n${YELLOW}Step 2: Enabling required GCP APIs...${NC}"
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
    compute.googleapis.com

# Step 3: Create Terraform tfvars
echo -e "\n${YELLOW}Step 3: Creating Terraform configuration...${NC}"
cat > terraform/terraform.tfvars << EOF
gcp_project_id       = "$PROJECT_ID"
gcp_region          = "$REGION"
gcp_zone            = "$ZONE"
environment         = "dev"
bucket_prefix       = "cricket-analytics"
dataflow_machine_type = "n1-standard-2"
dataflow_num_workers = 2
dataflow_max_workers = 5
rapidapi_key        = "$RAPIDAPI_KEY"
EOF
echo -e "${GREEN}✓ terraform.tfvars created${NC}"

# Step 4: Update config.yaml
echo -e "\n${YELLOW}Step 4: Updating configuration...${NC}"
sed -i "s/cricket-analytics-project/$PROJECT_ID/g" config/config.yaml
echo -e "${GREEN}✓ config.yaml updated${NC}"

# Step 5: Deploy infrastructure with Terraform
echo -e "\n${YELLOW}Step 5: Deploying infrastructure with Terraform...${NC}"
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
ARTIFACT_REGISTRY=$(terraform output -raw artifact_registry_repository_url)
cd ..
echo -e "${GREEN}✓ Infrastructure deployed${NC}"

# Step 6: Build and push Dataflow Docker image
echo -e "\n${YELLOW}Step 6: Building and pushing Dataflow Flex Template...${NC}"
gcloud auth configure-docker ${REGION}-docker.pkg.dev

REGISTRY="${REGION}-docker.pkg.dev"
REPOSITORY="cricket-dataflow-templates"
IMAGE_NAME="batting-pipeline"
IMAGE_URI="${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest"

cd dataflow
docker build -t $IMAGE_URI .
docker push $IMAGE_URI
cd ..

# Build Flex Template
gcloud dataflow flex-template build \
    gs://cricket-analytics-dataflow-templates-${PROJECT_ID}/batting-pipeline \
    --image=$IMAGE_URI \
    --sdk-language=PYTHON
echo -e "${GREEN}✓ Dataflow Flex Template deployed${NC}"

# Step 7: Create BigQuery tables and views
echo -e "\n${YELLOW}Step 7: Creating BigQuery tables and views...${NC}"

run_sql() {
    local file=$1
    sed "s/{PROJECT_ID}/${PROJECT_ID}/g" "$file" | bq query --use_legacy_sql=false --project_id=${PROJECT_ID} --nouse_cache
}

cd bigquery/sql
for sql_file in 01_create_raw_table.sql 02_create_dim_player.sql 03_create_dim_country.sql 04_create_dim_format.sql 05_create_dim_date.sql 06_create_fact_batting.sql 07_create_curated_views.sql; do
    echo "Running $sql_file..."
    run_sql $sql_file
done
cd ../..
echo -e "${GREEN}✓ BigQuery tables and views created${NC}"

# Step 8: Test ingestion
echo -e "\n${YELLOW}Step 8: Testing ingestion script...${NC}"
export RAPIDAPI_KEY=$RAPIDAPI_KEY
export GCP_PROJECT=$PROJECT_ID
pip install -r ingestion/requirements.txt > /dev/null 2>&1
python ingestion/fetch_batting_rankings.py
echo -e "${GREEN}✓ Ingestion test complete${NC}"

# Step 9: Verify data in BigQuery
echo -e "\n${YELLOW}Step 9: Verifying BigQuery data...${NC}"
sleep 5
bq query --use_legacy_sql=false --project_id=${PROJECT_ID} \
    "SELECT COUNT(*) as total_records, FORMAT FROM \`${PROJECT_ID}.cricket_raw.batting_rankings\` GROUP BY FORMAT"

echo -e "\n${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Verify data in BigQuery:"
echo "   bq ls ${PROJECT_ID}:cricket_raw"
echo "   bq query --use_legacy_sql=false \"SELECT * FROM \\\`${PROJECT_ID}.cricket_curated.vw_current_rankings\\\` LIMIT 10\""
echo ""
echo "2. Create Looker Studio dashboard:"
echo "   - Go to https://lookerstudio.google.com/"
echo "   - Add BigQuery data source"
echo "   - Select cricket_curated dataset"
echo "   - Create visualizations"
echo ""
echo "3. Monitor Cloud Scheduler job:"
echo "   gcloud scheduler jobs describe cricket-daily-ingestion --location ${REGION}"
echo ""
echo "4. View logs:"
echo "   gcloud functions logs read cricket-gcs-dataflow-trigger --gen2 --region ${REGION}"
echo ""
echo "For detailed documentation, see README.md and DEPLOYMENT.md"
