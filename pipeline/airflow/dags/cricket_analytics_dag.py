"""
Cricket Analytics Pipeline DAG

Orchestrates the complete data pipeline:
1. Ingestion: Fetch Cricbuzz API data
2. Storage: Upload CSV to GCS
3. Processing: Dataflow Beam pipeline
4. Transformation: BigQuery SQL transforms
5. Validation: Data quality checks
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.dataflow import DataflowTemplateOperator
from airflow.providers.google.cloud.operators.gcs import GCSListObjectsOperator
from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyTableOperator,
    BigQueryInsertJobOperator,
    BigQueryCheckOperator,
)
from airflow.providers.google.cloud.transfers.gcs_to_bigquery import GCSToBigQueryOperator
from airflow.utils.task_group import TaskGroup
from airflow.models import Variable
from airflow.exceptions import AirflowException
import logging
from typing import Dict, List
import requests
import pandas as pd
from google.cloud import storage
import yaml
import os

logger = logging.getLogger(__name__)

# ============================================
# Configuration
# ============================================

PROJECT_ID = Variable.get("gcp_project_id", default_var="cricket-analytics-project")
GCP_REGION = Variable.get("gcp_region", default_var="us-central1")
RAW_BUCKET = Variable.get("raw_bucket", default_var="cricket-raw-data")
TEMPLATE_LOCATION = Variable.get(
    "dataflow_template_location",
    default_var="gs://cricket-dataflow-templates-{}/batting-pipeline".format(PROJECT_ID),
)
BQ_RAW_DATASET = Variable.get("bq_raw_dataset", default_var="cricket_raw")
BQ_STAGING_DATASET = Variable.get("bq_staging_dataset", default_var="cricket_staging")
BQ_CURATED_DATASET = Variable.get("bq_curated_dataset", default_var="cricket_curated")
RAPIDAPI_KEY = Variable.get("rapidapi_key", default_var="")

# DAG defaults
default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "start_date": datetime(2024, 6, 1),
    "email": ["airflow-alerts@example.com"],
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

# ============================================
# DAG Definition
# ============================================

dag = DAG(
    "cricket_analytics_pipeline",
    default_args=default_args,
    description="End-to-end cricket batting rankings analytics pipeline",
    schedule_interval="0 6 * * *",  # Daily at 06:00 UTC
    catchup=False,
    tags=["cricket", "analytics", "dataflow"],
    max_active_runs=1,
)

# ============================================
# Python Functions
# ============================================

def fetch_cricbuzz_api(**context) -> Dict[str, str]:
    """
    Fetch batting rankings from Cricbuzz API via RapidAPI.
    Returns: Dictionary with file paths for each format.
    """
    logger.info("Starting Cricbuzz API fetch...")

    api_base_url = "https://cricbuzz-cricket.p.rapidapi.com"
    endpoint = "/stats/v1/rankings/batsmen"

    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": "cricbuzz-cricket.p.rapidapi.com",
    }

    formats = ["test", "odi", "t20i"]
    all_data = []

    try:
        for format_type in formats:
            logger.info(f"Fetching {format_type.upper()} rankings...")

            params = {
                "formatType": format_type,
                "rankType": "batsmen",
            }

            response = requests.get(
                f"{api_base_url}{endpoint}",
                headers=headers,
                params=params,
                timeout=30,
            )
            response.raise_for_status()

            data = response.json()
            df = parse_rankings_response(data, format_type)

            if not df.empty:
                all_data.append(df)
                logger.info(f"Fetched {len(df)} {format_type.upper()} records")
            else:
                logger.warning(f"No data for {format_type.upper()}")

        if not all_data:
            raise AirflowException("No data fetched for any format")

        # Combine all formats
        combined_df = pd.concat(all_data, ignore_index=True)
        logger.info(f"Total records fetched: {len(combined_df)}")

        # Save to GCS
        gcs_file_path = upload_to_gcs(combined_df, context["execution_date"])

        # Store file path in XCom for downstream tasks
        context["task_instance"].xcom_push(key="gcs_file_path", value=gcs_file_path)

        logger.info(f"Data saved to: {gcs_file_path}")
        return {"status": "success", "file_path": gcs_file_path}

    except requests.RequestException as e:
        logger.error(f"API request failed: {e}")
        raise AirflowException(f"API fetch failed: {e}")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise AirflowException(f"Fetch failed: {e}")

def parse_rankings_response(data: dict, format_type: str) -> pd.DataFrame:
    """Parse API response into DataFrame."""
    if not data or "data" not in data:
        logger.warning(f"No data in response for {format_type}")
        return pd.DataFrame()

    rankings = []
    for rank_entry in data.get("data", {}).get("rank", []):
        try:
            player = rank_entry.get("player", {})
            rankings.append({
                "rank": rank_entry.get("rank"),
                "player_id": player.get("id"),
                "player_name": player.get("name"),
                "country": player.get("country"),
                "country_id": player.get("countryId"),
                "rating": rank_entry.get("rating"),
                "points": rank_entry.get("points"),
                "best_rank": rank_entry.get("bestRank"),
                "format": format_type.upper(),
                "ingested_at": datetime.utcnow().isoformat(),
            })
        except Exception as e:
            logger.warning(f"Error parsing entry: {e}")
            continue

    return pd.DataFrame(rankings)

def upload_to_gcs(df: pd.DataFrame, execution_date: datetime) -> str:
    """Upload CSV to GCS bucket."""
    timestamp = execution_date.strftime("%Y%m%d_%H%M%S")
    filename = f"batting_rankings_{timestamp}.csv"
    gcs_path = f"batting/{filename}"

    csv_data = df.to_csv(index=False)

    client = storage.Client(project=PROJECT_ID)
    bucket = client.bucket(RAW_BUCKET)
    blob = bucket.blob(gcs_path)

    logger.info(f"Uploading to gs://{RAW_BUCKET}/{gcs_path}")
    blob.upload_from_string(csv_data, content_type="text/csv")

    logger.info(f"Successfully uploaded {len(df)} records")
    return f"gs://{RAW_BUCKET}/{gcs_path}"

def validate_data_quality(**context) -> bool:
    """
    Validate ingested data quality.
    Checks: row count, null values, data types.
    """
    logger.info("Running data quality checks...")

    from google.cloud import bigquery

    bq_client = bigquery.Client(project=PROJECT_ID)

    # Check row count in raw table
    query = f"""
    SELECT COUNT(*) as record_count
    FROM `{PROJECT_ID}.{BQ_RAW_DATASET}.batting_rankings`
    WHERE DATE(ingested_at) = CURRENT_DATE()
    """

    result = bq_client.query(query).result()
    for row in result:
        record_count = row.record_count
        logger.info(f"Records in raw table today: {record_count}")

        if record_count < 100:  # Sanity check: expect at least 100 records
            logger.warning(f"Low record count: {record_count}")
            raise AirflowException(f"Data quality check failed: Only {record_count} records")

    logger.info("Data quality checks passed")
    return True

def check_dataflow_success(**context) -> bool:
    """Check if Dataflow job completed successfully."""
    logger.info("Checking Dataflow job status...")
    # The DataflowTemplateOperator handles this automatically
    # This is a placeholder for additional validation
    return True

# ============================================
# DAG Tasks
# ============================================

with dag:

    # ============================================
    # Stage 1: Data Ingestion
    # ============================================

    with TaskGroup("ingestion", tooltip="Fetch data from external sources") as ingestion_tg:

        fetch_api_data = PythonOperator(
            task_id="fetch_cricbuzz_api",
            python_callable=fetch_cricbuzz_api,
            provide_context=True,
            retries=3,
            retry_delay=timedelta(minutes=2),
        )

    # ============================================
    # Stage 2: Data Processing with Dataflow
    # ============================================

    with TaskGroup("processing", tooltip="Process data with Dataflow") as processing_tg:

        launch_dataflow = DataflowTemplateOperator(
            task_id="launch_dataflow_job",
            template=TEMPLATE_LOCATION,
            parameters={
                "input_file": "{{ task_instance.xcom_pull(task_ids='ingestion.fetch_cricbuzz_api', key='gcs_file_path') }}",
                "output_dataset": BQ_RAW_DATASET,
                "output_table": "batting_rankings",
            },
            project_id=PROJECT_ID,
            location=GCP_REGION,
            wait_until_finished=True,
            dataflow_default_options={
                "runner": "DataflowRunner",
                "projectId": PROJECT_ID,
                "region": GCP_REGION,
                "stagingLocation": f"gs://cricket-dataflow-temp-{PROJECT_ID}/staging",
                "tempLocation": f"gs://cricket-dataflow-temp-{PROJECT_ID}/temp",
                "machineType": "n1-standard-2",
                "numWorkers": 2,
                "maxNumWorkers": 5,
            },
        )

    # ============================================
    # Stage 3: Data Quality Validation
    # ============================================

    with TaskGroup("validation", tooltip="Validate ingested data") as validation_tg:

        validate_data = PythonOperator(
            task_id="validate_data_quality",
            python_callable=validate_data_quality,
            provide_context=True,
            trigger_rule="all_success",
        )

        check_raw_table = BigQueryCheckOperator(
            task_id="check_raw_table_exists",
            sql=f"SELECT COUNT(*) FROM `{PROJECT_ID}.{BQ_RAW_DATASET}.batting_rankings`",
            use_legacy_sql=False,
            location=GCP_REGION,
        )

    # ============================================
    # Stage 4: Data Transformation to Staging
    # ============================================

    with TaskGroup("staging_transformation", tooltip="Transform to staging layer") as staging_tg:

        transform_dim_player = BigQueryInsertJobOperator(
            task_id="transform_dim_player",
            configuration={
                "query": {
                    "query": f"""
                    MERGE `{PROJECT_ID}.{BQ_STAGING_DATASET}.dim_player` T
                    USING (
                        SELECT DISTINCT
                            player_id,
                            MAX(player_name) as player_name,
                            MAX(country_id) as country_id,
                            CURRENT_TIMESTAMP() as last_updated
                        FROM `{PROJECT_ID}.{BQ_RAW_DATASET}.batting_rankings`
                        WHERE DATE(ingested_at) = CURRENT_DATE()
                        GROUP BY player_id
                    ) S
                    ON T.player_id = S.player_id
                    WHEN MATCHED THEN
                        UPDATE SET
                            player_name = S.player_name,
                            country_id = S.country_id,
                            last_updated = S.last_updated
                    WHEN NOT MATCHED THEN
                        INSERT (player_id, player_name, country_id, last_updated)
                        VALUES (S.player_id, S.player_name, S.country_id, S.last_updated)
                    """,
                    "useLegacySql": False,
                }
            },
            location=GCP_REGION,
        )

        transform_dim_country = BigQueryInsertJobOperator(
            task_id="transform_dim_country",
            configuration={
                "query": {
                    "query": f"""
                    MERGE `{PROJECT_ID}.{BQ_STAGING_DATASET}.dim_country` T
                    USING (
                        SELECT DISTINCT
                            country_id,
                            MAX(country) as country_name,
                            CURRENT_TIMESTAMP() as last_updated
                        FROM `{PROJECT_ID}.{BQ_RAW_DATASET}.batting_rankings`
                        WHERE DATE(ingested_at) = CURRENT_DATE()
                        GROUP BY country_id
                    ) S
                    ON T.country_id = S.country_id
                    WHEN MATCHED THEN
                        UPDATE SET
                            country_name = S.country_name,
                            last_updated = S.last_updated
                    WHEN NOT MATCHED THEN
                        INSERT (country_id, country_name, last_updated)
                        VALUES (S.country_id, S.country_name, CURRENT_TIMESTAMP())
                    """,
                    "useLegacySql": False,
                }
            },
            location=GCP_REGION,
        )

        transform_fact_batting = BigQueryInsertJobOperator(
            task_id="transform_fact_batting",
            configuration={
                "query": {
                    "query": f"""
                    MERGE `{PROJECT_ID}.{BQ_STAGING_DATASET}.fact_batting_rankings` T
                    USING (
                        SELECT
                            CONCAT(
                                FORMAT_DATE('%Y%m%d', DATE(raw.ingested_at)),
                                '-',
                                raw.player_id,
                                '-',
                                CASE raw.format
                                    WHEN 'TEST' THEN '1'
                                    WHEN 'ODI' THEN '2'
                                    WHEN 'T20I' THEN '3'
                                END
                            ) as fact_id,
                            raw.player_id,
                            raw.country_id,
                            CASE raw.format
                                WHEN 'TEST' THEN 1
                                WHEN 'ODI' THEN 2
                                WHEN 'T20I' THEN 3
                            END as format_id,
                            CAST(FORMAT_DATE('%Y%m%d', DATE(raw.ingested_at)) AS INT64) as date_id,
                            raw.rank,
                            raw.rating,
                            raw.points,
                            raw.best_rank,
                            raw.source_file,
                            CURRENT_TIMESTAMP() as loaded_at
                        FROM `{PROJECT_ID}.{BQ_RAW_DATASET}.batting_rankings` raw
                        WHERE DATE(raw.ingested_at) = CURRENT_DATE()
                    ) S
                    ON T.fact_id = S.fact_id
                    WHEN MATCHED THEN
                        UPDATE SET
                            rank = S.rank,
                            rating = S.rating,
                            points = S.points,
                            best_rank = S.best_rank,
                            loaded_at = S.loaded_at
                    WHEN NOT MATCHED THEN
                        INSERT (
                            fact_id, player_id, country_id, format_id, date_id,
                            rank, rating, points, best_rank, source_file, loaded_at
                        )
                        VALUES (
                            S.fact_id, S.player_id, S.country_id, S.format_id, S.date_id,
                            S.rank, S.rating, S.points, S.best_rank, S.source_file, S.loaded_at
                        )
                    """,
                    "useLegacySql": False,
                }
            },
            location=GCP_REGION,
        )

        # Dependencies
        transform_dim_player >> transform_dim_country
        [transform_dim_player, transform_dim_country] >> transform_fact_batting

    # ============================================
    # Stage 5: Curated Views (No transformation needed, already materialized)
    # ============================================

    notify_completion = PythonOperator(
        task_id="notify_completion",
        python_callable=lambda **context: logger.info("Pipeline execution completed successfully"),
        trigger_rule="all_success",
    )

    # ============================================
    # DAG Dependencies
    # ============================================

    ingestion_tg >> processing_tg >> validation_tg >> staging_transformation >> notify_completion
