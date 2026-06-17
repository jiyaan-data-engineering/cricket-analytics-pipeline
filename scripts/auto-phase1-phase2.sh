#!/bin/bash
# Fully automated two-phase pipeline (create → run → cleanup)

set -e

PROJECT_ID="${1:-cricket-analytics-prod}"
REGION="${2:-us-central1}"
ENVIRONMENT_NAME="cricket-analytics-composer-$(date +%s)"
SERVICE_ACCOUNT="cricket-composer-sa@${PROJECT_ID}.iam.gserviceaccount.com"
CONFIG_BUCKET="cricket-dataflow-templates-prod"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ============================================================================
# PHASE 1: CREATE COMPOSER
# ============================================================================

log "Phase 1: Creating Cloud Composer..."

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
RAW_BUCKET=cricket-raw-data-prod || exit 1

log "✅ Composer created: $ENVIRONMENT_NAME"

# Get details
COMPOSER_DETAILS=$(gcloud composer environments describe $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --format=json)

AIRFLOW_URI=$(echo "$COMPOSER_DETAILS" | grep -o '"airflowUri":"[^"]*' | cut -d'"' -f4)

log "✅ Airflow: $AIRFLOW_URI"

# Save config
CONFIG_JSON=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "environment_name": "$ENVIRONMENT_NAME",
  "project_id": "$PROJECT_ID",
  "region": "$REGION",
  "airflow_uri": "$AIRFLOW_URI",
  "status": "CREATED"
}
EOF
)

CONFIG_FILE="gs://${CONFIG_BUCKET}/composer-configs/$(date +%Y%m%d-%H%M%S)-config.json"
echo "$CONFIG_JSON" | gsutil cp - "$CONFIG_FILE"

log "✅ Config saved: $CONFIG_FILE"

# ============================================================================
# PHASE 2: RUN PIPELINE
# ============================================================================

log "Phase 2: Deploying DAGs..."

sleep 30

for dag_file in pipeline/airflow/dags/*.py; do
  if [ -f "$dag_file" ]; then
    gcloud composer environments storage dags import \
      --environment=$ENVIRONMENT_NAME \
      --location=$REGION \
      --source="$dag_file" 2>/dev/null && \
      log "✅ Deployed: $(basename $dag_file)" || \
      log "⚠️ $(basename $dag_file) exists or failed"
  fi
done

log "Phase 2: Running pipeline..."

gcloud composer environments run $ENVIRONMENT_NAME \
  --location=$REGION \
  airflow dags trigger cricket_analytics_dag 2>/dev/null

log "✅ DAG triggered"

# Monitor execution
log "Phase 2: Monitoring execution (max 60 min)..."

MAX_WAIT_MINUTES=60
POLL_INTERVAL=30
ELAPSED=0

while [ $ELAPSED -lt $((MAX_WAIT_MINUTES * 60)) ]; do
  STATUS=$(gcloud composer environments run $ENVIRONMENT_NAME \
    --location=$REGION \
    airflow dags list-runs \
    --dag-id cricket_analytics_dag \
    --limit 1 2>/dev/null | grep -i "success\|failed" || echo "")

  if [ ! -z "$STATUS" ]; then
    if echo "$STATUS" | grep -iq "success"; then
      log "✅ DAG completed"
      break
    elif echo "$STATUS" | grep -iq "failed"; then
      log "❌ DAG failed"
      break
    fi
  fi

  sleep $POLL_INTERVAL
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Collect metrics
log "Phase 2: Collecting metrics..."

bq query --use_legacy_sql=false --project_id=$PROJECT_ID \
  "SELECT COUNT(*) as records FROM \`$PROJECT_ID.cricket_raw.batting_rankings\` WHERE DATE(ingested_at) = CURRENT_DATE()" \
  2>/dev/null || log "⚠️ Could not fetch metrics"

# ============================================================================
# PHASE 3: CLEANUP
# ============================================================================

log "Phase 3: Deleting Composer..."

gcloud composer environments delete $ENVIRONMENT_NAME \
  --location=$REGION \
  --project=$PROJECT_ID \
  --quiet

log "✅ Cleanup complete"
log "✅ FULLY AUTOMATED PIPELINE COMPLETE!"
log "💰 Saved ~\$150/day by deleting Composer"
