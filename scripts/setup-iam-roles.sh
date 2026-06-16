#!/bin/bash
set -e

PROJECT_ID=$1
if [ -z "$PROJECT_ID" ]; then
  echo "Usage: setup-iam-roles.sh <PROJECT_ID>"
  exit 1
fi

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
FUNCTION_SA="cricket-cloud-function-sa@$PROJECT_ID.iam.gserviceaccount.com"

echo "=================================================="
echo "⚠️  GCP ORG ADMIN REQUIRED"
echo "=================================================="
echo ""
echo "This script grants IAM roles needed for Cloud Function automation."
echo "You must have org-level permissions to run these commands."
echo ""
echo "Project: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo ""
echo "=================================================="
echo ""

echo "1️⃣  Granting roles/storage.objectViewer to Compute SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$COMPUTE_SA" \
  --role="roles/storage.objectViewer"

echo ""
echo "2️⃣  Granting roles/storage.admin to Cloud Function SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$FUNCTION_SA" \
  --role="roles/storage.admin"

echo ""
echo "3️⃣  Granting roles/dataflow.admin to Cloud Function SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$FUNCTION_SA" \
  --role="roles/dataflow.admin"

echo ""
echo "4️⃣  Granting roles/iam.serviceAccountUser to Cloud Function SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$FUNCTION_SA" \
  --role="roles/iam.serviceAccountUser"

echo ""
echo "5️⃣  Granting roles/eventarc.eventReceiver to Cloud Function SA..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$FUNCTION_SA" \
  --role="roles/eventarc.eventReceiver"

echo ""
echo "=================================================="
echo "✅ IAM roles configured successfully!"
echo "=================================================="
echo ""
echo "Cloud Function is now ready for FULL automation."
echo "All future deployments will include automatic Cloud Function setup."
echo ""
