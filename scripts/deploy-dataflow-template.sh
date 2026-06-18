#!/bin/bash
set -e

# Deploy Dataflow Flex Template
# This script builds and registers the Dataflow template to GCS

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"
ARTIFACT_REPO="cricket-dataflow"
IMAGE_NAME="batting-pipeline"
TEMPLATE_LOCATION="gs://${PROJECT_ID}-dataflow-templates-prod/batting-pipeline"

echo "=================================================="
echo "DEPLOYING DATAFLOW FLEX TEMPLATE"
echo "=================================================="
echo ""
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Template: $TEMPLATE_LOCATION"
echo ""

# Step 1: Check if Artifact Registry exists
echo "[1/5] Checking Artifact Registry..."
if ! gcloud artifacts repositories describe $ARTIFACT_REPO --location=$REGION --project=$PROJECT_ID 2>/dev/null; then
    echo "Creating Artifact Registry repository..."
    gcloud artifacts repositories create $ARTIFACT_REPO \
        --repository-format=docker \
        --location=$REGION \
        --project=$PROJECT_ID
fi
echo "✅ Artifact Registry ready"

# Step 2: Build Docker image using Cloud Build
echo ""
echo "[2/5] Building Docker image with Cloud Build..."
cd pipeline/dataflow
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REPO}/${IMAGE_NAME}"

gcloud builds submit . \
    --project=$PROJECT_ID \
    --substitutions="_REGION=${REGION},_IMAGE_NAME=${IMAGE_NAME}" \
    --config=- << 'CLOUDBUILD'
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_ARTIFACT_REPO}/${_IMAGE_NAME}:latest', '.']
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_ARTIFACT_REPO}/${_IMAGE_NAME}:latest']
images:
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_ARTIFACT_REPO}/${_IMAGE_NAME}:latest'
substitutions:
  _REGION: 'us-central1'
  _ARTIFACT_REPO: 'cricket-dataflow'
  _IMAGE_NAME: 'batting-pipeline'
timeout: 1800s
CLOUDBUILD

echo "✅ Docker image built and pushed"

# Step 3: Create template metadata
echo ""
echo "[3/5] Creating template metadata..."
cat > /tmp/metadata.json << EOF
{
  "image": "${IMAGE_URI}:latest",
  "sdkLanguage": "PYTHON",
  "name": "Cricket Batting Pipeline",
  "description": "Reads batting rankings CSV from GCS and writes to BigQuery",
  "parameters": [
    {
      "name": "inputFile",
      "label": "Input CSV file path",
      "helpText": "GCS path to input CSV (e.g., gs://bucket/batting/*.csv)",
      "regexes": ["^gs://.*"],
      "isOptional": false
    },
    {
      "name": "outputTable",
      "label": "Output BigQuery table",
      "helpText": "BigQuery table (e.g., project:dataset.table)",
      "regexes": ["^[a-zA-Z0-9_:.*]+\$"],
      "isOptional": false
    },
    {
      "name": "tempLocation",
      "label": "Temporary GCS location",
      "helpText": "GCS path for temporary files",
      "regexes": ["^gs://.*"],
      "isOptional": false
    }
  ]
}
EOF

# Step 4: Upload template to GCS
echo ""
echo "[4/5] Uploading template to GCS..."
gsutil -m cp /tmp/metadata.json ${TEMPLATE_LOCATION}/metadata

echo "✅ Template uploaded"

# Step 5: Verify template
echo ""
echo "[5/5] Verifying template..."
gsutil ls -l ${TEMPLATE_LOCATION}/

echo ""
echo "=================================================="
echo "✅ DATAFLOW FLEX TEMPLATE DEPLOYED"
echo "=================================================="
echo ""
echo "Template ready at: ${TEMPLATE_LOCATION}"
echo "Image URI: ${IMAGE_URI}:latest"
echo ""
echo "Update DAG to use:"
echo "  gcloud dataflow flex-template run cricket-batting-\${RANDOM} \\"
echo "    --template-file-gcs-location=${TEMPLATE_LOCATION} \\"
echo "    --region=${REGION} \\"
echo "    --project-id=${PROJECT_ID} \\"
echo "    --parameters inputFile=...,outputTable=...,tempLocation=..."
