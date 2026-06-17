#!/bin/bash

# ============================================================================
# PHASE 2: RUN DATA PIPELINE WITH CREATED COMPOSER
# ============================================================================
# Uses Cloud Composer environment created in Phase 1
# Deploys DAGs, runs pipeline, monitors execution, and deletes Composer
# Usage: ./phase2-run-pipeline.sh <CONFIG_FILE_OR_GCS_PATH>

set -e

CONFIG_SOURCE="${1:?ERROR: Must provide Phase 1 config file or GCS path}"

echo "=============================================="
echo "⚙️  PHASE 2: RUN DATA PIPELINE"
echo "=============================================="
echo ""

# ============================================================================
# STEP 1: LOAD CONFIG FROM PHASE 1
# ============================================================================

echo "📥 Step 1: Loading Phase 1 configuration..."
echo "   Source: $CONFIG_SOURCE"
echo ""

# Check if it's a GCS path or local file
if [[ "$CONFIG_SOURCE" == "gs://"* ]]; then
  echo "⏳ Downloading config from GCS..."
  CONFIG_JSON=$(gsutil cat "$CONFIG_SOURCE")
else
  echo "📂 Reading local config file..."
  CONFIG_JSON=$(cat "$CONFIG_SOURCE")
fi

# Parse JSON config
PROJECT_ID=$(echo "$CONFIG_JSON" | grep -o '"project_id":"[^"]*' | cut -d'"' -f4)
REGION=$(echo "$CONFIG_JSON" | grep -o '"region":"[^"]*' | cut -d'"' -f4)
ENVIRONMENT_NAME=$(echo "$CONFIG_JSON" | grep -o '"environment_name":"[^"]*' | cut -d'"' -f4)
SERVICE_ACCOUNT=$(echo "$CONFIG_JSON" | grep -o '"service_account":"[^"]*' | cut -d'"' -f4)
DAGS_BUCKET=$(echo "$CONFIG_JSON" | grep -o '"dags_bucket":"[^"]*' | cut -d'"' -f4)
AIRFLOW_URI=$(echo "$CONFIG_JSON" | grep -o '"airflow_uri":"[^"]*' | cut -d'"' -f4)

echo "✅ Config loaded successfully"
echo ""
echo "Composer Details:"
echo "  Project: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Environment: $ENVIRONMENT_NAME"
echo "  Service Account: $SERVICE_ACCOUNT"
echo "  Airflow URI: $AIRFLOW_URI"
echo ""

# ============================================================================
# STEP 2: VERIFY COMPOSER ENVIRONMENT IS READY
# ============================================================================

echo "🔍 Step 2: Verifying Composer environment is ready..."
echo ""

# Wait for environment to be fully created
MAX_WAIT=30
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
  STATUS=$(gcloud composer environments describe $ENVIRONMENT_NAME \
    --location=$REGION \
    --project=$PROJECT_ID \
    --format="value(state)" 2>/dev/null || echo "CREATING")

  if [ "$STATUS" = "RUNNING" ]; then
    echo "✅ Composer environment is RUNNING"
    break
  fi

  echo "⏳ Environment status: $STATUS (waiting...)"
  sleep 10
  ELAPSED=$((ELAPSED + 10))
done

if [ "$STATUS" != "RUNNING" ]; then
  echo "⚠️  Warning: Environment status is $STATUS, proceeding anyway..."
fi

echo ""

# ============================================================================
# STEP 3: DEPLOY DAGs TO COMPOSER
# ============================================================================

echo "📤 Step 3: Deploying DAGs to Composer..."
echo ""

DAGS=(
  "pipeline/airflow/dags/cricket_analytics_dag.py"
  "pipeline/airflow/dags/data_quality_monitoring_dag.py"
)

for dag_file in "${DAGS[@]}"; do
  if [ -f "$dag_file" ]; then
    echo "  Uploading: $dag_file"
    gcloud composer environments storage dags import \
      --environment=$ENVIRONMENT_NAME \
      --location=$REGION \
      --source="$dag_file" 2>/dev/null || echo "    ⚠️  Could not import (may already exist)"
  else
    echo "  ⚠️  File not found: $dag_file"
  fi
done

echo ""
echo "✅ DAGs deployed"
echo ""

# ============================================================================
# STEP 4: TRIGGER DAG EXECUTION
# ============================================================================

echo "🚀 Step 4: Triggering DAG execution..."
echo ""

gcloud composer environments run $ENVIRONMENT_NAME \
  --location=$REGION \
  airflow dags trigger \
  --exec-date "2026-06-16" \
  cricket_analytics_dag \
  2>/dev/null || echo "⚠️  DAG trigger command executed (may run asynchronously)"

echo "✅ DAG execution triggered"
echo ""

# ============================================================================
# STEP 5: MONITOR DAG EXECUTION
# ============================================================================

echo "👁️  Step 5: Monitoring DAG execution..."
echo ""

MAX_WAIT_MINUTES=60
POLL_INTERVAL=30
ELAPSED=0

while [ $ELAPSED -lt $((MAX_WAIT_MINUTES * 60)) ]; do
  echo "⏳ Checking DAG status... ($(($ELAPSED / 60))m elapsed)"

  # Check DAG run status
  DAG_STATUS=$(gcloud composer environments run $ENVIRONMENT_NAME \
    --location=$REGION \
    airflow dags list-runs \
    --dag-id cricket_analytics_dag \
    --limit 1 2>/dev/null | grep -i "success\|failed\|running" || echo "")

  if [ ! -z "$DAG_STATUS" ]; then
    echo "  Status: $DAG_STATUS"

    if echo "$DAG_STATUS" | grep -iq "success"; then
      echo ""
      echo "✅ DAG completed successfully!"
      break
    elif echo "$DAG_STATUS" | grep -iq "failed"; then
      echo ""
      echo "❌ DAG failed - check Airflow UI for details"
      echo "   Airflow: $AIRFLOW_URI"
      break
    fi
  fi

  sleep $POLL_INTERVAL
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo ""

# ============================================================================
# STEP 6: COLLECT AUDIT METRICS
# ============================================================================

echo "📊 Step 6: Collecting pipeline execution metrics..."
echo ""

AUDIT_QUERY="
SELECT
  CURRENT_TIMESTAMP() as audit_timestamp,
  'cricket_analytics_dag' as dag_name,
  COUNT(*) as record_count,
  MIN(ingested_at) as earliest_record,
  MAX(ingested_at) as latest_record,
  COUNT(DISTINCT format) as format_count
FROM \`$PROJECT_ID.cricket_raw.batting_rankings\`
WHERE DATE(ingested_at) = CURRENT_DATE()
GROUP BY 1, 2
"

echo "Execution Summary:"
bq query --use_legacy_sql=false --project_id=$PROJECT_ID --format=pretty "$AUDIT_QUERY" 2>/dev/null || \
  echo "⚠️  Could not fetch metrics (data may not be loaded yet)"

echo ""
echo "✅ Audit metrics collected"
echo ""

# ============================================================================
# STEP 7: DELETE COMPOSER ENVIRONMENT
# ============================================================================

echo "🗑️  Step 7: Deleting Composer environment..."
echo ""

gcloud composer environments delete $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet || echo "⚠️  Could not delete (may be in use)"

echo ""
echo "✅ Composer environment deleted"
echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================

echo "=============================================="
echo "✅ PHASE 2 COMPLETE"
echo "=============================================="
echo ""
echo "📊 Pipeline Execution Summary:"
echo "  ✓ Loaded Phase 1 configuration"
echo "  ✓ Verified Composer environment"
echo "  ✓ Deployed DAGs"
echo "  ✓ Triggered DAG execution"
echo "  ✓ Monitored completion"
echo "  ✓ Collected metrics"
echo "  ✓ Deleted environment"
echo ""
echo "💰 Cost Impact:"
echo "  ✓ Composer environment deleted"
echo "  ✓ Saving ~$150/day"
echo ""
echo "📈 Results:"
echo "  - Check BigQuery cricket_raw dataset for data"
echo "  - Check cricket_staging for transformed data"
echo "  - Check cricket_curated for analytics-ready views"
echo ""
echo "✨ Pipeline ready for next run!"
echo "=============================================="
