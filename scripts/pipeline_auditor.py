#!/usr/bin/env python3
"""
Pipeline Auditor - Log tracking for all 4 pipelines
Records execution metrics, errors, and data quality metrics
"""

import uuid
from datetime import datetime
from typing import Dict, List, Optional
from google.cloud import bigquery
import logging

logger = logging.getLogger(__name__)


class PipelineAuditor:
    """Central auditing for all pipelines"""

    def __init__(self, project_id: str):
        self.project_id = project_id
        self.bq_client = bigquery.Client(project=project_id)
        self.audit_dataset = f"{project_id}.cricket_audit_logs"

    # =========================================================================
    # PIPELINE 1: API INGESTION LOGS
    # =========================================================================

    def log_api_ingestion(
        self,
        status: str,
        total_records: int,
        test_records: int = 0,
        odi_records: int = 0,
        t20i_records: int = 0,
        gcs_file_path: str = None,
        file_size_bytes: int = None,
        start_time: datetime = None,
        end_time: datetime = None,
        error_message: str = None,
        retry_count: int = 0,
    ):
        """Log API ingestion pipeline execution"""
        pipeline_run_id = str(uuid.uuid4())

        duration = None
        if start_time and end_time:
            duration = int((end_time - start_time).total_seconds())

        query = f"""
        INSERT INTO `{self.audit_dataset}.pipeline_1_api_ingestion`
        (pipeline_run_id, pipeline_name, execution_date, status,
         total_records_fetched, test_format_records, odi_format_records, t20i_format_records,
         gcs_file_path, file_size_bytes, start_time, end_time, duration_seconds,
         error_message, retry_count)
        VALUES
        ('{pipeline_run_id}', 'API Ingestion', CURRENT_TIMESTAMP(), '{status}',
         {total_records}, {test_records}, {odi_records}, {t20i_records},
         '{gcs_file_path}', {file_size_bytes}, TIMESTAMP('{start_time}'),
         TIMESTAMP('{end_time}'), {duration}, '{error_message}', {retry_count})
        """

        try:
            self.bq_client.query(query).result()
            logger.info(f"✅ API Ingestion logged: {pipeline_run_id}")
            return pipeline_run_id
        except Exception as e:
            logger.error(f"❌ Failed to log API ingestion: {e}")
            return None

    # =========================================================================
    # PIPELINE 2: DATAFLOW LOGS
    # =========================================================================

    def log_dataflow(
        self,
        dataflow_job_id: str,
        dataflow_job_name: str,
        status: str,
        input_records: int,
        output_records: int,
        error_records: int = 0,
        worker_nodes: int = 2,
        machine_type: str = "n1-standard-2",
        start_time: datetime = None,
        end_time: datetime = None,
        error_message: str = None,
    ):
        """Log Dataflow (Apache Beam) pipeline execution"""
        pipeline_run_id = str(uuid.uuid4())

        duration = None
        if start_time and end_time:
            duration = int((end_time - start_time).total_seconds())

        query = f"""
        INSERT INTO `{self.audit_dataset}.pipeline_2_dataflow`
        (pipeline_run_id, pipeline_name, execution_date, status,
         dataflow_job_id, dataflow_job_name, output_table, output_dataset,
         input_records, output_records, error_records, worker_nodes, machine_type,
         start_time, end_time, duration_seconds, error_message)
        VALUES
        ('{pipeline_run_id}', 'Dataflow Processing', CURRENT_TIMESTAMP(), '{status}',
         '{dataflow_job_id}', '{dataflow_job_name}', 'batting_rankings', 'cricket_raw',
         {input_records}, {output_records}, {error_records}, {worker_nodes}, '{machine_type}',
         TIMESTAMP('{start_time}'), TIMESTAMP('{end_time}'), {duration}, '{error_message}')
        """

        try:
            self.bq_client.query(query).result()
            logger.info(f"✅ Dataflow logged: {pipeline_run_id}")
            return pipeline_run_id
        except Exception as e:
            logger.error(f"❌ Failed to log Dataflow: {e}")
            return None

    # =========================================================================
    # PIPELINE 3: STAGING TRANSFORMATION LOGS
    # =========================================================================

    def log_staging_transform(
        self,
        transform_name: str,
        status: str,
        source_records: int,
        inserted_records: int = 0,
        updated_records: int = 0,
        deleted_records: int = 0,
        constraint_violations: int = 0,
        start_time: datetime = None,
        end_time: datetime = None,
        error_message: str = None,
    ):
        """Log staging transformation pipeline execution"""
        pipeline_run_id = str(uuid.uuid4())

        duration = None
        if start_time and end_time:
            duration = int((end_time - start_time).total_seconds())

        total_affected = inserted_records + updated_records + deleted_records

        query = f"""
        INSERT INTO `{self.audit_dataset}.pipeline_3_staging_transform`
        (pipeline_run_id, pipeline_name, execution_date, status,
         transform_name, source_table, target_table,
         source_records, inserted_records, updated_records, deleted_records,
         total_affected_records, constraint_violations, start_time, end_time,
         duration_seconds, error_message)
        VALUES
        ('{pipeline_run_id}', 'Staging Transformation', CURRENT_TIMESTAMP(), '{status}',
         '{transform_name}', 'cricket_raw', 'cricket_staging',
         {source_records}, {inserted_records}, {updated_records}, {deleted_records},
         {total_affected}, {constraint_violations}, TIMESTAMP('{start_time}'),
         TIMESTAMP('{end_time}'), {duration}, '{error_message}')
        """

        try:
            self.bq_client.query(query).result()
            logger.info(f"✅ Staging Transform logged: {pipeline_run_id}")
            return pipeline_run_id
        except Exception as e:
            logger.error(f"❌ Failed to log staging transform: {e}")
            return None

    # =========================================================================
    # PIPELINE 4: CURATED VIEWS LOGS
    # =========================================================================

    def log_curated_view(
        self,
        view_name: str,
        status: str,
        view_row_count: int,
        unique_players: int = 0,
        unique_countries: int = 0,
        query_execution_time_ms: int = 0,
        bytes_billed: int = 0,
        start_time: datetime = None,
        end_time: datetime = None,
        error_message: str = None,
    ):
        """Log curated views pipeline execution"""
        pipeline_run_id = str(uuid.uuid4())

        duration = None
        if start_time and end_time:
            duration = int((end_time - start_time).total_seconds())

        query = f"""
        INSERT INTO `{self.audit_dataset}.pipeline_4_curated_views`
        (pipeline_run_id, pipeline_name, execution_date, status,
         view_name, view_row_count, unique_players, unique_countries,
         query_execution_time_ms, bytes_billed, start_time, end_time,
         duration_seconds, error_message)
        VALUES
        ('{pipeline_run_id}', 'Curated Views', CURRENT_TIMESTAMP(), '{status}',
         '{view_name}', {view_row_count}, {unique_players}, {unique_countries},
         {query_execution_time_ms}, {bytes_billed}, TIMESTAMP('{start_time}'),
         TIMESTAMP('{end_time}'), {duration}, '{error_message}')
        """

        try:
            self.bq_client.query(query).result()
            logger.info(f"✅ Curated View logged: {pipeline_run_id}")
            return pipeline_run_id
        except Exception as e:
            logger.error(f"❌ Failed to log curated view: {e}")
            return None

    # =========================================================================
    # MASTER LOG
    # =========================================================================

    def log_master(
        self,
        pipeline_stage: int,
        pipeline_name: str,
        status: str,
        total_records: int,
        total_errors: int = 0,
        start_time: datetime = None,
        end_time: datetime = None,
        error_summary: str = None,
    ):
        """Log to master audit log for all pipelines"""
        pipeline_run_id = str(uuid.uuid4())

        duration = None
        success_rate = 100 if total_errors == 0 else (total_records - total_errors) / total_records * 100
        if start_time and end_time:
            duration = int((end_time - start_time).total_seconds())

        query = f"""
        INSERT INTO `{self.audit_dataset}.pipeline_master_log`
        (pipeline_run_id, pipeline_stage, pipeline_name, execution_date, status,
         total_records_processed, total_errors, success_rate, start_time, end_time,
         total_duration_seconds, error_summary)
        VALUES
        ('{pipeline_run_id}', {pipeline_stage}, '{pipeline_name}', CURRENT_TIMESTAMP(), '{status}',
         {total_records}, {total_errors}, {success_rate}, TIMESTAMP('{start_time}'),
         TIMESTAMP('{end_time}'), {duration}, '{error_summary}')
        """

        try:
            self.bq_client.query(query).result()
            logger.info(f"✅ Master log entry: {pipeline_run_id}")
            return pipeline_run_id
        except Exception as e:
            logger.error(f"❌ Failed to log to master log: {e}")
            return None

    # =========================================================================
    # REPORTING
    # =========================================================================

    def get_pipeline_stats(self, days: int = 7) -> Dict:
        """Get statistics for all pipelines (last N days)"""
        query = f"""
        SELECT
          pipeline_name,
          DATE(execution_date) as date,
          COUNT(*) as total_runs,
          COUNTIF(status = 'SUCCESS') as successful_runs,
          COUNTIF(status = 'FAILED') as failed_runs,
          ROUND(COUNTIF(status = 'SUCCESS') / COUNT(*) * 100, 2) as success_rate_percent,
          AVG(total_duration_seconds) as avg_duration_seconds
        FROM `{self.audit_dataset}.pipeline_master_log`
        WHERE DATE(execution_date) >= DATE_SUB(CURRENT_DATE(), INTERVAL {days} DAY)
        GROUP BY pipeline_name, date
        ORDER BY date DESC
        """

        try:
            results = self.bq_client.query(query).result()
            return [dict(row) for row in results]
        except Exception as e:
            logger.error(f"❌ Failed to get pipeline stats: {e}")
            return []


if __name__ == "__main__":
    # Example usage
    auditor = PipelineAuditor("your-project-id")

    # Log API ingestion
    auditor.log_api_ingestion(
        status="SUCCESS",
        total_records=135,
        test_records=45,
        odi_records=45,
        t20i_records=45,
        gcs_file_path="gs://bucket/batting_rankings_20240614.csv",
        file_size_bytes=5240,
        retry_count=0,
    )

    # Get stats
    stats = auditor.get_pipeline_stats(days=7)
    for stat in stats:
        print(f"✅ {stat['pipeline_name']}: {stat['success_rate_percent']}% success")
