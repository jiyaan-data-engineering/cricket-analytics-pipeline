# 🔄 Apache Beam / Dataflow: ETL Pipeline Guide

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete Dataflow Setup

Complete guide for Dataflow pipeline configuration and deployment.

---

## 📋 Quick Navigation
- [Overview](#overview)
- [Pipeline Architecture](#architecture)
- [Code Structure](#code-structure)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

---

## 📊 Overview

| Component | Details | Status |
|-----------|---------|--------|
| **Framework** | Apache Beam (Python SDK) | ✅ |
| **Runner** | Google Cloud Dataflow | ✅ |
| **Template** | Flex Template (Docker) | ✅ |
| **Machine Type** | n1-standard-2 | ✅ |
| **Workers** | 2-5 (auto-scaling) | ✅ |
| **Language** | Python 3.11 | ✅ |
| **Input** | CSV from GCS | ✅ |
| **Output** | BigQuery RAW table | ✅ |

---

## 🏗️ Pipeline Architecture

```
GCS CSV Input
    ↓
ReadFromText (Distributed file read)
    ↓
ParDo(ParseCsvLine) - Distributed transformation
    ├─ Skip header
    ├─ Parse CSV row
    ├─ Type validation
    ├─ Error handling
    └─ Yield record
    ↓
WriteToBigQuery - Distributed write
    ├─ Table: cricket_raw.batting_rankings
    ├─ Schema: 11 columns
    ├─ Mode: WRITE_APPEND
    └─ Auto-create if needed
    ↓
BigQuery Table
```

---

## 💻 Code Structure

### File: dataflow/pipeline.py

**Imports**:
```python
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.io import ReadFromText, WriteToBigQuery
from apache_beam.transforms import ParDo
```

**Schema Definition**:
```python
RAW_SCHEMA = {
    "fields": [
        {"name": "rank", "type": "INTEGER", "mode": "NULLABLE"},
        {"name": "player_id", "type": "STRING", "mode": "NULLABLE"},
        # ... 9 more fields
    ]
}
```

**ParseCsvLine Transform**:
```python
class ParseCsvLine(beam.DoFn):
    """Parse CSV line into dictionary"""
    
    def process(self, line: str, source_file: str):
        try:
            # Skip header
            if line.startswith("rank"):
                return
            
            # Parse CSV
            reader = csv.reader(StringIO(line))
            row = next(reader)
            
            # Validate columns
            if len(row) < 10:
                logger.warning(f"Skipping line: {len(row)} columns")
                return
            
            # Build record with type casting
            record = {
                "rank": int(row[0]) if row[0] else None,
                "player_id": row[1] if row[1] else None,
                # ... map all 11 fields
                "source_file": source_file,
            }
            
            yield record
        
        except ValueError as e:
            logger.warning(f"Type error: {e}")
        except Exception as e:
            logger.error(f"Parse error: {e}")
```

**Main Pipeline**:
```python
def run(argv=None):
    """Main Dataflow pipeline"""
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_file", required=True)
    parser.add_argument("--output_dataset", required=True)
    parser.add_argument("--output_table", required=True)
    
    known_args, pipeline_args = parser.parse_known_args(argv)
    
    # Pipeline options
    options = PipelineOptions(pipeline_args)
    options.view_as(StandardOptions).runner = "DataflowRunner"
    options.view_as(WorkerOptions).machine_type = "n1-standard-2"
    options.view_as(WorkerOptions).num_workers = 2
    options.view_as(WorkerOptions).max_num_workers = 5
    
    # Pipeline execution
    with beam.Pipeline(options=options) as p:
        lines = (
            p
            | "Read CSV" >> ReadFromText(known_args.input_file)
            | "Parse CSV" >> ParDo(ParseCsvLine(), known_args.input_file.split("/")[-1])
        )
        
        table_spec = f"{known_args.output_dataset}.{known_args.output_table}"
        lines | "Write to BigQuery" >> WriteToBigQuery(
            table=table_spec,
            schema=RAW_SCHEMA,
            write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
        )
```

---

## 🐳 Flex Template

### File: dataflow/Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy pipeline code
COPY pipeline.py .

# Set entrypoint
ENTRYPOINT ["python", "-m", "apache_beam.runners.dataflow.main"]
```

### File: dataflow/requirements.txt

```
apache-beam[gcp]==2.52.0
google-cloud-dataflow>=0.8.0
google-cloud-bigquery>=3.10.0
pandas
pyyaml
```

---

## 🚀 Deployment

### Step 1: Build Docker Image

```bash
cd dataflow

# Build image
docker build -t cricket-pipeline:latest .

# Tag for Artifact Registry
docker tag cricket-pipeline:latest \
  us-central1-docker.pkg.dev/PROJECT_ID/cricket-docker/batting-pipeline:latest

# Configure auth
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push to registry
docker push us-central1-docker.pkg.dev/PROJECT_ID/cricket-docker/batting-pipeline:latest
```

### Step 2: Build Flex Template

```bash
gcloud dataflow flex-template build \
  gs://cricket-dataflow-templates/batting-pipeline/metadata \
  --image=us-central1-docker.pkg.dev/PROJECT_ID/cricket-docker/batting-pipeline:latest \
  --sdk-language=PYTHON
```

### Step 3: Launch Dataflow Job

```bash
gcloud dataflow flex-template run "batting-pipeline-$(date +%Y%m%d_%H%M%S)" \
  --template-file-gcs-location="gs://cricket-dataflow-templates/batting-pipeline/metadata" \
  --region="us-central1" \
  --parameters=input_file="gs://cricket-raw-data/batting/batting_rankings_*.csv" \
  --parameters=output_dataset="cricket_raw" \
  --parameters=output_table="batting_rankings" \
  --service-account-email="cricket-dataflow-sa@PROJECT_ID.iam.gserviceaccount.com"
```

---

## 📊 Monitoring

### Via CLI

```bash
# List jobs
gcloud dataflow jobs list --region us-central1

# Show job details
gcloud dataflow jobs show JOB_ID --region us-central1

# View job metrics
gcloud dataflow jobs describe JOB_ID --region us-central1 --format=json

# View logs
gcloud logging read "resource.type=dataflow_step AND labels.job_id=JOB_ID" \
  --limit 50 --format json
```

### Via Cloud Logging

```
Filter:
resource.type="dataflow_step"
resource.labels.job_id="YOUR_JOB_ID"

Shows:
- Step execution time
- Record count
- Error messages
- Worker logs
```

### Key Metrics

- **Throughput**: Records/sec (should be > 1000)
- **Latency**: Job duration (should be < 10 min)
- **Error Rate**: Failed records (should be < 1%)
- **Worker Count**: Auto-scales based on load
- **CPU Usage**: Should be 40-60%

---

## 🔧 Common Operations

### Drain (Graceful Stop)

```bash
gcloud dataflow jobs drain JOB_ID --region us-central1
```

### Cancel

```bash
gcloud dataflow jobs cancel JOB_ID --region us-central1
```

### Update Pipeline Code

```bash
# Modify pipeline.py
# Rebuild Docker image
docker build -t cricket-pipeline:v2 .
docker push us-central1-docker.pkg.dev/PROJECT_ID/cricket-docker/batting-pipeline:v2

# Rebuild Flex Template
gcloud dataflow flex-template build \
  gs://cricket-dataflow-templates/batting-pipeline/metadata-v2 \
  --image=us-central1-docker.pkg.dev/PROJECT_ID/cricket-docker/batting-pipeline:v2 \
  --sdk-language=PYTHON
```

---

## ❌ Troubleshooting

### Issue: "Permission denied"

```
Error: Permission denied while getting IAM policy

Solution:
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member=serviceAccount:cricket-dataflow-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/bigquery.admin
```

### Issue: "Table not found"

```
Error: BigQuery table not found

Solution:
- Verify dataset exists: bq ls cricket_raw
- Verify table created: bq show cricket_raw.batting_rankings
- Check spelling in output_dataset/output_table parameters
```

### Issue: "CSV parsing fails"

```
Error: Skipping malformed line

Solution:
- Check CSV format in GCS
- Verify header row
- Check column count
- Check for special characters
```

### Issue: "Slow job"

```
Low throughput

Solution:
- Increase max_num_workers: 5 → 10
- Check file size
- Check CPU usage
- Monitor for disk I/O bottleneck
```

---

## 📈 Performance Tips

1. **Batch Size**: Use default (1000 rows)
2. **Worker Count**: Let autoscaling handle it
3. **Machine Type**: n1-standard-2 is balanced
4. **Input Format**: CSV is fine, consider Parquet for huge files
5. **Network**: Use same region as GCS bucket

---

## ✅ Checklist

- [ ] Dockerfile created & tested locally
- [ ] requirements.txt includes all dependencies
- [ ] Docker image pushed to Artifact Registry
- [ ] Flex Template metadata built
- [ ] Service account has BigQuery Admin role
- [ ] GCS bucket accessible
- [ ] Output dataset exists
- [ ] Test job runs successfully
- [ ] Monitoring/logging configured

---

**Status**: ✅ Production Dataflow Pipeline  
**Template**: Flex Template (Docker)  
**Language**: Python 3.11  
**Last Updated**: 2026-06-07  

Fast, scalable ETL! 🔄
