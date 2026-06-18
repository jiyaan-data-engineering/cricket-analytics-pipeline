#!/usr/bin/env python3
"""
Apache Beam Dataflow Pipeline: CSV to BigQuery
Reads batting rankings CSV from GCS and writes to BigQuery
"""

import argparse
import logging
import csv
from datetime import datetime
from typing import Dict, Any

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions, GoogleCloudOptions
from apache_beam.io import ReadFromText, WriteToBigQuery
from apache_beam.io.gcp.bigquery_tools import parse_table_schema_from_json


class ParseCsvLine(beam.DoFn):
    """Parse CSV line into BigQuery record"""

    def process(self, line: str):
        try:
            if not line or line.startswith('rank'):  # Skip header
                return

            # Parse CSV line
            fields = next(csv.reader([line]))
            if len(fields) < 10:
                return

            record = {
                'rank': int(fields[0]) if fields[0] else 0,
                'player_id': fields[1] or '',
                'player_name': fields[2] or '',
                'country': fields[3] or '',
                'country_id': int(fields[4]) if fields[4] else 0,
                'rating': float(fields[5]) if fields[5] else 0.0,
                'points': float(fields[6]) if fields[6] else 0.0,
                'best_rank': int(fields[7]) if fields[7] else 0,
                'format': fields[8].upper() if fields[8] else '',
                'ingested_at': fields[9] if fields[9] else datetime.utcnow().isoformat(),
            }

            yield record

        except Exception as e:
            logging.warning(f"Error parsing line: {line} - {str(e)}")


def run(argv=None):
    """Build and run the pipeline"""

    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--inputFile',
        dest='input_file',
        required=True,
        help='GCS path to input CSV file (e.g., gs://bucket/batting/*.csv)',
    )
    parser.add_argument(
        '--outputTable',
        dest='output_table',
        required=True,
        help='BigQuery table (e.g., project:dataset.table)',
    )
    parser.add_argument(
        '--tempLocation',
        dest='temp_location',
        required=True,
        help='GCS path for temporary files',
    )

    args, pipeline_args = parser.parse_known_args(argv)

    # BigQuery schema
    schema = {
        'fields': [
            {'name': 'rank', 'type': 'INTEGER', 'mode': 'NULLABLE'},
            {'name': 'player_id', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'player_name', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'country', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'country_id', 'type': 'INTEGER', 'mode': 'NULLABLE'},
            {'name': 'rating', 'type': 'FLOAT64', 'mode': 'NULLABLE'},
            {'name': 'points', 'type': 'FLOAT64', 'mode': 'NULLABLE'},
            {'name': 'best_rank', 'type': 'INTEGER', 'mode': 'NULLABLE'},
            {'name': 'format', 'type': 'STRING', 'mode': 'NULLABLE'},
            {'name': 'ingested_at', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'},
        ]
    }

    # Pipeline options
    pipeline_options = PipelineOptions(pipeline_args)
    google_cloud_options = pipeline_options.view_as(GoogleCloudOptions)
    google_cloud_options.temp_location = args.temp_location

    with beam.Pipeline(options=pipeline_options) as pipeline:
        (
            pipeline
            | 'Read CSV from GCS' >> ReadFromText(args.input_file, skip_header_lines=1)
            | 'Parse CSV' >> beam.ParDo(ParseCsvLine())
            | 'Write to BigQuery' >> WriteToBigQuery(
                table=args.output_table,
                schema=schema,
                create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
            )
        )


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()
