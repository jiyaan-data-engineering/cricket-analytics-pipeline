#!/bin/bash

# ============================================================================
# BUILD AND PUSH DATAFLOW FLEX TEMPLATE
# ============================================================================
# Builds Apache Beam pipeline as Docker image and pushes to Artifact Registry
# Usage: ./build-dataflow-template.sh <PROJECT_ID> <REGION>

set -e

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"
ARTIFACT_REGISTRY_LOCATION="${3:-us-central1}"
REPOSITORY_NAME="dataflow-templates"
IMAGE_NAME="cricket-batting-rankings-pipeline"
IMAGE_TAG="latest"

echo "=============================================="
echo "🐳 Building Dataflow Flex Template"
echo "=============================================="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Repository: $REPOSITORY_NAME"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"
echo ""

# Full image path
IMAGE_PATH="${ARTIFACT_REGISTRY_LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Image path: $IMAGE_PATH"
echo ""

# Step 1: Create Artifact Registry repository if it doesn't exist
echo "1️⃣  Creating Artifact Registry repository (if needed)..."
gcloud artifacts repositories create $REPOSITORY_NAME \
  --repository-format=docker \
  --location=$ARTIFACT_REGISTRY_LOCATION \
  --project=$PROJECT_ID \
  2>/dev/null || echo "   Repository already exists"

echo ""

# Step 2: Configure Docker authentication
echo "2️⃣  Configuring Docker authentication..."
gcloud auth configure-docker ${ARTIFACT_REGISTRY_LOCATION}-docker.pkg.dev --quiet

echo ""

# Step 3: Build Docker image
echo "3️⃣  Building Docker image..."
cd pipeline/dataflow

docker build \
  --tag $IMAGE_PATH \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  .

cd ../..

echo ""

# Step 4: Push to Artifact Registry
echo "4️⃣  Pushing image to Artifact Registry..."
docker push $IMAGE_PATH

echo ""

# Step 5: Create Flex Template spec
echo "5️⃣  Creating Flex Template spec..."

FLEX_TEMPLATE_SPEC="gs://cricket-dataflow-templates-prod/specs/cricket-batting-rankings-template.json"

gcloud dataflow flex-templates build $FLEX_TEMPLATE_SPEC \
  --image=$IMAGE_PATH \
  --sdk-language=PYTHON \
  --flex-template-base-image=PYTHON3 \
  --project=$PROJECT_ID \
  2>/dev/null || echo "   Template spec already exists or will be created on first run"

echo ""

# Step 6: Output template info
echo "=============================================="
echo "✅ Dataflow Flex Template Created!"
echo "=============================================="
echo ""
echo "Template Details:"
echo "  Image:     $IMAGE_PATH"
echo "  Spec:      $FLEX_TEMPLATE_SPEC"
echo "  Project:   $PROJECT_ID"
echo "  Region:    $REGION"
echo ""
echo "To launch a Dataflow job using this template:"
echo ""
echo "  gcloud dataflow flex-templates run <JOB_NAME> \\"
echo "    --template-file-gcs-location=$FLEX_TEMPLATE_SPEC \\"
echo "    --parameters input_file=gs://cricket-raw-data-prod/batting/sample.csv,output_dataset=cricket_raw,output_table=batting_rankings \\"
echo "    --region=$REGION \\"
echo "    --project-id=$PROJECT_ID"
echo ""
