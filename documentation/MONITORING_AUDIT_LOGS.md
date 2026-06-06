# 📋 Monitoring, Audit & Logs Management

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete Operations Guide

Complete guide for monitoring, auditing, and log management in production.

---

## 📊 Overview

| Component | Tool | Status | Details |
|-----------|------|--------|---------|
| **Logging** | Cloud Logging | ✅ | All events captured |
| **Monitoring** | Cloud Monitoring | ✅ | Metrics & alerts |
| **Audit** | Cloud Audit Logs | ✅ | Compliance tracking |
| **Failure Handling** | Retry Logic | ✅ | Built-in resiliency |
| **Dashboards** | Custom Dashboards | ✅ | KPI visualization |

---

## 📝 Logging Architecture

```
Components
├─ Cloud Run (Ingestion)
├─ Cloud Function
├─ Dataflow Jobs
├─ BigQuery Queries
├─ Cloud Scheduler
└─ Cloud Composer (Airflow)
    ↓
Cloud Logging
    ├─ Structure: JSON format
    ├─ Retention: Configurable
    ├─ Query: Via Cloud Logging Explorer
    └─ Export: To GCS, BigQuery
```

---

## 🔍 Logging by Component

### 1. Cloud Function Logs

**Where**: Cloud Logging → Cloud Functions

```bash
# View logs
gcloud functions logs read cricket-gcs-dataflow-trigger \
  --gen2 --region us-central1 --limit 100

# Filter by severity
gcloud logging read \
  'resource.type="cloud_function" AND severity=ERROR' \
  --limit 50 --format json
```

**Log Structure**:
```json
{
  "timestamp": "2026-06-07T10:00:00Z",
  "severity": "INFO",
  "function_name": "cricket-gcs-dataflow-trigger",
  "message": "Launching Dataflow job: batting-pipeline-20260607_100000",
  "trace_id": "abc123def456"
}
```

**Key Metrics**:
- Function invocations
- Execution time
- Memory usage
- Error rate

### 2. Dataflow Logs

**Where**: Cloud Logging → Dataflow

```bash
# View logs for specific job
gcloud logging read \
  "resource.type=dataflow_step AND labels.job_id=JOB_ID" \
  --limit 200 --format json
```

**Log Levels**:
- **INFO**: Normal operation (record counts, file reads)
- **WARNING**: Skipped records, malformed lines
- **ERROR**: Type conversion failures, API errors

**What's Logged**:
- Record processing count
- Skipped records (with reasons)
- Type conversion errors
- BigQuery write operations

### 3. Cloud Scheduler Logs

**Where**: Cloud Logging → Cloud Scheduler

```bash
# View scheduler job history
gcloud scheduler jobs describe cricket-daily-ingestion \
  --location us-central1 \
  --format=json | jq '.schedule, .timezone'

# View execution logs
gcloud logging read \
  "resource.type=cloud_scheduler_job" \
  --limit 50
```

**Tracks**:
- Job execution time
- Success/failure status
- Cloud Run/Function invocation results

### 4. Airflow (Cloud Composer) Logs

**Where**: Cloud Logging → Cloud Composer

```bash
# View DAG logs
gcloud logging read \
  "resource.type=cloud_composer_environment \
   AND jsonPayload.dag_id=cricket_analytics_pipeline" \
  --limit 100
```

**DAG Logs Include**:
- Task execution time
- Task success/failure
- Dataflow job IDs
- SQL query execution
- SLA violations

### 5. BigQuery Logs

**Where**: Cloud Logging & BigQuery console

```bash
# View BigQuery query logs
bq ls -j  # List jobs

# Get job details
bq show -j JOB_ID

# Check table statistics
bq show cricket_raw.batting_rankings
```

**Tracks**:
- Query execution time
- Bytes scanned/processed
- Slot usage
- Error details

---

## 🚨 Failure Handling & Retry Logic

### Dataflow Retry Policy

```hcl
# terraform/main.tf
resource "google_dataflow_job" "example" {
  max_workers    = 5
  enable_streaming_engine = false
  
  on_delete = "cancel"  # Cancel job on terraform destroy
}
```

**Default Behavior**:
- ✅ Retries failed work items (auto)
- ✅ Max 4 retries per item
- ✅ Exponential backoff (1s → 64s)
- ✅ Skips bad records, continues processing

### Cloud Function Retry

```hcl
# terraform/main.tf
resource "google_cloudfunctions2_function" "trigger" {
  service_config {
    max_instance_count = 10
    timeout_seconds = 600
  }
  
  event_trigger {
    retry_policy = "RETRY_POLICY_DO_NOT_RETRY"  # No auto-retry
  }
}
```

**If Function Fails**:
- ❌ Event is lost (not retried)
- ✅ Error logged to Cloud Logging
- ⚠️ Need manual re-triggering if critical

**Solution**: Configure alerting!

### Cloud Scheduler Retry

```hcl
# terraform/main.tf
resource "google_cloud_scheduler_job" "ingest" {
  http_target {
    uri = google_cloudrun_service.ingestion.status[0].url
  }
  
  retry_config {
    retry_count = 5
    max_retry_duration = "3600s"  # 1 hour
    min_backoff_duration = "60s"
    max_backoff_duration = "3600s"
  }
}
```

**Retry Behavior**:
- ✅ Retries up to 5 times
- ✅ Exponential backoff
- ✅ Stops after 1 hour of trying

### Airflow DAG Retry

```python
# airflow/dags/cricket_analytics_dag.py
default_args = {
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'email_on_failure': True,
    'email': ['admin@example.com'],
    'sla': timedelta(hours=24),
}
```

**Task Retry**:
- ✅ 2 automatic retries on failure
- ✅ 5-minute wait between retries
- ✅ Email notification on failure
- ✅ SLA alert if > 24 hours

---

## 📊 Monitoring & Alerting

### Cloud Monitoring Metrics

**Key Metrics to Track**:

```
Dataflow:
  - job/billable_shuffle_data_processed (bytes)
  - job/elapsed_time (seconds)
  - job/worker_count (instances)
  - job/worker_cpu_utilization (%)

BigQuery:
  - slots_total_allocated (slots)
  - slots_total_allocated_capacity (percent)
  - table_size (bytes)
  - query_scanned_bytes (bytes)

Cloud Function:
  - function/execution_count (invocations)
  - function/execution_times (ms)
  - function/errors (count)
```

### Setting Up Alerts

```hcl
# terraform/main.tf
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "Dataflow High Error Rate"
  combiner     = "OR"
  
  conditions {
    display_name = "Error rate > 1%"
    
    condition_threshold {
      filter          = "resource.type=\"dataflow_job\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.01
      
      aggregations {
        alignment_period  = "300s"  # 5 minutes
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]
  
  documentation {
    content = "Dataflow job has > 1% error rate"
  }
}
```

**Alert Channels**:
- Email notifications
- Slack integration
- SMS/PagerDuty
- Webhooks

---

## 🔐 Audit Logging

### Cloud Audit Logs

**Automatically Captured**:
- Who accessed what resource
- When they accessed it
- What changes were made

**View Audit Logs**:

```bash
# View all audit logs for a resource
gcloud logging read \
  'protoPayload.resourceName="projects/PROJECT_ID/datasets/cricket_raw"' \
  --limit 50 \
  --format json

# View who deleted a table
gcloud logging read \
  'protoPayload.methodName=bigquery.tables.delete' \
  --limit 20
```

**Compliance**:
- ✅ Stores for 90 days (free)
- ✅ Export to BigQuery for longer retention
- ✅ Immutable logs
- ✅ Compliance reports

### Enable Audit Logging for BigQuery

```hcl
# terraform/main.tf
resource "google_bigquery_dataset" "raw" {
  # Enable audit logs
  access {
    role          = "roles/bigquery.dataOwner"
    user_by_email = google_service_account.audit.email
  }
}
```

---

## 📈 Custom Dashboards

### Create Monitoring Dashboard

```bash
# Via GCP Console
1. Go to Cloud Monitoring
2. Click "Dashboards" → "Create Dashboard"
3. Add widgets:
   - Dataflow job execution time (line chart)
   - Record processing rate (gauge)
   - Error rate (heatmap)
   - BigQuery query latency (bar chart)
   - Pipeline success rate (scorecard)
```

### Example Dashboard Query

```
Metric: dataflow_step/data_processed_bytes
Filter: resource.job_name =~ "batting-pipeline-.*"
Aggregation: SUM every 1 minute
Visualization: Line chart
```

---

## 🔍 Querying Logs

### Log Sink to BigQuery

```bash
# Create sink to export logs to BigQuery
gcloud logging sinks create cricket-logs-sink \
  bigquery.googleapis.com/projects/PROJECT_ID/datasets/audit_logs \
  --log-filter='resource.type=("cloud_function" OR "dataflow_step")'
```

### Query Logs from BigQuery

```sql
SELECT
  TIMESTAMP_TRUNC(timestamp, DAY) as date,
  severity,
  COUNT(*) as event_count,
  APPROX_TOP_COUNT(jsonPayload.message, 1)[OFFSET(0)].value as top_message
FROM `project.audit_logs.cloudfunction_googleapis_com`
WHERE DATE(timestamp) >= CURRENT_DATE() - 7
GROUP BY date, severity
ORDER BY date DESC
```

---

## 📋 Audit Trail for Compliance

### Track Data Changes

```sql
-- Query audit logs for data modifications
SELECT
  TIMESTAMP_TRUNC(timestamp, DAY) as date,
  protoPayload.authenticationInfo.principalEmail as user,
  protoPayload.methodName as action,
  protoPayload.resourceName as resource,
  protoPayload.status.message as status
FROM `project.audit_logs.cloudaudit_googleapis_com`
WHERE protoPayload.methodName LIKE '%bigquery.tables.%'
  AND DATE(timestamp) >= CURRENT_DATE() - 30
ORDER BY timestamp DESC
```

### Generate Compliance Report

```bash
# Export audit logs for compliance
bq extract \
  audit_logs.cloudaudit_googleapis_com \
  gs://compliance-bucket/audit-logs-2026-06.json \
  --destination_format NEWLINE_DELIMITED_JSON
```

---

## ✅ Best Practices

### 1. Log Aggregation
- ✅ Centralize all logs in Cloud Logging
- ✅ Use consistent log format
- ✅ Add trace IDs for correlation

### 2. Alerting
- ✅ Alert on error rate > 1%
- ✅ Alert on job duration > threshold
- ✅ Alert on missing daily runs
- ✅ Alert on SLA violations

### 3. Retention
- ✅ Default: 30 days in Cloud Logging
- ✅ Export to BigQuery for analytics
- ✅ Archive to GCS for long-term storage

### 4. Audit
- ✅ Review audit logs weekly
- ✅ Export for compliance
- ✅ Alert on unauthorized access

---

## 🔧 Troubleshooting

### Issue: No logs appearing

```
Check:
1. Cloud Logging API enabled
2. Service account has logging.logWriter role
3. Log filtering is not too restrictive
4. Resource exists and is active
```

### Issue: Logs deleted accidentally

```
Note: Deleted logs CANNOT be recovered
Prevention:
1. Enable log locking (if compliance required)
2. Export to BigQuery (immutable copy)
3. Archive to GCS regularly
```

### Issue: Cost of logging is high

```
Solutions:
1. Increase retention period filter
2. Exclude verbose DEBUG logs
3. Use log sinks to filter
4. Archive old logs to GCS (cheaper storage)
```

---

**Status**: ✅ Complete Monitoring & Audit Guide  
**Components Covered**: 6 (Logging, Monitoring, Audit, Failure, Alerts, Dashboards)  
**Last Updated**: 2026-06-07  

Full operational visibility! 📋
