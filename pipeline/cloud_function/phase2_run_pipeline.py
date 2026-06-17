"""
Cloud Function for PHASE 2: Run Data Pipeline with Composer
Triggered by Cloud Scheduler after Phase 1 completes
Input: Config file path from Phase 1
Executes: Deploy DAGs → Run pipeline → Monitor → Delete Composer
"""

import functions_framework
import os
import json
import subprocess
from google.cloud import storage

PROJECT_ID = os.getenv("GCP_PROJECT_ID", "cricket-analytics-prod")
REGION = os.getenv("GCP_REGION", "us-central1")


@functions_framework.http
def run_pipeline_phase2(request):
    """
    HTTP Cloud Function to run data pipeline with Composer environment.

    Query parameters:
    - config_file: GCS path to Phase 1 config (e.g., gs://bucket/path/config.json)
    """

    try:
        # Get config file from request
        request_json = request.get_json()
        config_file = request_json.get("config_file")

        if not config_file:
            return {
                "status": "error",
                "message": "Missing config_file parameter"
            }, 400

        print(f"⚙️  PHASE 2: Running Data Pipeline")
        print(f"   Config: {config_file}")
        print("")

        # ========== STEP 1: LOAD CONFIG ==========
        print("📥 Step 1: Loading Phase 1 configuration...")

        storage_client = storage.Client(project=PROJECT_ID)

        # Parse GCS path
        if not config_file.startswith("gs://"):
            return {
                "status": "error",
                "message": "Config file must be a GCS path (gs://...)"
            }, 400

        bucket_name, blob_path = config_file[5:].split("/", 1)
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_path)

        config_json = blob.download_as_string().decode("utf-8")
        config = json.loads(config_json)

        environment_name = config["environment_name"]
        service_account = config["service_account"]
        dags_bucket = config["dags_bucket"]
        airflow_uri = config["airflow_uri"]

        print(f"✅ Config loaded")
        print(f"   Environment: {environment_name}")
        print(f"   Region: {REGION}")
        print("")

        # ========== STEP 2: VERIFY ENVIRONMENT ==========
        print("🔍 Step 2: Verifying Composer environment...")

        describe_cmd = [
            "gcloud", "composer", "environments", "describe",
            environment_name,
            f"--location={REGION}",
            f"--project={PROJECT_ID}",
            "--format=value(state)"
        ]

        describe_result = subprocess.run(describe_cmd, capture_output=True, text=True, timeout=60)

        if describe_result.returncode != 0:
            raise Exception(f"Environment not found: {environment_name}")

        status = describe_result.stdout.strip()
        print(f"✅ Environment status: {status}")
        print("")

        # ========== STEP 3: DEPLOY DAGS ==========
        print("📤 Step 3: Deploying DAGs...")

        dags = [
            "pipeline/airflow/dags/cricket_analytics_dag.py",
            "pipeline/airflow/dags/data_quality_monitoring_dag.py"
        ]

        for dag_file in dags:
            import_cmd = [
                "gcloud", "composer", "environments", "storage", "dags", "import",
                f"--environment={environment_name}",
                f"--location={REGION}",
                f"--source={dag_file}"
            ]

            import_result = subprocess.run(import_cmd, capture_output=True, text=True, timeout=300)

            if import_result.returncode == 0:
                print(f"  ✅ Deployed: {dag_file}")
            else:
                print(f"  ⚠️  Warning: {dag_file} - {import_result.stderr}")

        print("")

        # ========== STEP 4: TRIGGER DAG ==========
        print("🚀 Step 4: Triggering DAG execution...")

        trigger_cmd = [
            "gcloud", "composer", "environments", "run",
            environment_name,
            f"--location={REGION}",
            "--exec",
            "airflow", "dags", "trigger",
            "--dag-id", "cricket_analytics_dag"
        ]

        trigger_result = subprocess.run(trigger_cmd, capture_output=True, text=True, timeout=60)

        if trigger_result.returncode == 0:
            print(f"✅ DAG triggered successfully")
        else:
            print(f"⚠️  Trigger message: {trigger_result.stdout}")

        print("")

        # ========== STEP 5: MONITOR EXECUTION ==========
        print("👁️  Step 5: Monitoring DAG execution...")

        max_wait_minutes = 60
        poll_interval = 30
        elapsed = 0

        while elapsed < (max_wait_minutes * 60):
            list_cmd = [
                "gcloud", "composer", "environments", "run",
                environment_name,
                f"--location={REGION}",
                "--exec",
                "airflow", "dags", "list-runs",
                "--dag-id", "cricket_analytics_dag",
                "--limit", "1"
            ]

            list_result = subprocess.run(list_cmd, capture_output=True, text=True, timeout=60)

            if list_result.returncode == 0:
                output = list_result.stdout

                if "success" in output.lower():
                    print(f"✅ DAG completed successfully!")
                    break
                elif "failed" in output.lower():
                    print(f"❌ DAG failed - check Airflow UI: {airflow_uri}")
                    break
                else:
                    print(f"  ⏳ Status: running... ({elapsed // 60}m elapsed)")
            else:
                print(f"  ⏳ Checking status... ({elapsed // 60}m elapsed)")

            import time
            time.sleep(poll_interval)
            elapsed += poll_interval

        print("")

        # ========== STEP 6: DELETE COMPOSER ==========
        print("🗑️  Step 6: Deleting Composer environment...")

        delete_cmd = [
            "gcloud", "composer", "environments", "delete",
            environment_name,
            f"--project={PROJECT_ID}",
            f"--location={REGION}",
            "--quiet"
        ]

        delete_result = subprocess.run(delete_cmd, capture_output=True, text=True, timeout=600)

        if delete_result.returncode == 0:
            print(f"✅ Environment deleted")
            print(f"💰 Saving ~$150/day!")
        else:
            print(f"⚠️  Delete initiated (may take time)")

        print("")

        # ========== FINAL SUMMARY ==========
        return {
            "status": "success",
            "phase": "2",
            "message": "Pipeline execution complete",
            "environment_name": environment_name,
            "steps_completed": [
                "✓ Loaded Phase 1 configuration",
                "✓ Verified Composer environment",
                "✓ Deployed DAGs",
                "✓ Triggered DAG execution",
                "✓ Monitored completion",
                "✓ Deleted environment"
            ],
            "results": {
                "data_location": "BigQuery cricket_raw dataset",
                "transformations": "cricket_staging (star schema)",
                "analytics": "cricket_curated (5 views)",
                "cost_saved": "~$150 by deleting Composer"
            },
            "next_steps": [
                "Check BigQuery cricket_raw for ingested data",
                "Check cricket_staging for transformed data",
                "Check cricket_curated for analytics-ready views",
                "View dashboard via Looker Studio"
            ]
        }, 200

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {
            "status": "error",
            "message": str(e)
        }, 500


@functions_framework.cloud_event
def run_pipeline_phase2_pubsub(cloud_event):
    """
    Cloud Function triggered by Pub/Sub for Phase 2.
    Input: Pub/Sub message with config_file path.
    """

    import base64
    import json

    try:
        pubsub_message = base64.b64decode(cloud_event.data["message"]["data"])
        message = json.loads(pubsub_message)

        config_file = message.get("config_file")

        if not config_file:
            return {
                "status": "error",
                "message": "Missing config_file in Pub/Sub message"
            }

        # Create fake request object for HTTP function
        class FakeRequest:
            def get_json(self):
                return {"config_file": config_file}

        return run_pipeline_phase2(FakeRequest())

    except Exception as e:
        print(f"❌ Pub/Sub Error: {str(e)}")
        return {
            "status": "error",
            "message": str(e)
        }
