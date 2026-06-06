#!/usr/bin/env python3
"""
Apache Beam pipeline for processing cricket batting rankings CSV.
Reads from GCS, validates, transforms, and writes to BigQuery.
"""

import argparse
import logging
from typing import Dict, Any, List
import csv
from io import StringIO

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import WorkerOptions
from apache_beam.options.pipeline_options import StandardOptions
from apache_beam.io import ReadFromText, WriteToBigQuery
from apache_beam.transforms import ParDo
from apache_beam.transforms.core import Map
from apache_beam import pvalue
from google.cloud.bigquery.schema import SchemaField

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# BigQuery schema for raw batting rankings
RAW_SCHEMA = {
    "fields": [
        {"name": "rank", "type": "INTEGER", "mode": "NULLABLE"},
        {"name": "player_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "player_name", "type": "STRING", "mode": "NULLABLE"},
        {"name": "country", "type": "STRING", "mode": "NULLABLE"},
        {"name": "country_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "rating", "type": "FLOAT", "mode": "NULLABLE"},
        {"name": "points", "type": "FLOAT", "mode": "NULLABLE"},
        {"name": "best_rank", "type": "INTEGER", "mode": "NULLABLE"},
        {"name": "format", "type": "STRING", "mode": "NULLABLE"},
        {"name": "ingested_at", "type": "TIMESTAMP", "mode": "NULLABLE"},
        {"name": "source_file", "type": "STRING", "mode": "NULLABLE"},
    ]
}

class ParseCsvLine(beam.DoFn):
    """Parse CSV line into dictionary."""

    def process(self, line: str, source_file: str):
        try:
            if line.startswith("rank"):  # Skip header
                return

            reader = csv.reader(StringIO(line))
            row = next(reader)

            if len(row) < 10:
                logger.warning(f"Skipping malformed line: {line}")
                return

            record = {
                "rank": int(row[0]) if row[0] else None,
                "player_id": row[1] if row[1] else None,
                "player_name": row[2] if row[2] else None,
                "country": row[3] if row[3] else None,
                "country_id": row[4] if row[4] else None,
                "rating": float(row[5]) if row[5] else None,
                "points": float(row[6]) if row[6] else None,
                "best_rank": int(row[7]) if row[7] else None,
                "format": row[8] if row[8] else None,
                "ingested_at": row[9] if row[9] else None,
                "source_file": source_file,
            }
            yield record

        except ValueError as e:
            logger.warning(f"Validation error for line {line}: {e}")
        except Exception as e:
            logger.error(f"Unexpected error parsing line {line}: {e}")

def run(argv=None):
    """Main pipeline execution."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--input_file",
        required=True,
        help="Input CSV file path (gs://bucket/path/file.csv)"
    )
    parser.add_argument(
        "--output_dataset",
        required=True,
        help="BigQuery dataset name"
    )
    parser.add_argument(
        "--output_table",
        required=True,
        help="BigQuery table name"
    )
    parser.add_argument(
        "--runner",
        default="DataflowRunner",
        help="Beam runner: DirectRunner or DataflowRunner"
    )
    parser.add_argument(
        "--project",
        help="GCP project ID"
    )
    parser.add_argument(
        "--region",
        default="us-central1",
        help="GCP region for Dataflow"
    )
    parser.add_argument(
        "--temp_location",
        help="Temporary location for Dataflow staging"
    )

    known_args, pipeline_args = parser.parse_known_args(argv)

    # Pipeline options
    options = PipelineOptions(pipeline_args)
    options.view_as(StandardOptions).runner = known_args.runner

    if known_args.runner == "DataflowRunner":
        options.view_as(WorkerOptions).machine_type = "n1-standard-2"
        options.view_as(WorkerOptions).num_workers = 2
        options.view_as(WorkerOptions).max_num_workers = 5

    # Extract source file name from path
    source_file = known_args.input_file.split("/")[-1]

    with beam.Pipeline(options=options) as p:
        logger.info(f"Starting pipeline with input: {known_args.input_file}")

        # Read CSV from GCS
        lines = (
            p
            | "Read CSV" >> ReadFromText(known_args.input_file)
            | "Parse CSV" >> ParDo(ParseCsvLine(), source_file)
        )

        # Write to BigQuery
        table_spec = f"{known_args.output_dataset}.{known_args.output_table}"
        lines | "Write to BigQuery" >> WriteToBigQuery(
            table=table_spec,
            schema=RAW_SCHEMA,
            write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
        )

        logger.info("Pipeline execution complete")

if __name__ == "__main__":
    import sys
    run(sys.argv[1:])
