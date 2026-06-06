"""
Cloud Function triggered by GCS object finalization.
Launches Dataflow Flex Template job to process batting rankings CSV.
"""

import os
import json
import logging
from typing import Dict, Any

import functions_framework
from google.cloud import dataflow_v1beta3
from google.cloud import logging as cloud_logging

# Setup Cloud Logging
logging_client = cloud_logging.Client()
logging_client.setup_logging()
logger = logging.getLogger(__name__)

PROJECT_ID = os.getenv("GCP_PROJECT")
REGION = os.getenv("GCP_REGION", "us-central1")
TEMPLATE_LOCATION = os.getenv("DATAFLOW_TEMPLATE_LOCATION",
                               "gs://cricket-dataflow-templates/batting-pipeline")
BQ_DATASET = os.getenv("BQ_DATASET", "cricket_raw")
BQ_TABLE = os.getenv("BQ_TABLE", "batting_rankings")

@functions_framework.cloud_event
def process_batting_file(cloud_event: Dict[str, Any]) -> None:
    """
    Triggered by Cloud Storage finalized event.
    Filters for batting/ prefix and launches Dataflow job.
    """
    try:
        # Extract bucket and file information
        data = cloud_event.data
        bucket = data["bucket"]
        name = data["name"]

        logger.info(f"Processing file: gs://{bucket}/{name}")

        # Filter for batting rankings files
        if not name.startswith("batting/"):
            logger.info(f"Skipping file (not in batting/ prefix): {name}")
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

    # Define flex template request
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
                "machineType": "n1-standard-2",
                "numWorkers": 2,
                "maxWorkers": 5,
                "zone": f"{REGION}-a",
                "additionalExperiments": ["enable_streaming_engine"],
            },
        }
    )

    response = client.launch_flex_template(request=request)
    logger.info(f"Flex Template job response: {response}")
