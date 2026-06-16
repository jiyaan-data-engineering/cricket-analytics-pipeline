#!/bin/bash

# ============================================================================
# CLOUD COMPOSER DEPLOYMENT SCRIPT
# ============================================================================
# Deploy Cloud Composer environment for cricket analytics pipeline

set -e

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"
ENVIRONMENT_NAME="cricket-analytics-composer"
SERVICE_ACCOUNT="cricket-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🚀 Deploying Cloud Composer Environment..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT_NAME"
echo ""

# Create Cloud Composer environment
echo "⏳ Checking if Cloud Composer environment exists..."

if gcloud composer environments describe $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID &>/dev/null; then
  echo "✅ Cloud Composer environment already exists - skipping creation"
else
  echo "⏳ Creating Cloud Composer environment (this takes 10-15 minutes)..."

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
RAW_BUCKET=cricket-raw-data-prod

  echo "✅ Cloud Composer environment created successfully!"
fi
echo ""
echo "🚀 Deploying DAGs..."

# Deploy DAGs (ignore errors if DAG files don't exist yet)
echo "Importing cricket_analytics_dag.py..."
gcloud composer environments storage dags import \
  --environment=$ENVIRONMENT_NAME \
  --location=$REGION \
  --source=pipeline/airflow/dags/cricket_analytics_dag.py 2>/dev/null || echo "⚠️  cricket_analytics_dag.py not found (optional)"

echo "Importing data_quality_monitoring_dag.py..."
gcloud composer environments storage dags import \
  --environment=$ENVIRONMENT_NAME \
  --location=$REGION \
  --source=pipeline/airflow/dags/data_quality_monitoring_dag.py 2>/dev/null || echo "⚠️  data_quality_monitoring_dag.py not found (optional)"

echo "✅ DAG deployment step completed!"
echo ""
echo "🎉 Cloud Composer setup complete!"
echo ""
echo "Access Airflow UI:"
gcloud composer environments describe $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --format="value(config.airflowUri)"
