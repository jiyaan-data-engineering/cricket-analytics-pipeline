#!/bin/bash

# ============================================================================
# CLOUD COMPOSER DEPLOYMENT SCRIPT
# ============================================================================
# Deploy Cloud Composer environment for cricket analytics pipeline

set -e

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"
ENVIRONMENT_NAME="cricket-analytics-composer"

echo "🚀 Deploying Cloud Composer Environment..."
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT_NAME"
echo ""

# Create Cloud Composer environment
echo "⏳ Creating Cloud Composer environment (this takes 10-15 minutes)..."

gcloud composer environments create $ENVIRONMENT_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --env-variables=\
GCP_PROJECT_ID=$PROJECT_ID,\
GCP_REGION=$REGION,\
BQ_RAW_DATASET=cricket_raw,\
BQ_STAGING_DATASET=cricket_staging,\
BQ_CURATED_DATASET=cricket_curated,\
DATAFLOW_TEMPLATE_BUCKET=cricket-dataflow-templates-prod,\
RAW_BUCKET=cricket-raw-data-prod

echo "✅ Cloud Composer environment created successfully!"
echo ""
echo "🚀 Deploying DAGs..."

# Get the DAGs bucket
DAGS_BUCKET=$(gcloud composer environments describe $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --format="value(config.dagGcsPrefix)" | sed 's|gs://||g' | sed 's|/dags||g')

echo "DAGs Bucket: $DAGS_BUCKET"

# Deploy DAGs
gcloud composer environments storage dags import \
  --environment=$ENVIRONMENT_NAME \
  --location=$REGION \
  --source=pipeline/airflow/dags/cricket_analytics_dag.py

gcloud composer environments storage dags import \
  --environment=$ENVIRONMENT_NAME \
  --location=$REGION \
  --source=pipeline/airflow/dags/data_quality_monitoring_dag.py

echo "✅ DAGs deployed successfully!"
echo ""
echo "🎉 Cloud Composer setup complete!"
echo ""
echo "Access Airflow UI:"
gcloud composer environments describe $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --format="value(config.airflowUri)"
