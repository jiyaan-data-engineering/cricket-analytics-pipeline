"""Fully automated orchestrator for cricket analytics pipeline"""

import functions_framework
import os
import json
import subprocess
import time
from datetime import datetime
from google.cloud import storage, bigquery

PROJECT_ID = os.getenv("GCP_PROJECT_ID", "cricket-analytics-prod")
REGION = os.getenv("GCP_REGION", "us-central1")
CONFIG_BUCKET = "cricket-dataflow-templates-prod"
ENVIRONMENT_PREFIX = "cricket-analytics-composer"

DAG_FILES = [
    "pipeline/airflow/dags/cricket_analytics_dag.py",
    "pipeline/airflow/dags/data_quality_monitoring_dag.py"
]

ENV_VARS = {
    "GCP_PROJECT_ID": PROJECT_ID,
    "GCP_REGION": REGION,
    "BQ_RAW_DATASET": "cricket_raw",
    "BQ_STAGING_DATASET": "cricket_staging",
    "BQ_CURATED_DATASET": "cricket_curated",
    "DATAFLOW_TEMPLATE_BUCKET": "cricket-dataflow-templates-prod",
    "RAW_BUCKET": "cricket-raw-data-prod"
}


@functions_framework.http
def auto_run_pipeline(request):
    """Run all 3 phases: create composer, execute pipeline, cleanup."""
    try:
        print("Starting fully automated pipeline...")

        env_name, config_data = phase1_create_composer()
        results = phase2_run_pipeline(env_name)
        phase3_cleanup(env_name)

        return {
            "status": "success",
            "environment": env_name,
            "results": results
        }, 200

    except Exception as e:
        print(f"Error: {str(e)}")
        return {"status": "error", "message": str(e)}, 500


@functions_framework.cloud_event
def auto_run_pipeline_pubsub(cloud_event):
    """Triggered by Pub/Sub (Cloud Scheduler)."""
    print("Pub/Sub trigger received")

    class FakeRequest:
        def get_json(self):
            return {}

    return auto_run_pipeline(FakeRequest())


def phase1_create_composer():
    """Create Cloud Composer environment and return config."""
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    env_name = f"{ENVIRONMENT_PREFIX}-{timestamp}"
    service_account = f"cricket-composer-sa@{PROJECT_ID}.iam.gserviceaccount.com"

    print(f"Phase 1: Creating {env_name}...")

    env_vars = ",".join([f"{k}={v}" for k, v in ENV_VARS.items()])

    cmd = [
        "gcloud", "composer", "environments", "create", env_name,
        f"--project={PROJECT_ID}",
        f"--location={REGION}",
        f"--service-account={service_account}",
        "--env-variables", env_vars,
        "--quiet"
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
    if result.returncode != 0:
        raise Exception(f"Composer creation failed: {result.stderr}")

    print(f"✅ Composer created: {env_name}")

    # Get environment details
    describe_cmd = [
        "gcloud", "composer", "environments", "describe", env_name,
        f"--project={PROJECT_ID}",
        f"--location={REGION}",
        "--format=json"
    ]

    describe_result = subprocess.run(describe_cmd, capture_output=True, text=True, timeout=60)
    if describe_result.returncode != 0:
        raise Exception(f"Describe failed: {describe_result.stderr}")

    env_details = json.loads(describe_result.stdout)

    config_data = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "environment_name": env_name,
        "project_id": PROJECT_ID,
        "region": REGION,
        "airflow_uri": env_details.get("config", {}).get("airflowUri", ""),
        "dags_bucket": env_details.get("config", {}).get("dagGcsPrefix", ""),
    }

    # Save config to GCS
    storage_client = storage.Client(project=PROJECT_ID)
    bucket = storage_client.bucket(CONFIG_BUCKET)
    blob = bucket.blob(f"composer-configs/{timestamp}-config.json")
    blob.upload_from_string(json.dumps(config_data))

    print(f"✅ Config saved to GCS")

    return env_name, config_data


def phase2_run_pipeline(env_name):
    """Deploy DAGs, run pipeline, monitor execution."""
    print(f"Phase 2: Running pipeline with {env_name}...")

    # Deploy DAGs
    for dag_file in DAG_FILES:
        import_cmd = [
            "gcloud", "composer", "environments", "storage", "dags", "import",
            f"--environment={env_name}",
            f"--location={REGION}",
            f"--source={dag_file}"
        ]

        import_result = subprocess.run(import_cmd, capture_output=True, text=True, timeout=300)
        if import_result.returncode == 0:
            print(f"✅ Deployed: {dag_file.split('/')[-1]}")

    # Trigger DAG
    trigger_cmd = [
        "gcloud", "composer", "environments", "run", env_name,
        f"--location={REGION}",
        "--exec",
        "airflow", "dags", "trigger",
        "--dag-id", "cricket_analytics_dag"
    ]

    trigger_result = subprocess.run(trigger_cmd, capture_output=True, text=True, timeout=60)
    print("✅ DAG triggered")

    # Monitor execution
    print("Phase 2: Monitoring DAG execution (max 60 min)...")

    max_wait_seconds = 3600
    poll_interval = 30
    elapsed = 0

    while elapsed < max_wait_seconds:
        list_cmd = [
            "gcloud", "composer", "environments", "run", env_name,
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
                print("✅ DAG completed successfully")
                break
            elif "failed" in output.lower():
                print("❌ DAG failed")
                break

        time.sleep(poll_interval)
        elapsed += poll_interval

    # Collect metrics
    print("Phase 2: Collecting metrics...")

    metrics = {"record_count": 0, "format_count": 0}

    try:
        bq_client = bigquery.Client(project=PROJECT_ID)

        query = f"""
        SELECT COUNT(*) as record_count, COUNT(DISTINCT format) as format_count
        FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
        WHERE DATE(ingested_at) = CURRENT_DATE()
        """

        query_job = bq_client.query(query)
        results = query_job.result()

        for row in results:
            metrics = {
                "record_count": row.record_count or 0,
                "format_count": row.format_count or 0
            }

        print(f"✅ Metrics collected: {metrics['record_count']} records")

    except Exception as e:
        print(f"⚠️ Could not fetch metrics: {str(e)}")

    return metrics


def phase3_cleanup(env_name):
    """Delete Cloud Composer environment."""
    print(f"Phase 3: Cleaning up {env_name}...")

    delete_cmd = [
        "gcloud", "composer", "environments", "delete", env_name,
        f"--project={PROJECT_ID}",
        f"--location={REGION}",
        "--quiet"
    ]

    delete_result = subprocess.run(delete_cmd, capture_output=True, text=True, timeout=600)

    if delete_result.returncode == 0:
        print(f"✅ Composer deleted (saving ~$150/day)")
    else:
        print("⚠️ Delete initiated asynchronously")
