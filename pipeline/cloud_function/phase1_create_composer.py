"""
Cloud Function for PHASE 1: Create Cloud Composer Environment
Triggered by Cloud Scheduler or manual call
Returns: Config JSON saved to GCS
"""

import functions_framework
import os
import json
import subprocess
from datetime import datetime
from google.cloud import storage

PROJECT_ID = os.getenv("GCP_PROJECT_ID", "cricket-analytics-prod")
REGION = os.getenv("GCP_REGION", "us-central1")
CONFIG_BUCKET = "cricket-dataflow-templates-prod"


@functions_framework.http
def create_composer_phase1(request):
    """
    HTTP Cloud Function to create Cloud Composer environment.

    Returns: JSON with environment details for Phase 2
    """

    try:
        # Generate unique environment name
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        environment_name = f"cricket-analytics-composer-{timestamp}"
        service_account = f"cricket-composer-sa@{PROJECT_ID}.iam.gserviceaccount.com"

        print(f"🚀 PHASE 1: Creating Cloud Composer")
        print(f"   Environment: {environment_name}")
        print(f"   Project: {PROJECT_ID}")
        print(f"   Region: {REGION}")
        print("")

        # Create Cloud Composer environment
        print("⏳ Creating environment (takes 10-15 minutes)...")

        cmd = [
            "gcloud", "composer", "environments", "create",
            environment_name,
            f"--project={PROJECT_ID}",
            f"--location={REGION}",
            f"--service-account={service_account}",
            "--env-variables",
            f"GCP_PROJECT_ID={PROJECT_ID},"
            f"GCP_REGION={REGION},"
            f"BQ_RAW_DATASET=cricket_raw,"
            f"BQ_STAGING_DATASET=cricket_staging,"
            f"BQ_CURATED_DATASET=cricket_curated,"
            f"DATAFLOW_TEMPLATE_BUCKET=cricket-dataflow-templates-prod,"
            f"RAW_BUCKET=cricket-raw-data-prod",
            "--quiet"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)

        if result.returncode != 0:
            raise Exception(f"Failed to create environment: {result.stderr}")

        print(f"✅ Environment created: {environment_name}")
        print("")

        # Get environment details
        print("📋 Retrieving environment details...")

        describe_cmd = [
            "gcloud", "composer", "environments", "describe",
            environment_name,
            f"--project={PROJECT_ID}",
            f"--location={REGION}",
            "--format=json"
        ]

        describe_result = subprocess.run(describe_cmd, capture_output=True, text=True, timeout=60)

        if describe_result.returncode != 0:
            raise Exception(f"Failed to describe environment: {describe_result.stderr}")

        environment_details = json.loads(describe_result.stdout)

        # Extract key details
        config_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "project_id": PROJECT_ID,
            "region": REGION,
            "environment_name": environment_name,
            "service_account": service_account,
            "airflow_uri": environment_details.get("config", {}).get("airflowUri", ""),
            "dags_bucket": environment_details.get("config", {}).get("dagGcsPrefix", ""),
            "status": environment_details.get("state", "UNKNOWN")
        }

        print(f"✅ Details retrieved")
        print(f"   Airflow URI: {config_data['airflow_uri']}")
        print(f"   DAGs Bucket: {config_data['dags_bucket']}")
        print("")

        # Save config to GCS
        print("💾 Saving config to GCS...")

        config_file = f"gs://{CONFIG_BUCKET}/composer-configs/{timestamp}-config.json"
        storage_client = storage.Client(project=PROJECT_ID)
        bucket = storage_client.bucket(CONFIG_BUCKET)
        blob = bucket.blob(f"composer-configs/{timestamp}-config.json")
        blob.upload_from_string(json.dumps(config_data, indent=2))

        print(f"✅ Config saved: {config_file}")
        print("")

        # Return success with config location
        return {
            "status": "success",
            "phase": "1",
            "message": "Cloud Composer environment created successfully",
            "environment_name": environment_name,
            "config_file": config_file,
            "config": config_data,
            "next_step": f"Use config file with Phase 2: phase2-run-pipeline.sh {config_file}"
        }, 200

    except subprocess.TimeoutExpired:
        return {
            "status": "timeout",
            "message": "Environment creation timeout (expected for 10-15 min operation)",
            "note": "Environment may still be creating. Check gcloud status."
        }, 202

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {
            "status": "error",
            "message": str(e)
        }, 500


@functions_framework.cloud_event
def create_composer_phase1_pubsub(cloud_event):
    """
    Cloud Function triggered by Pub/Sub for Phase 1.
    Can be scheduled via Cloud Scheduler.
    """

    print(f"📨 Received Pub/Sub event: {cloud_event}")

    # Call the HTTP function logic
    result, status_code = create_composer_phase1(None)

    return result
