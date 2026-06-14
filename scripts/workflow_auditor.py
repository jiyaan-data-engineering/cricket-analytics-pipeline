#!/usr/bin/env python3
"""
Workflow Auditor - Logs all pipeline stages to BigQuery audit tables
Captures: stage name, status, start/end time, records, errors, duration
"""

import os
import sys
import json
import uuid
from datetime import datetime
from typing import Optional, Dict, Any
from google.cloud import bigquery

class WorkflowAuditor:
    """Log workflow execution to audit tables"""

    def __init__(self, project_id: str):
        self.project_id = project_id
        self.bq_client = bigquery.Client(project=project_id)
        self.audit_dataset = f"{project_id}.cricket_audit_logs"
        self.execution_run_id = str(uuid.uuid4())
        self.execution_date = datetime.utcnow()

    def log_api_ingestion(
        self,
        status: str,
        total_records: int = 0,
        gcs_path: str = None,
        start_time: str = None,
        end_time: str = None,
        error_message: str = None,
    ):
        """Log API ingestion stage"""
        print(f"📝 Logging API Ingestion: {status}")

        query = f"""
        INSERT INTO `{self.audit_dataset}.api_ingestion_audit_log`
        (run_id, pipeline_stage, execution_date, status,
         total_records_fetched, gcs_output_path,
         execution_start_time, execution_end_time, error_message, created_timestamp)
        VALUES
        ('{self.execution_run_id}', 'api_ingestion', CURRENT_TIMESTAMP(), '{status}',
         {total_records}, '{gcs_path}',
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{start_time}'),
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{end_time}'),
         '{error_message}', CURRENT_TIMESTAMP())
        """

        try:
            self.bq_client.query(query).result()
            print(f"✅ API Ingestion logged")
            return True
        except Exception as e:
            print(f"⚠️  API Ingestion logging failed: {e}")
            return False

    def log_dataflow(
        self,
        status: str,
        job_id: str = None,
        input_records: int = 0,
        output_records: int = 0,
        start_time: str = None,
        end_time: str = None,
        error_message: str = None,
    ):
        """Log Dataflow processing stage"""
        print(f"📝 Logging Dataflow: {status}")

        query = f"""
        INSERT INTO `{self.audit_dataset}.dataflow_processing_audit_log`
        (run_id, pipeline_stage, execution_date, status,
         dataflow_job_id, input_record_count, output_record_count,
         execution_start_time, execution_end_time, error_message, created_timestamp)
        VALUES
        ('{self.execution_run_id}', 'dataflow_processing', CURRENT_TIMESTAMP(), '{status}',
         '{job_id}', {input_records}, {output_records},
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{start_time}'),
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{end_time}'),
         '{error_message}', CURRENT_TIMESTAMP())
        """

        try:
            self.bq_client.query(query).result()
            print(f"✅ Dataflow logged")
            return True
        except Exception as e:
            print(f"⚠️  Dataflow logging failed: {e}")
            return False

    def log_transformation(
        self,
        status: str,
        transform_name: str,
        source_records: int = 0,
        inserted_records: int = 0,
        updated_records: int = 0,
        start_time: str = None,
        end_time: str = None,
        error_message: str = None,
    ):
        """Log data transformation stage (RAW → STAGING)"""
        print(f"📝 Logging Transformation ({transform_name}): {status}")

        query = f"""
        INSERT INTO `{self.audit_dataset}.data_transformation_audit_log`
        (run_id, pipeline_stage, execution_date, status,
         transformation_name, source_record_count, inserted_record_count, updated_record_count,
         execution_start_time, execution_end_time, error_message, created_timestamp)
        VALUES
        ('{self.execution_run_id}', 'data_transformation', CURRENT_TIMESTAMP(), '{status}',
         '{transform_name}', {source_records}, {inserted_records}, {updated_records},
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{start_time}'),
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{end_time}'),
         '{error_message}', CURRENT_TIMESTAMP())
        """

        try:
            self.bq_client.query(query).result()
            print(f"✅ Transformation logged")
            return True
        except Exception as e:
            print(f"⚠️  Transformation logging failed: {e}")
            return False

    def log_curated_views(
        self,
        status: str,
        view_name: str,
        row_count: int = 0,
        start_time: str = None,
        end_time: str = None,
        error_message: str = None,
    ):
        """Log curated views creation"""
        print(f"📝 Logging Curated View ({view_name}): {status}")

        query = f"""
        INSERT INTO `{self.audit_dataset}.analytics_views_audit_log`
        (run_id, pipeline_stage, execution_date, status,
         view_name, view_row_count,
         execution_start_time, execution_end_time, error_message, created_timestamp)
        VALUES
        ('{self.execution_run_id}', 'analytics_views', CURRENT_TIMESTAMP(), '{status}',
         '{view_name}', {row_count},
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{start_time}'),
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{end_time}'),
         '{error_message}', CURRENT_TIMESTAMP())
        """

        try:
            self.bq_client.query(query).result()
            print(f"✅ Curated View logged")
            return True
        except Exception as e:
            print(f"⚠️  Curated View logging failed: {e}")
            return False

    def log_master(
        self,
        pipeline_stage_number: int,
        pipeline_stage_name: str,
        status: str,
        total_records: int = 0,
        total_errors: int = 0,
        start_time: str = None,
        end_time: str = None,
        error_summary: str = None,
    ):
        """Log to master execution summary"""
        print(f"📝 Logging Master Summary - Stage {pipeline_stage_number}: {status}")

        success_rate = 100.0 if total_errors == 0 else ((total_records - total_errors) / max(total_records, 1)) * 100

        query = f"""
        INSERT INTO `{self.audit_dataset}.pipeline_execution_summary`
        (execution_run_id, pipeline_stage_number, pipeline_stage_name, execution_date, status,
         total_records_processed, total_records_with_errors, overall_success_rate,
         execution_start_time, execution_end_time, error_summary_message, created_timestamp)
        VALUES
        ('{self.execution_run_id}', {pipeline_stage_number}, '{pipeline_stage_name}', CURRENT_TIMESTAMP(), '{status}',
         {total_records}, {total_errors}, {success_rate},
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{start_time}'),
         PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%SZ', '{end_time}'),
         '{error_summary}', CURRENT_TIMESTAMP())
        """

        try:
            self.bq_client.query(query).result()
            print(f"✅ Master log entry created")
            return True
        except Exception as e:
            print(f"⚠️  Master log failed: {e}")
            return False

    def get_execution_run_id(self) -> str:
        """Get the unique execution run ID for this pipeline run"""
        return self.execution_run_id


if __name__ == "__main__":
    # Example usage from command line
    project_id = os.getenv("GCP_PROJECT_ID", "cricbuzz-satish-dev")
    auditor = WorkflowAuditor(project_id)

    # Log example API ingestion
    auditor.log_api_ingestion(
        status="SUCCESS",
        total_records=135,
        gcs_path="gs://cricket-raw-bucket/batting_rankings_2026-06-14.csv",
        start_time="2026-06-14T06:00:00Z",
        end_time="2026-06-14T06:05:00Z"
    )

    # Log master summary
    auditor.log_master(
        pipeline_stage_number=1,
        pipeline_stage_name="api_ingestion",
        status="SUCCESS",
        total_records=135,
        total_errors=0,
        start_time="2026-06-14T06:00:00Z",
        end_time="2026-06-14T06:05:00Z"
    )

    print(f"\n✅ Execution Run ID: {auditor.get_execution_run_id()}")
