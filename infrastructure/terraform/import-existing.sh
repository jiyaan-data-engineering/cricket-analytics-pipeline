#!/bin/bash
# ============================================================================
# import-existing.sh
# Import existing resources into Terraform state (idempotent deployment)
# ============================================================================

set -e

PROJECT_ID="${1:-}"
if [ -z "$PROJECT_ID" ]; then
  echo "Usage: ./import-existing.sh <GCP_PROJECT_ID>"
  exit 1
fi

echo "📍 Importing existing resources into Terraform state..."
echo "   Project: $PROJECT_ID"
echo ""

# Function to safely import a resource
import_resource() {
  local resource_type=$1
  local resource_name=$2
  local import_id=$3

  echo "  Attempting to import $resource_type.$resource_name..."

  if terraform import -no-color "$resource_type.$resource_name" "$import_id" 2>/dev/null; then
    echo "    ✅ Imported successfully"
  else
    # It's okay if import fails (resource might not exist or already in state)
    echo "    ⚠️  Already in state or doesn't exist (skipping)"
  fi
}

echo "📦 Importing BigQuery Datasets..."
import_resource "google_bigquery_dataset.raw" "cricket_raw" "cricket_raw"
import_resource "google_bigquery_dataset.staging" "cricket_staging" "cricket_staging"
import_resource "google_bigquery_dataset.curated" "cricket_curated" "cricket_curated"

echo ""
echo "📦 Importing GCS Buckets..."
import_resource "google_storage_bucket.raw_data" "cricket-analytics-raw-data" "cricket-analytics-raw-data"
import_resource "google_storage_bucket.dataflow_templates" "cricket-analytics-dataflow-templates" "cricket-analytics-dataflow-templates"
import_resource "google_storage_bucket.dataflow_temp" "cricket-analytics-dataflow-temp" "cricket-analytics-dataflow-temp"
import_resource "google_storage_bucket.composer_dags" "cricket-analytics-composer-dags" "cricket-analytics-composer-dags"

echo ""
echo "📦 Importing Service Accounts..."
import_resource "google_service_account.dataflow_sa" "cricket-dataflow-sa@$PROJECT_ID.iam.gserviceaccount.com" "cricket-dataflow-sa"
import_resource "google_service_account.cloud_function_sa" "cricket-cloud-function-sa@$PROJECT_ID.iam.gserviceaccount.com" "cricket-cloud-function-sa"
import_resource "google_service_account.composer_sa" "cricket-composer-sa@$PROJECT_ID.iam.gserviceaccount.com" "cricket-composer-sa"

echo ""
echo "📦 Importing KMS Resources..."
import_resource "google_kms_key_ring.composer" "projects/$PROJECT_ID/locations/us-central1/keyRings/cricket-composer-keyring" "projects/$PROJECT_ID/locations/us-central1/keyRings/cricket-composer-keyring"

echo ""
echo "✅ Import complete! Existing resources are now tracked by Terraform"
