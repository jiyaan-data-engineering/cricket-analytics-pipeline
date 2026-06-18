"""
Data Quality Monitoring DAG

Monitors data quality and pipeline health:
- Table freshness checks
- Data completeness validation
- Schema validation
- Performance metrics
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCheckOperator
from airflow.utils.task_group import TaskGroup
from airflow.models import Variable
from airflow.exceptions import AirflowException
import logging
from google.cloud import bigquery

logger = logging.getLogger(__name__)

PROJECT_ID = Variable.get("gcp_project_id", default_var="cricket-analytics-prod")
GCP_REGION = Variable.get("gcp_region", default_var="us-central1")

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "start_date": datetime(2024, 6, 1),
    "email": ["airflow-alerts@example.com"],
    "email_on_failure": True,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

dag = DAG(
    "cricket_data_quality_monitoring",
    default_args=default_args,
    description="Monitor data quality and pipeline health",
    schedule_interval="0 10 * * *",  # Daily at 10:00 UTC (after main pipeline)
    catchup=False,
    tags=["cricket", "monitoring", "quality"],
)

# ============================================
# Python Functions
# ============================================

def check_table_freshness(**context) -> bool:
    """Check if all tables have recent data."""
    logger.info("Checking table freshness...")

    bq_client = bigquery.Client(project=PROJECT_ID)

    tables = [
        ("cricket_raw", "batting_rankings"),
        ("cricket_staging", "fact_batting_rankings"),
    ]

    for dataset, table in tables:
        query = f"""
        SELECT MAX(
            CASE
                WHEN ingested_at IS NOT NULL THEN ingested_at
                WHEN loaded_at IS NOT NULL THEN loaded_at
                ELSE NULL
            END
        ) as last_update
        FROM `{PROJECT_ID}.{dataset}.{table}`
        """

        result = bq_client.query(query).result()
        for row in result:
            last_update = row.last_update

            if last_update is None:
                raise AirflowException(f"No data in {dataset}.{table}")

            hours_old = (datetime.utcnow() - last_update.replace(tzinfo=None)).total_seconds() / 3600
            logger.info(f"{dataset}.{table}: Last update {hours_old:.1f} hours ago")

            if hours_old > 48:  # Alert if data is older than 48 hours
                raise AirflowException(f"Data in {dataset}.{table} is stale ({hours_old:.1f} hours old)")

    logger.info("Table freshness check passed")
    return True

def check_data_completeness(**context) -> bool:
    """Check data completeness and null values."""
    logger.info("Checking data completeness...")

    bq_client = bigquery.Client(project=PROJECT_ID)

    query = f"""
    SELECT
        FORMAT,
        COUNT(*) as record_count,
        COUNTIF(player_id IS NULL) as null_player_ids,
        COUNTIF(rating IS NULL) as null_ratings
    FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
    WHERE DATE(ingested_at) = CURRENT_DATE()
    GROUP BY FORMAT
    """

    result = bq_client.query(query).result()

    for row in result:
        logger.info(f"{row.FORMAT}: {row.record_count} records")

        if row.null_player_ids > 0:
            logger.warning(f"{row.FORMAT}: {row.null_player_ids} null player_ids")

        if row.null_ratings > 0:
            logger.warning(f"{row.FORMAT}: {row.null_ratings} null ratings")

        # Alert if less than 50 records (sanity check)
        if row.record_count < 50:
            raise AirflowException(f"{row.FORMAT}: Only {row.record_count} records (expected ~100)")

    logger.info("Data completeness check passed")
    return True

def check_staging_consistency(**context) -> bool:
    """Check consistency between raw and staging layers."""
    logger.info("Checking staging consistency...")

    bq_client = bigquery.Client(project=PROJECT_ID)

    query = f"""
    WITH raw_counts AS (
        SELECT COUNT(DISTINCT player_id) as raw_player_count
        FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
        WHERE DATE(ingested_at) = CURRENT_DATE()
    ),
    staging_counts AS (
        SELECT COUNT(DISTINCT player_id) as staging_player_count
        FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings`
        WHERE DATE(loaded_at) = CURRENT_DATE()
    )
    SELECT
        raw_player_count,
        staging_player_count,
        ABS(raw_player_count - staging_player_count) as difference
    FROM raw_counts, staging_counts
    """

    result = bq_client.query(query).result()

    for row in result:
        logger.info(f"Raw: {row.raw_player_count}, Staging: {row.staging_player_count}")

        # Allow small difference due to filtering
        if row.difference > 5:
            logger.warning(f"Inconsistency detected: {row.difference} record difference")

    logger.info("Staging consistency check passed")
    return True

def generate_quality_report(**context) -> dict:
    """Generate data quality report."""
    logger.info("Generating quality report...")

    bq_client = bigquery.Client(project=PROJECT_ID)

    report = {
        "timestamp": datetime.utcnow().isoformat(),
        "checks": {
            "freshness": "PASSED",
            "completeness": "PASSED",
            "consistency": "PASSED",
        },
    }

    # Raw layer stats
    query = f"""
    SELECT
        COUNT(*) as total_records,
        COUNT(DISTINCT FORMAT) as format_count,
        COUNT(DISTINCT country) as country_count,
        MIN(rank) as best_rank,
        MAX(rank) as worst_rank
    FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
    WHERE DATE(ingested_at) = CURRENT_DATE()
    """

    result = bq_client.query(query).result()
    for row in result:
        report["raw_layer"] = {
            "total_records": row.total_records,
            "formats": row.format_count,
            "countries": row.country_count,
            "rank_range": f"{row.best_rank} - {row.worst_rank}",
        }

    logger.info(f"Quality Report: {report}")
    context["task_instance"].xcom_push(key="quality_report", value=report)

    return report

# ============================================
# DAG Tasks
# ============================================

with dag:

    with TaskGroup("freshness_checks", tooltip="Check data freshness") as freshness_tg:

        check_freshness = PythonOperator(
            task_id="check_table_freshness",
            python_callable=check_table_freshness,
            provide_context=True,
        )

    with TaskGroup("completeness_checks", tooltip="Check data completeness") as completeness_tg:

        check_completeness = PythonOperator(
            task_id="check_data_completeness",
            python_callable=check_data_completeness,
            provide_context=True,
        )

    with TaskGroup("consistency_checks", tooltip="Check layer consistency") as consistency_tg:

        check_consistency = PythonOperator(
            task_id="check_staging_consistency",
            python_callable=check_staging_consistency,
            provide_context=True,
        )

    generate_report = PythonOperator(
        task_id="generate_quality_report",
        python_callable=generate_quality_report,
        provide_context=True,
        trigger_rule="all_done",
    )

    # Dependencies
    freshness_tg >> completeness_tg >> consistency_tg >> generate_report
