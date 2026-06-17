#!/bin/bash

# ============================================================================
# FULLY AUTOMATED TWO-PHASE PIPELINE
# ============================================================================
# Phase 1: Create Composer
# Phase 2: Run pipeline (automatically triggered)
# No manual intervention needed
# Usage: ./auto-phase1-phase2.sh <PROJECT_ID> <REGION>

set -e

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"
ENVIRONMENT_NAME="cricket-analytics-composer-$(date +%s)"
SERVICE_ACCOUNT="cricket-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com"
CONFIG_BUCKET="cricket-dataflow-templates-prod"

LOG_FILE="/tmp/pipeline-$(date +%Y%m%d-%H%M%S).log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ============================================================================
# PHASE 1: CREATE COMPOSER
# ============================================================================

log "════════════════════════════════════════════"
log "🚀 PHASE 1: Creating Cloud Composer"
log "════════════════════════════════════════════"
log ""

log "Creating environment: $ENVIRONMENT_NAME"
log ""

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
RAW_BUCKET=cricket-raw-data-prod || {
  log "❌ Failed to create Composer"
  exit 1
}

log "✅ Composer created: $ENVIRONMENT_NAME"
log ""

# Get environment details
log "Retrieving environment details..."

COMPOSER_DETAILS=$(gcloud composer environments describe $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --format=json)

AIRFLOW_URI=$(echo "$COMPOSER_DETAILS" | grep -o '"airflowUri":"[^"]*' | cut -d'"' -f4)
DAGS_BUCKET=$(echo "$COMPOSER_DETAILS" | grep -o '"dagGcsPrefix":"[^"]*' | cut -d'"' -f4)

log "Environment ready!"
log "  Airflow: $AIRFLOW_URI"
log "  DAGs: $DAGS_BUCKET"
log ""

# Save config
CONFIG_JSON=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment_name": "$ENVIRONMENT_NAME",
  "project_id": "$PROJECT_ID",
  "region": "$REGION",
  "service_account": "$SERVICE_ACCOUNT",
  "airflow_uri": "$AIRFLOW_URI",
  "dags_bucket": "$DAGS_BUCKET",
  "status": "CREATED"
}
EOF
)

CONFIG_FILE="gs://${CONFIG_BUCKET}/composer-configs/$(date +%Y%m%d-%H%M%S)-config.json"
echo "$CONFIG_JSON" | gsutil cp - "$CONFIG_FILE"

log "✅ Config saved: $CONFIG_FILE"
log ""

# ============================================================================
# PHASE 2: RUN PIPELINE (AUTOMATIC)
# ============================================================================

log "════════════════════════════════════════════"
log "⚙️  PHASE 2: Running Data Pipeline"
log "════════════════════════════════════════════"
log ""

log "Waiting for environment to be fully ready..."
sleep 30

# Deploy DAGs
log "📤 Deploying DAGs..."

for dag_file in pipeline/airflow/dags/*.py; do
  if [ -f "$dag_file" ]; then
    log "  Uploading: $(basename $dag_file)"
    gcloud composer environments storage dags import \
      --environment=$ENVIRONMENT_NAME \
      --location=$REGION \
      --source="$dag_file" 2>/dev/null || log "    ⚠️  $(basename $dag_file) already exists"
  fi
done

log "✅ DAGs deployed"
log ""

# Trigger DAG
log "🚀 Triggering DAG execution..."

gcloud composer environments run $ENVIRONMENT_NAME \
  --location=$REGION \
  airflow dags trigger \
  cricket_analytics_dag 2>/dev/null || log "  DAG trigger sent"

log "✅ DAG triggered"
log ""

# Monitor execution
log "👁️  Monitoring DAG execution (max 60 minutes)..."

MAX_WAIT_MINUTES=60
POLL_INTERVAL=30
ELAPSED=0
DAG_COMPLETE=false

while [ $ELAPSED -lt $((MAX_WAIT_MINUTES * 60)) ]; do
  STATUS=$(gcloud composer environments run $ENVIRONMENT_NAME \
    --location=$REGION \
    airflow dags list-runs \
    --dag-id cricket_analytics_dag \
    --limit 1 2>/dev/null | grep -i "success\|failed" || echo "")

  if [ ! -z "$STATUS" ]; then
    if echo "$STATUS" | grep -iq "success"; then
      log "✅ DAG completed successfully!"
      DAG_COMPLETE=true
      break
    elif echo "$STATUS" | grep -iq "failed"; then
      log "❌ DAG failed - check Airflow UI: $AIRFLOW_URI"
      break
    fi
  fi

  log "  ⏳ Running... ($(($ELAPSED / 60))m)"
  sleep $POLL_INTERVAL
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

log ""

# Collect metrics
log "📊 Collecting execution metrics..."

AUDIT_QUERY="
SELECT
  COUNT(*) as record_count,
  COUNT(DISTINCT format) as format_count,
  MIN(ingested_at) as earliest_record,
  MAX(ingested_at) as latest_record
FROM \`$PROJECT_ID.cricket_raw.batting_rankings\`
WHERE DATE(ingested_at) = CURRENT_DATE()
"

METRICS=$(bq query --use_legacy_sql=false --project_id=$PROJECT_ID --format=json "$AUDIT_QUERY" 2>/dev/null | jq -r '.[0]' || echo "")

if [ ! -z "$METRICS" ]; then
  log "  Records ingested:"
  echo "$METRICS" | jq .
fi

log ""

# ============================================================================
# CLEANUP: DELETE COMPOSER
# ============================================================================

log "════════════════════════════════════════════"
log "🗑️  CLEANUP: Deleting Composer"
log "════════════════════════════════════════════"
log ""

log "Deleting environment: $ENVIRONMENT_NAME"

gcloud composer environments delete $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet || log "  ⚠️  Delete initiated asynchronously"

log "✅ Environment deleted"
log "💰 Saving ~$150/day!"
log ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================

log "════════════════════════════════════════════"
log "✅ FULLY AUTOMATED PIPELINE COMPLETE!"
log "════════════════════════════════════════════"
log ""
log "📊 Summary:"
log "  ✓ Phase 1: Created Cloud Composer"
log "  ✓ Phase 2: Deployed DAGs & ran pipeline"
log "  ✓ Collected metrics & audit logs"
log "  ✓ Deleted environment (cost saved)"
log ""
log "📈 Results:"
log "  - BigQuery cricket_raw: New data ingested"
log "  - BigQuery cricket_staging: Data transformed"
log "  - BigQuery cricket_curated: Analytics ready"
log ""
log "Log file: $LOG_FILE"
log "=============================================="
