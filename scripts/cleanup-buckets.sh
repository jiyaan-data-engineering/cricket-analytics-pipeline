#!/bin/bash
set -e

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"

echo "=================================================="
echo "GCS BUCKET CLEANUP - REMOVING UNNECESSARY BUCKETS"
echo "=================================================="
echo ""
echo "Project: $PROJECT_ID"
echo ""

# Function to delete bucket safely
delete_bucket() {
  BUCKET=$1
  echo "Deleting bucket: $BUCKET"
  
  # Empty the bucket first
  gsutil -m rm -r "gs://$BUCKET/*" 2>/dev/null || true
  
  # Delete the bucket
  gsutil rb "gs://$BUCKET" 2>/dev/null && echo "  ✅ Deleted: $BUCKET" || echo "  ⚠️ Could not delete: $BUCKET (may not exist)"
}

echo "🗑️  Removing auto-generated Cloud Build buckets..."
gsutil ls -b -p $PROJECT_ID | grep "cloudbuild" | while read -r bucket; do
  delete_bucket "${bucket#gs://}"
done

echo ""
echo "🗑️  Removing Cloud Function staging buckets..."
gsutil ls -b -p $PROJECT_ID | grep "gcf" | while read -r bucket; do
  delete_bucket "${bucket#gs://}"
done

echo ""
echo "🗑️  Removing old Terraform state backups..."
gsutil ls -b -p $PROJECT_ID | grep "tf-state\|terraform" | grep -v "cricket-prod-tf-state" | while read -r bucket; do
  delete_bucket "${bucket#gs://}"
done

echo ""
echo "=================================================="
echo "✅ CLEANUP COMPLETE"
echo "=================================================="
echo ""
echo "Remaining buckets should be:"
echo "  ✅ cricket-prod-raw-data"
echo "  ✅ cricket-prod-dataflow-templates"
echo "  ✅ cricket-prod-dataflow-temp"
echo "  ✅ cricket-prod-tf-state (if exists)"
echo "  ✅ us-central1-cricket-* (Cloud Composer auto-generated)"
echo ""
echo "Verify with: gsutil ls -b -p $PROJECT_ID | grep cricket-prod"
