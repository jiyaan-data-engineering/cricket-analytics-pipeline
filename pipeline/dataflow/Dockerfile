FROM python:3.11-slim

RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*

WORKDIR /pipeline
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY beam_pipeline.py .

ENTRYPOINT ["python", "-m", "apache_beam.runners.dataflow.main"]
