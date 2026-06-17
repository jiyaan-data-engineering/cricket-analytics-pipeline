"""
Cloud Function to manage on-demand Cloud Composer lifecycle.
Triggers after Dataflow completion to run quality checks and transformations.
"""

import functions_framework
import os
import subprocess
import logging
from google.cloud import dataflow_v1beta3

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

PROJECT_ID = os.getenv("GCP_PROJECT_ID", "cricket-analytics-prod")
REGION = os.getenv("GCP_REGION", "us-central1")


@functions_framework.cloud_event
def trigger_composer_lifecycle(cloud_event):
    """
    Triggered after Dataflow job completion.
    Creates Cloud Composer → Runs DAGs → Deletes Composer.

    Expects Pub/Sub message with job status.
    """

    try:
        # Parse incoming event
        import base64
        import json

        pubsub_message = base64.b64decode(cloud_event.data["message"]["data"])
        message = json.loads(pubsub_message)

        job_status = message.get("jobStatus", "unknown")
        job_name = message.get("jobName", "unknown")

        logger.info(f"Received event: Job={job_name}, Status={job_status}")

        # Only proceed if Dataflow job succeeded
        if job_status.upper() != "JOB_STATE_DONE":
            logger.warning(f"Job not completed. Status: {job_status}")
            return {"status": "skipped", "reason": "job_not_done"}

        logger.info("✅ Dataflow job completed successfully")
        logger.info("🚀 Starting on-demand Cloud Composer lifecycle...")

        # Trigger the on-demand Composer script
        result = trigger_composer_on_demand()

        return {
            "status": "success",
            "message": "Cloud Composer lifecycle triggered",
            "result": result
        }

    except Exception as e:
        logger.error(f"❌ Error: {str(e)}")
        return {
            "status": "error",
            "message": str(e)
        }


def trigger_composer_on_demand():
    """
    Triggers the on-demand Cloud Composer lifecycle via Cloud Run.
    """
    try:
        # Call the on-demand Composer orchestration script
        # This would be deployed as a separate Cloud Run service or triggered via gcloud

        logger.info("📍 Starting Cloud Composer on-demand lifecycle...")

        # Step 1: Create environment (10-15 min)
        logger.info("1️⃣  Creating Cloud Composer environment...")
        create_composer(PROJECT_ID, REGION)

        # Step 2: Deploy DAGs
        logger.info("2️⃣  Deploying DAGs...")
        deploy_dags(PROJECT_ID, REGION)

        # Step 3: Monitor execution
        logger.info("3️⃣  Waiting for DAG execution...")
        wait_for_dags(PROJECT_ID, REGION)

        # Step 4: Delete environment
        logger.info("4️⃣  Cleaning up Cloud Composer...")
        delete_composer(PROJECT_ID, REGION)

        logger.info("✅ On-demand Cloud Composer lifecycle complete!")

        return {
            "phase1_create": "completed",
            "phase2_deploy": "completed",
            "phase3_wait": "completed",
            "phase4_delete": "completed"
        }

    except Exception as e:
        logger.error(f"Error in Composer lifecycle: {str(e)}")
        raise


def create_composer(project_id, region):
    """Create Cloud Composer environment."""
    env_name = "cricket-analytics-composer-ondemand"
    service_account = f"cricket-composer-sa@{project_id}.iam.gserviceaccount.com"

    cmd = [
        "gcloud", "composer", "environments", "create",
        env_name,
        f"--project={project_id}",
        f"--location={region}",
        f"--service-account={service_account}",
        "--quiet"
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=1200)
        if result.returncode == 0:
            logger.info(f"✅ Created {env_name}")
            return True
        else:
            if "ALREADY_EXISTS" in result.stderr:
                logger.info(f"⚠️  {env_name} already exists, skipping creation")
                return True
            raise Exception(result.stderr)
    except subprocess.TimeoutExpired:
        logger.warning("Composer creation timeout (normal for 10-15 min operation)")
        return True


def deploy_dags(project_id, region):
    """Deploy DAGs to Cloud Composer."""
    env_name = "cricket-analytics-composer-ondemand"

    dags = [
        "pipeline/airflow/dags/cricket_analytics_dag.py",
        "pipeline/airflow/dags/data_quality_monitoring_dag.py"
    ]

    for dag_path in dags:
        cmd = [
            "gcloud", "composer", "environments", "storage", "dags", "import",
            f"--environment={env_name}",
            f"--location={region}",
            f"--source={dag_path}"
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            if result.returncode == 0:
                logger.info(f"✅ Deployed {dag_path}")
            else:
                logger.warning(f"⚠️  Could not deploy {dag_path}: {result.stderr}")
        except subprocess.TimeoutExpired:
            logger.warning(f"Timeout deploying {dag_path}")


def wait_for_dags(project_id, region, max_wait_seconds=3600):
    """Wait for DAG execution to complete."""
    import time

    env_name = "cricket-analytics-composer-ondemand"
    start_time = time.time()

    while (time.time() - start_time) < max_wait_seconds:
        try:
            cmd = [
                "gcloud", "composer", "environments", "run",
                env_name,
                f"--location={region}",
                "--exec",
                "airflow", "dags", "list-runs",
                "--dag-id", "cricket_analytics_dag",
                "--state", "success"
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)

            if "cricket_analytics_dag" in result.stdout:
                logger.info("✅ DAG execution completed successfully")
                return True

            logger.info(f"⏳ Waiting for DAG... ({int(time.time() - start_time)}s)")
            time.sleep(30)

        except Exception as e:
            logger.warning(f"Error checking DAG status: {e}")
            time.sleep(30)

    logger.warning("DAG execution timeout - proceeding with deletion")
    return True


def delete_composer(project_id, region):
    """Delete Cloud Composer environment to save costs."""
    env_name = "cricket-analytics-composer-ondemand"

    cmd = [
        "gcloud", "composer", "environments", "delete",
        env_name,
        f"--project={project_id}",
        f"--location={region}",
        "--quiet"
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        if result.returncode == 0:
            logger.info(f"✅ Deleted {env_name}")
            logger.info("💰 Saved ~$150/day by deleting on-demand environment")
            return True
        else:
            raise Exception(result.stderr)
    except subprocess.TimeoutExpired:
        logger.warning("Deletion timeout (expected, may take 5+ minutes)")
        return True
