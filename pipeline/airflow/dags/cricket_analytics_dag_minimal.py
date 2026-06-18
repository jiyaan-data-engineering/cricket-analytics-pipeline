"""
Cricket Analytics Pipeline DAG - Minimal Version for Testing
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.dataflow import DataflowTemplateOperator
from airflow.utils.task_group import TaskGroup
from airflow.models import Variable
import logging

logger = logging.getLogger(__name__)

# Configuration (use defaults for now, can be overridden with Airflow Variables)
PROJECT_ID = "cricket-analytics-prod"
GCP_REGION = "us-central1"
RAW_BUCKET = "cricket-raw-data-prod"
BQ_RAW_DATASET = "cricket_raw"

# DAG defaults
default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "start_date": datetime(2024, 6, 1),
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

# DAG Definition
dag = DAG(
    "cricket_analytics_dag",
    default_args=default_args,
    description="End-to-end cricket batting rankings analytics pipeline (minimal)",
    schedule_interval="0 6 * * *",  # Daily at 06:00 UTC
    catchup=False,
    tags=["cricket", "analytics"],
    max_active_runs=1,
)

# Task Functions
def fetch_data(**context):
    logger.info(f"Fetching data for project: {PROJECT_ID}")
    logger.info("This is a test task")
    return {"status": "success"}

def process_data(**context):
    logger.info(f"Processing data in dataset: {BQ_RAW_DATASET}")
    return {"status": "success"}

def validate_data(**context):
    logger.info("Validating data quality")
    return {"status": "success"}

def transform_with_bigquery(**context):
    logger.info(f"Running BigQuery transformation in {PROJECT_ID} dataset {BQ_RAW_DATASET}")
    logger.info("Query would run: SELECT COUNT(*) FROM batting_rankings")
    return {"status": "success"}

# Tasks
with dag:
    with TaskGroup("ingestion_tg") as ingestion_tg:
        fetch_task = PythonOperator(
            task_id="fetch_cricbuzz_api",
            python_callable=fetch_data,
        )

    with TaskGroup("processing_tg") as processing_tg:
        dataflow_task = DataflowTemplateOperator(
            task_id="launch_dataflow",
            template_location=f"gs://cricket-dataflow-templates-prod/batting-pipeline",
            project_id=PROJECT_ID,
            location=GCP_REGION,
            parameters={
                "inputFile": f"gs://{RAW_BUCKET}/batting/*.csv",
                "outputTable": f"{PROJECT_ID}:{BQ_RAW_DATASET}.batting_rankings",
            },
        )

    with TaskGroup("validation_tg") as validation_tg:
        bq_transform = PythonOperator(
            task_id="transform_with_bigquery",
            python_callable=transform_with_bigquery,
        )

    # Dependencies
    ingestion_tg >> processing_tg >> validation_tg
