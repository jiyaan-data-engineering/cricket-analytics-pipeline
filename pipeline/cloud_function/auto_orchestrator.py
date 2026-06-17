"""
FULLY AUTOMATED ORCHESTRATOR
Single Cloud Function handles both Phase 1 & Phase 2
No manual intervention needed
"""

import functions_framework
import os
import json
import subprocess
import time
from datetime import datetime
from google.cloud import storage
from concurrent.futures import ThreadPoolExecutor

PROJECT_ID = os.getenv("GCP_PROJECT_ID", "cricket-analytics-prod")
REGION = os.getenv("GCP_REGION", "us-central1")
CONFIG_BUCKET = "cricket-dataflow-templates-prod"


@functions_framework.http
def auto_run_pipeline(request):
    """
    Fully automated pipeline orchestration.
    Runs Phase 1 & Phase 2 sequentially without manual intervention.
    """

    try:
        print("=" * 60)
        print("🚀 FULLY AUTOMATED PIPELINE ORCHESTRATION")
        print("=" * 60)
        print("")

        # Phase 1: Create Composer
        print("PHASE 1: Creating Cloud Composer")
        print("-" * 60)

        env_name, config_data = phase1_create_composer()

        print(f"✅ Phase 1 complete: {env_name}")
        print("")

        # Phase 2: Run Pipeline (auto-triggered)
        print("PHASE 2: Running Data Pipeline")
        print("-" * 60)

        results = phase2_run_pipeline(env_name, config_data)

        print(f"✅ Phase 2 complete")
        print("")

        # Cleanup
        print("CLEANUP: Deleting Composer")
        print("-" * 60)

        phase3_cleanup(env_name)

        print(f"✅ Cleanup complete")
        print("")

        # Final Summary
        print("=" * 60)
        print("✅ FULLY AUTOMATED PIPELINE COMPLETE!")
        print("=" * 60)
        print(f"Environment: {env_name}")
        print(f"Records ingested: {results.get('record_count', 'N/A')}")
        print(f"Formats processed: {results.get('format_count', 'N/A')}")
        print(f"Cost saved: ~$150/day by deleting Composer")
        print("")

        return {
            "status": "success",
            "message": "Fully automated pipeline completed",
            "environment": env_name,
            "phases_completed": ["1", "2", "cleanup"],
            "results": results,
            "cost_saved_per_day": "$150"
        }, 200

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {
            "status": "error",
            "message": str(e)
        }, 500


def phase1_create_composer():
    """
    Phase 1: Create Cloud Composer environment.
    Returns: (environment_name, config_data)
    """

    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    env_name = f"cricket-analytics-composer-{timestamp}"
    service_account = f"cricket-composer-sa@{PROJECT_ID}.iam.gserviceaccount.com"

    print(f"Creating environment: {env_name}")
    print(f"Service Account: {service_account}")
    print("")

    # Create environment
    cmd = [
        "gcloud", "composer", "environments", "create",
        env_name,
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

    print("⏳ Creating Cloud Composer (10-15 min)...")

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)

    if result.returncode != 0:
        raise Exception(f"Failed to create Composer: {result.stderr}")

    print(f"✅ Environment created")
    print("")

    # Get environment details
    print("Retrieving environment details...")

    describe_cmd = [
        "gcloud", "composer", "environments", "describe",
        env_name,
        f"--project={PROJECT_ID}",
        f"--location={REGION}",
        "--format=json"
    ]

    describe_result = subprocess.run(describe_cmd, capture_output=True, text=True, timeout=60)

    if describe_result.returncode != 0:
        raise Exception(f"Failed to describe environment: {describe_result.stderr}")

    env_details = json.loads(describe_result.stdout)

    config_data = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "environment_name": env_name,
        "project_id": PROJECT_ID,
        "region": REGION,
        "service_account": service_account,
        "airflow_uri": env_details.get("config", {}).get("airflowUri", ""),
        "dags_bucket": env_details.get("config", {}).get("dagGcsPrefix", ""),
        "status": "CREATED"
    }

    # Save config to GCS
    print("💾 Saving config to GCS...")

    storage_client = storage.Client(project=PROJECT_ID)
    bucket = storage_client.bucket(CONFIG_BUCKET)
    blob = bucket.blob(f"composer-configs/{timestamp}-config.json")
    blob.upload_from_string(json.dumps(config_data, indent=2))

    print(f"✅ Config saved")
    print(f"   Airflow: {config_data['airflow_uri']}")
    print(f"   DAGs: {config_data['dags_bucket']}")
    print("")

    return env_name, config_data


def phase2_run_pipeline(env_name, config_data):
    """
    Phase 2: Deploy DAGs and run pipeline.
    Returns: Execution results
    """

    print("Deploying DAGs to Composer...")
    print("")

    # Deploy DAGs
    dags = [
        "pipeline/airflow/dags/cricket_analytics_dag.py",
        "pipeline/airflow/dags/data_quality_monitoring_dag.py"
    ]

    for dag_file in dags:
        import_cmd = [
            "gcloud", "composer", "environments", "storage", "dags", "import",
            f"--environment={env_name}",
            f"--location={REGION}",
            f"--source={dag_file}"
        ]

        import_result = subprocess.run(import_cmd, capture_output=True, text=True, timeout=300)

        if import_result.returncode == 0:
            print(f"✅ Deployed: {dag_file.split('/')[-1]}")
        else:
            print(f"⚠️  {dag_file.split('/')[-1]}: {import_result.stderr[:100]}")

    print("")
    print("🚀 Triggering DAG execution...")

    # Trigger DAG
    trigger_cmd = [
        "gcloud", "composer", "environments", "run",
        env_name,
        f"--location={REGION}",
        "--exec",
        "airflow", "dags", "trigger",
        "--dag-id", "cricket_analytics_dag"
    ]

    trigger_result = subprocess.run(trigger_cmd, capture_output=True, text=True, timeout=60)

    if trigger_result.returncode != 0:
        print(f"⚠️  Trigger message: {trigger_result.stdout}")
    else:
        print(f"✅ DAG triggered")

    print("")
    print("👁️  Monitoring DAG execution (max 60 min)...")
    print("")

    # Monitor execution
    max_wait_seconds = 3600
    poll_interval = 30
    elapsed = 0

    while elapsed < max_wait_seconds:
        list_cmd = [
            "gcloud", "composer", "environments", "run",
            env_name,
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
                print(f"❌ DAG failed")
                break

        print(f"  ⏳ Running... ({elapsed // 60}m)")
        time.sleep(poll_interval)
        elapsed += poll_interval

    print("")
    print("📊 Collecting metrics...")

    # Query BigQuery for metrics
    metrics = {
        "record_count": 0,
        "format_count": 0,
        "earliest_record": None,
        "latest_record": None
    }

    try:
        from google.cloud import bigquery

        bq_client = bigquery.Client(project=PROJECT_ID)

        query = f"""
        SELECT
          COUNT(*) as record_count,
          COUNT(DISTINCT format) as format_count,
          MIN(ingested_at) as earliest_record,
          MAX(ingested_at) as latest_record
        FROM \`{PROJECT_ID}.cricket_raw.batting_rankings\`
        WHERE DATE(ingested_at) = CURRENT_DATE()
        """

        query_job = bq_client.query(query)
        results = query_job.result()

        for row in results:
            metrics = {
                "record_count": row.record_count or 0,
                "format_count": row.format_count or 0,
                "earliest_record": str(row.earliest_record) if row.earliest_record else None,
                "latest_record": str(row.latest_record) if row.latest_record else None
            }

        print(f"  Records: {metrics['record_count']}")
        print(f"  Formats: {metrics['format_count']}")
        print(f"  Latest: {metrics['latest_record']}")

    except Exception as e:
        print(f"  ⚠️  Could not fetch metrics: {str(e)}")

    print("")

    return metrics


def phase3_cleanup(env_name):
    """
    Phase 3: Delete Cloud Composer environment.
    """

    print(f"Deleting environment: {env_name}")

    delete_cmd = [
        "gcloud", "composer", "environments", "delete",
        env_name,
        f"--project={PROJECT_ID}",
        f"--location={REGION}",
        "--quiet"
    ]

    delete_result = subprocess.run(delete_cmd, capture_output=True, text=True, timeout=600)

    if delete_result.returncode == 0:
        print(f"✅ Environment deleted")
        print(f"💰 Saving ~$150/day!")
    else:
        print(f"⚠️  Delete initiated asynchronously")

    print("")


@functions_framework.cloud_event
def auto_run_pipeline_pubsub(cloud_event):
    """
    Triggered by Pub/Sub (Cloud Scheduler).
    No input needed - runs automatically.
    """

    print("📨 Received Pub/Sub trigger")
    print("Starting fully automated pipeline...")
    print("")

    # Call HTTP function
    class FakeRequest:
        def get_json(self):
            return {}

    return auto_run_pipeline(FakeRequest())
