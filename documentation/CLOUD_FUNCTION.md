# ☁️ Cloud Function: Event-Driven Trigger

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete Cloud Function Setup

Complete guide for Cloud Function 2nd Gen (GCS → Dataflow trigger).

---

## 📋 Quick Overview

| Component | Value | Status |
|-----------|-------|--------|
| **Type** | Cloud Function 2nd Gen | ✅ |
| **Runtime** | Python 3.11 | ✅ |
| **Trigger** | GCS object finalization (Eventarc) | ✅ |
| **Memory** | 512 MB | ✅ |
| **Timeout** | 600 seconds | ✅ |
| **Max Instances** | 10 | ✅ |

---

## 🎯 Purpose

**Event-driven trigger**: When CSV file uploaded to GCS → automatically launch Dataflow job

**Flow**:
```
GCS Upload CSV
    ↓ (Finalized event)
Eventarc
    ↓
Cloud Function
    ↓
Validate file
    ↓
Launch Dataflow job
    ↓
Process CSV
```

---

## 💻 Code: cloud_function/main.py

```python
"""
Cloud Function triggered by GCS object finalization.
Launches Dataflow Flex Template job.
"""

import os
import logging
from pathlib import Path
from typing import Dict, Any

import yaml
import functions_framework
from google.cloud import dataflow_v1beta3

# Setup logging
logger = logging.getLogger(__name__)

# Load configuration from config.yaml
def load_config() -> dict:
    config_path = Path(__file__).parent.parent / "config" / "config.yaml"
    with open(config_path, "r") as f:
        return yaml.safe_load(f)

config = load_config()

# Environment variables override config
PROJECT_ID = os.getenv("GCP_PROJECT")
REGION = os.getenv("GCP_REGION", config["gcp"]["region"])
TEMPLATE_LOCATION = os.getenv("DATAFLOW_TEMPLATE_LOCATION",
                               f"gs://{config['gcs']['template_bucket']}/batting-pipeline")
BQ_DATASET = os.getenv("BQ_DATASET", config["bigquery"]["dataset_raw"])
BQ_TABLE = os.getenv("BQ_TABLE", config["bigquery"]["table_raw_batting"])
BATTING_PREFIX = config["gcs"].get("raw_prefix", "batting/")

@functions_framework.cloud_event
def process_batting_file(cloud_event: Dict[str, Any]) -> None:
    """
    Triggered by Cloud Storage finalized event.
    Launches Dataflow Flex Template job.
    """
    try:
        # Extract bucket and file information
        data = cloud_event.data
        bucket = data["bucket"]
        name = data["name"]
        
        logger.info(f"Processing file: gs://{bucket}/{name}")
        
        # Filter for batting rankings files
        if not name.startswith(BATTING_PREFIX):
            logger.info(f"Skipping file (not in {BATTING_PREFIX} prefix): {name}")
            return
        
        if not name.endswith(".csv"):
            logger.info(f"Skipping file (not CSV): {name}")
            return
        
        # Launch Dataflow Flex Template
        gcs_file_path = f"gs://{bucket}/{name}"
        job_name = f"batting-pipeline-{name.split('_')[2].replace('.csv', '').lower()}"
        
        logger.info(f"Launching Dataflow job: {job_name}")
        launch_dataflow_job(gcs_file_path, job_name)
        logger.info("Dataflow job launched successfully")
    
    except KeyError as e:
        logger.error(f"Missing required event data: {e}")
        raise
    except Exception as e:
        logger.error(f"Failed to process event: {e}")
        raise

def launch_dataflow_job(input_file: str, job_name: str) -> None:
    """Launch Dataflow Flex Template job."""
    client = dataflow_v1beta3.FlexTemplatesServiceClient()
    
    request = dataflow_v1beta3.LaunchFlexTemplateRequest(
        project_id=PROJECT_ID,
        launch_parameter={
            "jobName": job_name,
            "containerSpecGcsPath": TEMPLATE_LOCATION,
            "parameters": {
                "input_file": input_file,
                "output_dataset": BQ_DATASET,
                "output_table": BQ_TABLE,
            },
            "environment": {
                "serviceAccountEmail": f"cricket-dataflow-sa@{PROJECT_ID}.iam.gserviceaccount.com",
                "tempLocation": f"gs://{config['gcs']['temp_bucket']}/temp",
                "maxWorkers": config["dataflow"]["max_workers"],
                "machineType": config["dataflow"]["machine_type"],
            },
        },
        location=REGION,
    )
    
    response = client.launch_flex_template(request=request)
    logger.info(f"Dataflow job ID: {response.job.id}")
```

---

## 🔧 Requirements: cloud_function/requirements.txt

```
google-cloud-dataflow>=0.8.0
google-cloud-logging>=2.0.0
pyyaml
```

---

## 📋 Configuration

### Terraform: terraform/main.tf

```hcl
resource "google_cloudfunctions2_function" "gcs_trigger" {
  name        = "cricket-gcs-dataflow-trigger"
  description = "Triggered by GCS object finalization"
  location    = var.gcp_region
  
  service_config {
    max_instance_count = 10
    timeout_seconds    = 600
    memory_mb          = 512
    
    service_account_email = google_service_account.cloud_function_sa.email
    
    environment_variables = {
      "GCP_PROJECT" = var.gcp_project_id
      "GCP_REGION" = var.gcp_region
    }
  }
  
  event_trigger {
    event_type = "google.cloud.storage.object.v1.finalized"
    retry_policy = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.cloud_function_sa.email
  }
}
```

---

## 🚀 Deployment

### Step 1: Package Code

```bash
cd cloud_function
zip -r ../cloud-function-source.zip .
cd ..
```

### Step 2: Upload to GCS

```bash
gsutil cp cloud-function-source.zip \
  gs://cricket-dataflow-templates-PROJECT_ID/cloud-function/
```

### Step 3: Deploy via Terraform

```bash
cd terraform
terraform apply -target=google_cloudfunctions2_function.gcs_trigger
```

### Step 4: Test

```bash
# Upload test CSV to trigger
gsutil cp test.csv \
  gs://cricket-raw-data-PROJECT_ID/batting/

# Monitor logs
gcloud functions logs read cricket-gcs-dataflow-trigger \
  --gen2 --region us-central1 --limit 50
```

---

## 📊 Monitoring

### View Logs

```bash
gcloud functions logs read cricket-gcs-dataflow-trigger \
  --gen2 --region us-central1 --limit 100
```

### Metrics

```bash
# Check function invocations
gcloud monitoring read \
  "cloudfunctions.googleapis.com/function/execution_count" \
  --filter='resource.labels.function_name="cricket-gcs-dataflow-trigger"'
```

---

## ❌ Troubleshooting

### Issue: Function not triggered

```
Problem: Upload file but function doesn't trigger

Solution:
1. Check Eventarc trigger status
2. Verify file in batting/ prefix
3. Check service account permissions
4. Review Cloud Logging
```

### Issue: Dataflow job not launching

```
Problem: Function triggers but Dataflow doesn't start

Solution:
1. Check if BQ dataset exists
2. Verify service account has BigQuery Admin role
3. Check Dataflow template path
4. Review function logs for errors
```

### Issue: Timeout

```
Problem: Function exceeds 600 seconds

Solution:
1. Increase timeout_seconds in Terraform
2. Check Dataflow job size
3. Monitor network I/O
```

---

**Status**: ✅ Event-Driven Trigger Complete  
**Last Updated**: 2026-06-07  

Automatic CSV processing! ☁️
