#!/bin/bash

# ============================================================================
# PHASE 1: CREATE CLOUD COMPOSER ENVIRONMENT
# ============================================================================
# Only creates the environment and saves details for Phase 2
# Output: Composer config JSON saved to GCS
# Usage: ./phase1-create-composer.sh <PROJECT_ID> <REGION>

set -e

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"
ENVIRONMENT_NAME="cricket-analytics-composer-$(date +%s)"
SERVICE_ACCOUNT="cricket-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com"
CONFIG_BUCKET="cricket-dataflow-templates-prod"
CONFIG_FILE="gs://${CONFIG_BUCKET}/composer-configs/$(date +%Y%m%d-%H%M%S)-config.json"

echo "=============================================="
echo "🚀 PHASE 1: CREATE CLOUD COMPOSER"
echo "=============================================="
echo ""
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT_NAME"
echo "Service Account: $SERVICE_ACCOUNT"
echo ""

# ============================================================================
# STEP 1: CREATE ENVIRONMENT
# ============================================================================

echo "⏳ Step 1: Creating Cloud Composer environment..."
echo "   (Takes 10-15 minutes, this is normal)"
echo ""

gcloud composer environments create $ENVIRONMENT_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --service-account=$SERVICE_ACCOUNT \
  --env-variables=\
GCP_PROJECT_ID=$PROJECT_ID,\
GCP_REGION=$REGION,\
BQ_RAW_DATASET=cricket_raw,\
BQ_STAGING_DATASET=cricket_staging,\
BQ_CURATED_DATASET=cricket_curated,\
DATAFLOW_TEMPLATE_BUCKET=cricket-dataflow-templates-prod,\
RAW_BUCKET=cricket-raw-data-prod \
|| { echo "❌ Failed to create Cloud Composer"; exit 1; }

echo "✅ Cloud Composer created: $ENVIRONMENT_NAME"
echo ""

# ============================================================================
# STEP 2: GET COMPOSER DETAILS
# ============================================================================

echo "📋 Step 2: Retrieving Composer environment details..."
echo ""

COMPOSER_DETAILS=$(gcloud composer environments describe $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --format=json)

AIRFLOW_URI=$(echo "$COMPOSER_DETAILS" | grep -o '"airflowUri":"[^"]*' | cut -d'"' -f4)
DAGS_BUCKET=$(echo "$COMPOSER_DETAILS" | grep -o '"dagGcsPrefix":"[^"]*' | cut -d'"' -f4)

echo "Airflow URI: $AIRFLOW_URI"
echo "DAGs Bucket: $DAGS_BUCKET"
echo ""

# ============================================================================
# STEP 3: SAVE CONFIG TO GCS
# ============================================================================

echo "💾 Step 3: Saving Composer config to GCS..."
echo "   Config path: $CONFIG_FILE"
echo ""

CONFIG_JSON=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project_id": "$PROJECT_ID",
  "region": "$REGION",
  "environment_name": "$ENVIRONMENT_NAME",
  "service_account": "$SERVICE_ACCOUNT",
  "airflow_uri": "$AIRFLOW_URI",
  "dags_bucket": "$DAGS_BUCKET",
  "status": "CREATED"
}
EOF
)

echo "$CONFIG_JSON" | gsutil cp - "$CONFIG_FILE"

if [ $? -eq 0 ]; then
  echo "✅ Config saved to: $CONFIG_FILE"
else
  echo "⚠️  Warning: Could not save config, but environment created"
fi

echo ""

# ============================================================================
# OUTPUT FOR PHASE 2
# ============================================================================

echo "=============================================="
echo "✅ PHASE 1 COMPLETE"
echo "=============================================="
echo ""
echo "📊 Output for Phase 2:"
echo ""
echo "export COMPOSER_PROJECT_ID=$PROJECT_ID"
echo "export COMPOSER_REGION=$REGION"
echo "export COMPOSER_ENV_NAME=$ENVIRONMENT_NAME"
echo "export COMPOSER_SERVICE_ACCOUNT=$SERVICE_ACCOUNT"
echo "export COMPOSER_CONFIG_FILE=$CONFIG_FILE"
echo ""
echo "Or use the config file directly:"
echo "  gsutil cp $CONFIG_FILE ./composer-config.json"
echo ""
echo "Next: Run Phase 2 to deploy DAGs and execute pipeline"
echo "=============================================="
echo ""

# Save to a local file for easy reference
echo "$CONFIG_JSON" > "/tmp/composer-phase1-${ENVIRONMENT_NAME}.json"
echo "Local backup saved to: /tmp/composer-phase1-${ENVIRONMENT_NAME}.json"
