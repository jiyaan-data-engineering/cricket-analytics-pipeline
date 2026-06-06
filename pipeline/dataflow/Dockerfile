# Dockerfile for Apache Beam Flex Template (Cricket Batting Rankings Pipeline)

FROM python:3.11-slim

WORKDIR /pipeline

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy pipeline code
COPY pipeline.py .

# Set entrypoint for Dataflow Flex Template
ENTRYPOINT ["python", "-m", "apache_beam.runners.dataflow.runner", \
            "--runner=DataflowRunner", \
            "--project=${GCLOUD_PROJECT}", \
            "--region=${GCLOUD_REGION}", \
            "--temp_location=${DATAFLOW_TEMP_LOCATION}", \
            "--requirements_file=requirements.txt"]
