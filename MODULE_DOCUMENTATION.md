# Cricket Analytics Pipeline — Module Documentation

**Version**: 1.0  
**Last Updated**: 2026-06-06  
**Purpose**: Comprehensive reference for all pipeline components, functions, and data flows

---

## Table of Contents

1. [Configuration Module](#1-configuration-module)
2. [Ingestion Module](#2-ingestion-module)
3. [Cloud Function Module](#3-cloud-function-module)
4. [Dataflow Module](#4-dataflow-module)
5. [BigQuery Module](#5-bigquery-module)
6. [Airflow DAG Module](#6-airflow-dag-module)
7. [Terraform Module](#7-terraform-module)

---

## 1. Configuration Module

**File**: `config/config.yaml`

### Purpose
Central configuration file used by all Python components. Eliminates hardcoding and enables environment-specific overrides.

### Structure

```yaml
gcp:
  project_id: "cricket-analytics-project"
  region: "us-central1"

gcs:
  raw_bucket: "cricket-raw-data"          # Used by terraform/gcs.tf
  raw_prefix: "batting/"                   # Used by terraform/gcs.tf
  template_bucket: "cricket-dataflow-templates"
  temp_bucket: "cricket-dataflow-temp"

bigquery:
  dataset_raw: "cricket_raw"              # Used by terraform/bigquery.tf
  dataset_staging: "cricket_staging"
  dataset_curated: "cricket_curated"
  table_raw_batting: "batting_rankings"

api:
  base_url: "https://cricbuzz-cricket.p.rapidapi.com"
  endpoint: "/stats/v1/rankings/batsmen"
  api_key: "${RAPIDAPI_KEY}"  # Read from environment variable
  formats: [test, odi, t20i]

scheduling:
  ingestion_schedule: "0 6 * * *"        # Daily 06:00 UTC
  staging_schedule: "0 8 * * *"          # Daily 08:00 UTC
  monitoring_schedule: "0 10 * * *"      # Daily 10:00 UTC

dataflow:
  machine_type: "n1-standard-2"
  min_workers: 2
  max_workers: 5
  sdk_container_image: "python:3.11-slim"

looker:
  dashboard_title: "Cricket Batting Rankings Analytics"
  refresh_interval_minutes: 60
```

### Usage in Code

```python
import yaml

with open('config/config.yaml', 'r') as f:
    config = yaml.safe_load(f)

project_id = config['gcp']['project_id']
raw_bucket = config['gcs']['raw_bucket']      # Source of truth for bucket name
raw_prefix = config['gcs']['raw_prefix']      # Source of truth for prefix
raw_dataset = config['bigquery']['dataset_raw']  # Source of truth for dataset
api_key = config['apis']['rapidapi']['api_key']
formats = config['apis']['formats']  # ['test', 'odi', 't20i']
```

### Environment Variable Override

```bash
# The API key MUST be set as an environment variable
export RAPIDAPI_KEY="your-actual-api-key-here"

# Then Python reads it via:
api_key = config['api']['api_key']  # Returns the ${RAPIDAPI_KEY} value from env
```

---

## 2. Ingestion Module

**File**: `ingestion/fetch_batting_rankings.py`

### Purpose
Fetches ICC Men's Batting Rankings from Cricbuzz API (via RapidAPI) and uploads a CSV to Google Cloud Storage.

### Execution Context
- **Trigger**: Cloud Scheduler job (daily at 06:00 UTC)
- **Environment**: Cloud Run container
- **Output**: Timestamped CSV file in `gs://{raw_bucket}/batting/batting_rankings_{YYYYMMDD_HHMMSS}.csv`

### Functions

#### `load_config()`
Reads and returns the YAML configuration.

```python
def load_config():
    """Load config from YAML file."""
    with open('config/config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    return config
```

**Returns**: `dict` — Configuration dictionary

---

#### `get_api_key()`
Retrieves the RapidAPI key from the environment variable.

```python
def get_api_key():
    """Get API key from environment."""
    api_key = os.getenv('RAPIDAPI_KEY')
    if not api_key:
        raise ValueError("RAPIDAPI_KEY environment variable not set")
    return api_key
```

**Returns**: `str` — API key  
**Raises**: `ValueError` if env var is not set

---

#### `fetch_rankings(format_type, api_key, config)`
Makes HTTP GET request to Cricbuzz API for a specific format (test/odi/t20i).

```python
def fetch_rankings(format_type, api_key, config):
    """Fetch rankings from Cricbuzz API for a specific format."""
    headers = {
        'X-RapidAPI-Key': api_key,
        'X-RapidAPI-Host': 'cricbuzz-cricket.p.rapidapi.com'
    }
    params = {
        'formatType': format_type,
        'rankType': 'batsmen'
    }
    url = config['api']['base_url'] + config['api']['endpoint']
    
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json()
```

**Parameters**:
- `format_type` (str): One of `'test'`, `'odi'`, `'t20i'`
- `api_key` (str): RapidAPI authentication key
- `config` (dict): Configuration dictionary

**Returns**: `dict` — Raw JSON response from API  
**Raises**: `requests.exceptions.HTTPError` on API failure

**API Response Structure**:
```json
{
  "data": {
    "rank": [
      {
        "rank": 1,
        "player": {
          "id": "12345",
          "name": "Virat Kohli"
        },
        "country": {
          "id": "1",
          "name": "India"
        },
        "rating": 845.0,
        "points": 2535,
        "info": {
          "careerBestRank": 1,
          "careerBestRating": 937.0
        }
      },
      ...
    ]
  }
}
```

---

#### `parse_rankings(data, format_type)`
Converts API JSON response to pandas DataFrame.

```python
def parse_rankings(data, format_type):
    """Parse API response into DataFrame."""
    records = []
    for player_data in data['data']['rank']:
        record = {
            'rank': player_data['rank'],
            'player_id': player_data['player']['id'],
            'player_name': player_data['player']['name'],
            'country': player_data['country']['name'],
            'country_id': player_data['country']['id'],
            'rating': player_data['rating'],
            'points': player_data['points'],
            'best_rank': player_data['info']['careerBestRank'],
            'format': format_type.upper(),
            'ingested_at': datetime.utcnow().isoformat() + 'Z'
        }
        records.append(record)
    
    return pd.DataFrame(records)
```

**Parameters**:
- `data` (dict): API JSON response
- `format_type` (str): One of `'test'`, `'odi'`, `'t20i'`

**Returns**: `pd.DataFrame` with columns:
- `rank` (int): Current ranking
- `player_id` (str): Unique player identifier
- `player_name` (str): Player's full name
- `country` (str): Country name
- `country_id` (str): Country identifier
- `rating` (float): Current rating
- `points` (float): Total points
- `best_rank` (int): Career best rank
- `format` (str): Format (TEST/ODI/T20I)
- `ingested_at` (str): ISO UTC timestamp

---

#### `upload_to_gcs(df, bucket, prefix)`
Serializes DataFrame to CSV and uploads to Google Cloud Storage.

```python
def upload_to_gcs(df, bucket, prefix):
    """Upload DataFrame to GCS as CSV."""
    client = storage.Client()
    bucket_obj = client.bucket(bucket)
    
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    filename = f'batting_rankings_{timestamp}.csv'
    blob = bucket_obj.blob(f'{prefix}/{filename}')
    
    csv_data = df.to_csv(index=False)
    blob.upload_from_string(csv_data, content_type='text/csv')
    
    gcs_path = f'gs://{bucket}/{prefix}/{filename}'
    print(f"Uploaded to: {gcs_path}")
    return gcs_path
```

**Parameters**:
- `df` (pd.DataFrame): Data to upload
- `bucket` (str): GCS bucket name
- `prefix` (str): Folder prefix (e.g., `'batting'`)

**Returns**: `str` — Full GCS URI  
**Side Effects**: Uploads CSV file to GCS

---

#### `main()`
Orchestrates the complete ingestion flow.

```python
def main():
    """Main ingestion flow."""
    try:
        config = load_config()
        api_key = get_api_key()
        
        dfs = []
        for format_type in config['api']['formats']:  # ['test', 'odi', 't20i']
            print(f"Fetching {format_type} rankings...")
            data = fetch_rankings(format_type, api_key, config)
            df = parse_rankings(data, format_type)
            dfs.append(df)
            print(f"  {len(df)} records fetched")
        
        combined_df = pd.concat(dfs, ignore_index=True)
        print(f"Total records: {len(combined_df)}")
        
        gcs_path = upload_to_gcs(
            combined_df,
            config['gcs']['raw_data_bucket'],
            'batting'
        )
        print(f"Success! Data uploaded to {gcs_path}")
        return 0
        
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())
```

### Requirements

```
requests==2.31.0
pandas==2.0.3
google-cloud-storage==2.10.0
pyyaml==6.0
python-dotenv==1.0.0
```

### Example Execution

```bash
# Set API key
export RAPIDAPI_KEY="abc123def456..."

# Run locally
python ingestion/fetch_batting_rankings.py

# Expected output
# Fetching test rankings...
#   150 records fetched
# Fetching odi rankings...
#   150 records fetched
# Fetching t20i rankings...
#   150 records fetched
# Total records: 450
# Success! Data uploaded to gs://cricket-raw-data/batting/batting_rankings_20240601_060000.csv
```

### CSV Output Format

```csv
rank,player_id,player_name,country,country_id,rating,points,best_rank,format,ingested_at
1,12345,Virat Kohli,India,1,845.0,2535,1,TEST,2024-06-01T06:00:00Z
2,23456,Kane Williamson,New Zealand,6,820.0,2460,2,TEST,2024-06-01T06:00:00Z
...
```

---

## 3. Cloud Function Module

**File**: `cloud_function/main.py`

### Purpose
Event-driven bridge that listens for new CSV files in GCS and triggers Dataflow jobs to process them.

### Execution Context
- **Trigger**: Google Cloud Storage object finalization event via Eventarc
- **Runtime**: Python 3.11
- **Timeout**: 600 seconds
- **Memory**: 512 MB (default)
- **Max Instances**: 10

### Functions

#### `process_batting_file(cloud_event)`
Cloud Function entry point. Triggered by GCS finalization events.

```python
@functions_framework.cloud_event
def process_batting_file(cloud_event):
    """Process a new batting rankings CSV file."""
    # Extract GCS event data
    payload = base64.b64decode(cloud_event.data["message"]["data"]).decode()
    gcs_event = json.loads(payload)
    
    bucket = gcs_event['bucket']
    filename = gcs_event['name']
    
    # Filter: only process CSV files in batting/ folder
    if not filename.startswith('batting/') or not filename.endswith('.csv'):
        print(f"Ignoring: {filename}")
        return
    
    gcs_path = f'gs://{bucket}/{filename}'
    job_name = f"batting-{filename.split('/')[-1].replace('.csv', '')}"
    
    print(f"Processing: {gcs_path}")
    launch_dataflow_job(gcs_path, job_name)
```

**Parameters**:
- `cloud_event`: Eventarc cloud event containing GCS finalization data

**Side Effects**: Launches a Dataflow job

---

#### `launch_dataflow_job(input_file, job_name)`
Creates and launches a Dataflow Flex Template job.

```python
def launch_dataflow_job(input_file, job_name):
    """Launch Dataflow Flex Template job."""
    project = os.getenv('GCP_PROJECT')
    region = os.getenv('GCP_REGION', 'us-central1')
    template_location = os.getenv('DATAFLOW_TEMPLATE_LOCATION')
    dataset = os.getenv('BQ_DATASET', 'cricket_raw')
    table = os.getenv('BQ_TABLE', 'batting_rankings')
    
    client = dataflow_v1beta3.FlexTemplatesServiceClient()
    
    request = dataflow_v1beta3.LaunchFlexTemplateRequest(
        project_id=project,
        location=region,
        launch_parameter=dataflow_v1beta3.LaunchFlexTemplateParameter(
            job_name=job_name,
            template_uri=template_location,
            parameters={
                'input_file': input_file,
                'output_dataset': dataset,
                'output_table': table,
            },
            environment=dataflow_v1beta3.FlexTemplateRuntimeEnvironment(
                machine_type='n1-standard-2',
                num_workers=2,
                max_workers=5,
                temp_location=f'gs://{os.getenv("TEMP_BUCKET")}/temp'
            )
        )
    )
    
    response = client.launch_flex_template(request=request)
    print(f"Dataflow job launched: {response.job.name}")
    return response
```

**Parameters**:
- `input_file` (str): GCS URI of the CSV file (e.g., `gs://bucket/batting/file.csv`)
- `job_name` (str): Unique name for the Dataflow job

**Returns**: `dataflow_v1beta3.Job` response  
**Side Effects**: Launches a Dataflow job on Google Cloud

**Environment Variables**:
- `GCP_PROJECT`: Google Cloud project ID
- `GCP_REGION`: GCP region (default: `us-central1`)
- `DATAFLOW_TEMPLATE_LOCATION`: GCS URI of Flex Template spec
- `BQ_DATASET`: BigQuery dataset name (default: `cricket_raw`)
- `BQ_TABLE`: BigQuery table name (default: `batting_rankings`)
- `TEMP_BUCKET`: GCS bucket for Dataflow temporary files

### Requirements

```
functions-framework==3.5.0
google-cloud-dataflow==2.52.0
google-cloud-logging==3.8.0
```

### Deployment

```bash
# Deploy to Cloud Functions
gcloud functions deploy cricket-gcs-dataflow-trigger \
  --gen2 \
  --runtime python311 \
  --region us-central1 \
  --trigger-event-type google.cloud.storage.object.v1.finalized \
  --trigger-resource cricket-raw-data \
  --entry-point process_batting_file \
  --set-env-vars GCP_PROJECT=my-project,GCP_REGION=us-central1,DATAFLOW_TEMPLATE_LOCATION=gs://cricket-dataflow-templates/batting-pipeline
```

---

## 4. Dataflow Module

**File**: `dataflow/pipeline.py`

### Purpose
Apache Beam pipeline that reads CSV from GCS, validates and transforms data, and writes to BigQuery.

### Execution Context
- **Runner**: DataflowRunner (Google Cloud Dataflow)
- **Language**: Python 3.11
- **SDK**: Apache Beam 2.52.0
- **Workers**: 2–5 on n1-standard-2 machines
- **Scaling**: Auto-scales based on input data size

### Schema Definition

```python
RAW_SCHEMA = {
    'fields': [
        {'name': 'rank', 'type': 'INTEGER', 'mode': 'NULLABLE'},
        {'name': 'player_id', 'type': 'STRING', 'mode': 'NULLABLE'},
        {'name': 'player_name', 'type': 'STRING', 'mode': 'NULLABLE'},
        {'name': 'country', 'type': 'STRING', 'mode': 'NULLABLE'},
        {'name': 'country_id', 'type': 'STRING', 'mode': 'NULLABLE'},
        {'name': 'rating', 'type': 'FLOAT', 'mode': 'NULLABLE'},
        {'name': 'points', 'type': 'FLOAT', 'mode': 'NULLABLE'},
        {'name': 'best_rank', 'type': 'INTEGER', 'mode': 'NULLABLE'},
        {'name': 'format', 'type': 'STRING', 'mode': 'NULLABLE'},
        {'name': 'ingested_at', 'type': 'TIMESTAMP', 'mode': 'NULLABLE'},
        {'name': 'source_file', 'type': 'STRING', 'mode': 'NULLABLE'},
    ]
}
```

### DoFn Classes

#### `ParseCsvLine(beam.DoFn)`
Custom DoFn that parses each CSV line and converts to a BigQuery record.

```python
class ParseCsvLine(beam.DoFn):
    """Parse CSV line into BigQuery record."""
    
    def process(self, line, source_file):
        """
        Process a single CSV line.
        
        Args:
            line: CSV line as string
            source_file: GCS source file path
            
        Yields:
            dict: BigQuery record
        """
        # Skip header
        if line.startswith('rank'):
            return
        
        try:
            reader = csv.reader([line])
            fields = next(reader)
            
            if len(fields) < 10:
                logging.warning(f"Skipping malformed line: {line[:50]}...")
                return
            
            record = {
                'rank': int(fields[0]),
                'player_id': fields[1].strip(),
                'player_name': fields[2].strip(),
                'country': fields[3].strip(),
                'country_id': fields[4].strip(),
                'rating': float(fields[5]),
                'points': float(fields[6]),
                'best_rank': int(fields[7]),
                'format': fields[8].strip().upper(),
                'ingested_at': fields[9].strip(),
                'source_file': source_file,
            }
            
            yield record
            
        except (ValueError, IndexError) as e:
            logging.error(f"Error parsing line: {str(e)}")
            return
```

**Input**: CSV line as string  
**Output**: dict with 11 keys matching BigQuery schema  
**Behavior**: Skips header, logs errors, yields valid records

### Pipeline Construction

```python
def run(argv=None):
    """Build and run the Beam pipeline."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--input_file', required=True, help='GCS input CSV file')
    parser.add_argument('--output_dataset', required=True, help='BigQuery dataset')
    parser.add_argument('--output_table', required=True, help='BigQuery table')
    parser.add_argument('--runner', default='DataflowRunner', help='Beam runner')
    parser.add_argument('--project', required=True, help='GCP project ID')
    parser.add_argument('--region', default='us-central1', help='GCP region')
    parser.add_argument('--temp_location', required=True, help='GCS temp location')
    
    known_args, pipeline_args = parser.parse_known_args(argv)
    
    # Create pipeline options
    pipeline_options = PipelineOptions(
        project=known_args.project,
        runner=known_args.runner,
        region=known_args.region,
        temp_location=known_args.temp_location,
        machine_type='n1-standard-2',
        num_workers=2,
        max_num_workers=5,
        autoscaling_algorithm='THROUGHPUT_BASED',
    )
    
    # Create and run pipeline
    with Pipeline(options=pipeline_options) as p:
        (p
         | 'ReadFromText' >> beam.io.ReadFromText(known_args.input_file)
         | 'ParseCsvLine' >> beam.ParDo(ParseCsvLine(), known_args.input_file)
         | 'WriteToBigQuery' >> beam.io.WriteToBigQuery(
             table=f'{known_args.project}:{known_args.output_dataset}.{known_args.output_table}',
             schema=RAW_SCHEMA,
             write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
             create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
         ))

if __name__ == '__main__':
    run()
```

### Pipeline Flow

```
Input CSV (GCS)
    ↓
ReadFromText
    ↓ (emits each line as a string)
ParseCsvLine DoFn
    ↓ (emits each valid record as a dict)
WriteToBigQuery
    ↓ (batches and appends to BigQuery)
Output Table (BigQuery)
```

### Requirements

```
apache-beam[gcp]==2.52.0
google-cloud-bigquery==3.13.0
pandas==2.0.3
```

### Docker Container

**File**: `dataflow/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install -q --no-cache-dir -r requirements.txt

# Copy pipeline code
COPY pipeline.py .

# Set entrypoint for Dataflow
ENTRYPOINT ["python", "-m", "apache_beam.runners.dataflow.runner", \
            "--project=${GCP_PROJECT}", \
            "--region=${GCP_REGION}", \
            "--temp_location=${TEMP_LOCATION}"]
```

### Execution Example

```bash
# Run locally (DirectRunner)
python dataflow/pipeline.py \
  --input_file gs://cricket-raw-data/batting/batting_rankings_20240601_060000.csv \
  --output_dataset cricket_raw \
  --output_table batting_rankings \
  --project my-project \
  --runner DirectRunner \
  --temp_location gs://cricket-dataflow-temp/temp

# Run on Dataflow (DataflowRunner)
python dataflow/pipeline.py \
  --input_file gs://cricket-raw-data/batting/batting_rankings_20240601_060000.csv \
  --output_dataset cricket_raw \
  --output_table batting_rankings \
  --project my-project \
  --runner DataflowRunner \
  --region us-central1 \
  --temp_location gs://cricket-dataflow-temp/temp
```

---

## 5. BigQuery Module

**File**: `bigquery/sql/01-07_*.sql`

### Purpose
Defines all BigQuery tables, schemas, and analytics views using the Medallion Architecture.

### Layer Structure

```
RAW LAYER
  └─ batting_rankings (one table, event log)

STAGING LAYER (Star Schema)
  ├─ dim_player (SCD Type 1)
  ├─ dim_country
  ├─ dim_format (static)
  ├─ dim_date (date spine)
  └─ fact_batting_rankings (daily snapshot fact)

CURATED LAYER (Analytics Views)
  ├─ vw_current_rankings
  ├─ vw_ranking_trend
  ├─ vw_top10_by_format
  ├─ vw_country_summary
  └─ vw_player_format_comparison
```

### 5.1 RAW Layer

**File**: `01_create_raw_table.sql`

```sql
-- Create RAW table (exact copy of ingested data)
CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_raw.batting_rankings` (
    rank INT64,
    player_id STRING,
    player_name STRING,
    country STRING,
    country_id STRING,
    rating FLOAT64,
    points FLOAT64,
    best_rank INT64,
    format STRING,
    ingested_at TIMESTAMP,
    source_file STRING
)
PARTITION BY DATE(ingested_at)
CLUSTER BY format, country
OPTIONS (
    description = "Raw batting rankings data - exact copy from API",
    require_partition_filter = false,
    partition_expiration_days = 90
);

-- Debug view: Latest 100 records per format per day
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_raw.vw_latest_raw` AS
SELECT
    rank,
    player_id,
    player_name,
    country,
    country_id,
    rating,
    points,
    best_rank,
    format,
    ingested_at,
    DATE(ingested_at) as ingestion_date,
    ROW_NUMBER() OVER (PARTITION BY format, DATE(ingested_at) ORDER BY rank) as rn
FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
WHERE rn <= 100;
```

**Key Characteristics**:
- Partitioned by ingestion date for query efficiency
- Clustered by format and country for common filter patterns
- 90-day retention policy
- No PK/FK constraints (event log style)

### 5.2 STAGING Layer — Star Schema

#### dim_player

```sql
CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_staging.dim_player` (
    player_id STRING NOT NULL,
    player_name STRING,
    country_id STRING,
    last_updated TIMESTAMP
)
PARTITION BY DATE(last_updated)
OPTIONS (
    description = "Player dimension - SCD Type 1",
    require_partition_filter = false
);

-- MERGE to upsert from raw layer
MERGE INTO `{PROJECT_ID}.cricket_staging.dim_player` tgt
USING (
    SELECT
        DISTINCT player_id,
        MAX(player_name) as player_name,
        MAX(country_id) as country_id,
        CURRENT_TIMESTAMP() as last_updated
    FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
    WHERE DATE(ingested_at) = CURRENT_DATE()
    GROUP BY player_id
) src
ON tgt.player_id = src.player_id
WHEN MATCHED THEN
    UPDATE SET
        player_name = src.player_name,
        country_id = src.country_id,
        last_updated = src.last_updated
WHEN NOT MATCHED THEN
    INSERT (player_id, player_name, country_id, last_updated)
    VALUES (src.player_id, src.player_name, src.country_id, src.last_updated);
```

**Characteristics**:
- SCD Type 1: Overwrites on update (no history)
- Keyed by player_id
- Populated daily via MERGE from raw layer

---

#### dim_country

```sql
CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_staging.dim_country` (
    country_id STRING NOT NULL,
    country_name STRING,
    icc_code STRING,
    last_updated TIMESTAMP
)
OPTIONS (
    description = "Country dimension with ICC codes"
);

-- MERGE to upsert
MERGE INTO `{PROJECT_ID}.cricket_staging.dim_country` tgt
USING (
    SELECT
        DISTINCT country_id,
        MAX(country) as country_name,
        CURRENT_TIMESTAMP() as last_updated
    FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
    WHERE DATE(ingested_at) = CURRENT_DATE()
    GROUP BY country_id
) src
ON tgt.country_id = src.country_id
WHEN MATCHED THEN
    UPDATE SET
        country_name = src.country_name,
        last_updated = src.last_updated
WHEN NOT MATCHED THEN
    INSERT (country_id, country_name, last_updated)
    VALUES (src.country_id, src.country_name, src.last_updated);

-- Update ICC codes for known countries
UPDATE `{PROJECT_ID}.cricket_staging.dim_country`
SET icc_code = CASE country_name
    WHEN 'India' THEN 'IND'
    WHEN 'Australia' THEN 'AUS'
    WHEN 'Pakistan' THEN 'PAK'
    WHEN 'England' THEN 'ENG'
    WHEN 'South Africa' THEN 'RSA'
    WHEN 'West Indies' THEN 'WI'
    WHEN 'New Zealand' THEN 'NZ'
    WHEN 'Sri Lanka' THEN 'SL'
    WHEN 'Bangladesh' THEN 'BAN'
    WHEN 'Afghanistan' THEN 'AFG'
    ELSE 'UNK'
END
WHERE icc_code IS NULL;
```

---

#### dim_format

```sql
CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_staging.dim_format` (
    format_id INT64,
    format_name STRING
)
OPTIONS (
    description = "Format dimension - static lookup"
);

INSERT INTO `{PROJECT_ID}.cricket_staging.dim_format` (format_id, format_name)
VALUES (1, 'TEST'), (2, 'ODI'), (3, 'T20I');
```

---

#### dim_date

```sql
CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_staging.dim_date` (
    date_id INT64,
    full_date DATE,
    year INT64,
    quarter INT64,
    month INT64,
    day INT64,
    week INT64,
    day_of_week INT64,
    day_name STRING,
    month_name STRING
)
OPTIONS (
    description = "Date dimension - 2015-2035 spine"
);

INSERT INTO `{PROJECT_ID}.cricket_staging.dim_date`
SELECT
    CAST(FORMAT_DATE('%Y%m%d', date_val) AS INT64) as date_id,
    date_val as full_date,
    EXTRACT(YEAR FROM date_val) as year,
    EXTRACT(QUARTER FROM date_val) as quarter,
    EXTRACT(MONTH FROM date_val) as month,
    EXTRACT(DAY FROM date_val) as day,
    EXTRACT(WEEK FROM date_val) as week,
    EXTRACT(DAYOFWEEK FROM date_val) as day_of_week,
    FORMAT_DATE('%A', date_val) as day_name,
    FORMAT_DATE('%B', date_val) as month_name
FROM (
    SELECT DATE_ADD('2015-01-01', INTERVAL CAST(i AS INT64) DAY) as date_val
    FROM UNNEST(GENERATE_ARRAY(0, 7304)) as i
);
```

---

#### fact_batting_rankings

```sql
CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_staging.fact_batting_rankings` (
    fact_id STRING,
    date_id INT64,
    player_id STRING,
    format_id INT64,
    country_id STRING,
    rank INT64,
    rating FLOAT64,
    points FLOAT64,
    best_rank INT64,
    loaded_at TIMESTAMP
)
PARTITION BY DATE(loaded_at)
CLUSTER BY format_id, country_id
OPTIONS (
    description = "Fact table - daily snapshot of rankings",
    require_partition_filter = false
);

-- MERGE to upsert (idempotent)
MERGE INTO `{PROJECT_ID}.cricket_staging.fact_batting_rankings` tgt
USING (
    SELECT
        CONCAT(
            FORMAT_DATE('%Y%m%d', CURRENT_DATE()),
            '-',
            r.player_id,
            '-',
            CASE r.format WHEN 'TEST' THEN '1' WHEN 'ODI' THEN '2' ELSE '3' END
        ) as fact_id,
        CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE()) AS INT64) as date_id,
        r.player_id,
        CASE r.format WHEN 'TEST' THEN 1 WHEN 'ODI' THEN 2 ELSE 3 END as format_id,
        r.country_id,
        r.rank,
        r.rating,
        r.points,
        r.best_rank,
        CURRENT_TIMESTAMP() as loaded_at
    FROM `{PROJECT_ID}.cricket_raw.batting_rankings` r
    WHERE DATE(r.ingested_at) = CURRENT_DATE()
) src
ON tgt.fact_id = src.fact_id
WHEN MATCHED THEN
    UPDATE SET
        rank = src.rank,
        rating = src.rating,
        points = src.points,
        loaded_at = src.loaded_at
WHEN NOT MATCHED THEN
    INSERT (fact_id, date_id, player_id, format_id, country_id, rank, rating, points, best_rank, loaded_at)
    VALUES (src.fact_id, src.date_id, src.player_id, src.format_id, src.country_id, src.rank, src.rating, src.points, src.best_rank, src.loaded_at);
```

**Composite Key**: `YYYYMMDD-player_id-format_id`  
**Frequency**: Daily snapshot (one record per player per format per day)

### 5.3 CURATED Layer — Analytics Views

**File**: `07_create_curated_views.sql`

#### vw_current_rankings
```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_current_rankings` AS
SELECT
    dp.player_name,
    dc.country_name,
    df.format_name as format,
    f.rank as current_rank,
    f.rating as current_rating,
    f.points,
    f.best_rank,
    f.loaded_at
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` f
JOIN `{PROJECT_ID}.cricket_staging.dim_player` dp ON f.player_id = dp.player_id
JOIN `{PROJECT_ID}.cricket_staging.dim_country` dc ON f.country_id = dc.country_id
JOIN `{PROJECT_ID}.cricket_staging.dim_format` df ON f.format_id = df.format_id
WHERE DATE(f.loaded_at) = CURRENT_DATE()
ORDER BY f.format_id, f.rank;
```

**Use Case**: Current rankings for today — ideal for dashboard tables

---

#### vw_ranking_trend
```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_ranking_trend` AS
SELECT
    dp.player_name,
    dc.country_name,
    df.format_name as format,
    dd.full_date,
    f.rank,
    LAG(f.rank) OVER (
        PARTITION BY f.player_id, f.format_id
        ORDER BY f.date_id
    ) as previous_rank,
    f.rank - LAG(f.rank) OVER (
        PARTITION BY f.player_id, f.format_id
        ORDER BY f.date_id
    ) as rank_change,
    f.rating
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` f
JOIN `{PROJECT_ID}.cricket_staging.dim_player` dp ON f.player_id = dp.player_id
JOIN `{PROJECT_ID}.cricket_staging.dim_country` dc ON f.country_id = dc.country_id
JOIN `{PROJECT_ID}.cricket_staging.dim_format` df ON f.format_id = df.format_id
JOIN `{PROJECT_ID}.cricket_staging.dim_date` dd ON f.date_id = dd.date_id
WHERE dd.full_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
ORDER BY f.format_id, dp.player_name, f.date_id;
```

**Use Case**: 90-day ranking history with rank movement — ideal for line charts

---

#### vw_top10_by_format
```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_top10_by_format` AS
SELECT
    dp.player_name,
    dc.country_name,
    df.format_name as format,
    f.rank as current_rank,
    f.rating as current_rating,
    f.points,
    ROW_NUMBER() OVER (PARTITION BY f.format_id ORDER BY f.rank) as format_rank
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` f
JOIN `{PROJECT_ID}.cricket_staging.dim_player` dp ON f.player_id = dp.player_id
JOIN `{PROJECT_ID}.cricket_staging.dim_country` dc ON f.country_id = dc.country_id
JOIN `{PROJECT_ID}.cricket_staging.dim_format` df ON f.format_id = df.format_id
WHERE DATE(f.loaded_at) = CURRENT_DATE()
    AND f.rank <= 10
ORDER BY f.format_id, f.rank;
```

**Use Case**: Top 10 players per format — ideal for bar charts

---

#### vw_country_summary
```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_country_summary` AS
SELECT
    dc.country_name,
    df.format_name as format,
    COUNT(DISTINCT f.player_id) as total_players,
    COUNTIF(f.rank <= 10) as players_in_top10,
    COUNTIF(f.rank <= 50) as players_in_top50,
    ROUND(AVG(f.rating), 2) as avg_rating,
    MIN(f.rating) as min_rating,
    MAX(f.rating) as max_rating,
    ROUND(AVG(f.points), 0) as avg_points
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` f
JOIN `{PROJECT_ID}.cricket_staging.dim_country` dc ON f.country_id = dc.country_id
JOIN `{PROJECT_ID}.cricket_staging.dim_format` df ON f.format_id = df.format_id
WHERE DATE(f.loaded_at) = CURRENT_DATE()
GROUP BY dc.country_name, df.format_name
ORDER BY dc.country_name, df.format_name;
```

**Use Case**: Country performance — ideal for pie/donut charts

---

#### vw_player_format_comparison
```sql
CREATE OR REPLACE VIEW `{PROJECT_ID}.cricket_curated.vw_player_format_comparison` AS
SELECT
    dp.player_name,
    dc.country_name,
    MAX(CASE WHEN df.format_id = 1 THEN f.rank END) as test_rank,
    MAX(CASE WHEN df.format_id = 1 THEN f.rating END) as test_rating,
    MAX(CASE WHEN df.format_id = 2 THEN f.rank END) as odi_rank,
    MAX(CASE WHEN df.format_id = 2 THEN f.rating END) as odi_rating,
    MAX(CASE WHEN df.format_id = 3 THEN f.rank END) as t20i_rank,
    MAX(CASE WHEN df.format_id = 3 THEN f.rating END) as t20i_rating
FROM `{PROJECT_ID}.cricket_staging.fact_batting_rankings` f
JOIN `{PROJECT_ID}.cricket_staging.dim_player` dp ON f.player_id = dp.player_id
JOIN `{PROJECT_ID}.cricket_staging.dim_country` dc ON f.country_id = dc.country_id
JOIN `{PROJECT_ID}.cricket_staging.dim_format` df ON f.format_id = df.format_id
WHERE DATE(f.loaded_at) = CURRENT_DATE()
GROUP BY dp.player_name, dc.country_name
ORDER BY COALESCE(test_rank, odi_rank, t20i_rank);
```

**Use Case**: Cross-format player comparison — ideal for multi-column tables

---

## 6. Airflow DAG Module

**File**: `airflow/dags/cricket_analytics_dag.py`

### Purpose
Complete end-to-end orchestration using Apache Airflow (Cloud Composer), with observability, retries, and error handling.

### DAG Configuration

```python
from airflow import DAG
from datetime import datetime

default_args = {
    'owner': 'cricket-analytics',
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
    'email_on_failure': True,
}

dag = DAG(
    'cricket_analytics',
    default_args=default_args,
    description='Daily cricket batting rankings pipeline',
    schedule_interval='0 6 * * *',  # 06:00 UTC daily
    max_active_runs=1,
    catchup=False,
    tags=['cricket', 'analytics', 'dataflow'],
)
```

**Schedule**: `0 6 * * *` (daily 06:00 UTC)  
**Max Runs**: 1 (no parallel runs)  
**Retries**: 2 attempts per task

### Task Groups

#### Stage 1: ingestion_tg
```python
with TaskGroup(group_id='ingestion_tg', dag=dag) as ingestion_tg:
    fetch_task = PythonOperator(
        task_id='fetch_cricbuzz_api',
        python_callable=fetch_cricbuzz_api,
        op_kwargs={
            'config_path': '/home/airflow/gcs/data/config.yaml',
            'bucket': Variable.get('raw_bucket', 'cricket-raw-data'),
        }
    )
```

**Tasks**:
- `fetch_cricbuzz_api` — calls RapidAPI for all 3 formats, concatenates DataFrames, uploads CSV to GCS
- Pushes `gcs_file_path` to XCom for downstream tasks

---

#### Stage 2: processing_tg
```python
with TaskGroup(group_id='processing_tg', dag=dag) as processing_tg:
    dataflow_task = DataflowTemplateOperator(
        task_id='launch_dataflow_job',
        template_location=Variable.get('dataflow_template_uri'),
        project_id=Variable.get('gcp_project_id'),
        location=Variable.get('gcp_region', 'us-central1'),
        parameters={
            'input_file': '{{ ti.xcom_pull(task_ids="ingestion_tg.fetch_cricbuzz_api") }}',
            'output_dataset': Variable.get('raw_dataset', 'cricket_raw'),
            'output_table': Variable.get('raw_table', 'batting_rankings'),
        },
        wait_until_finished=True,
    )
```

**Tasks**:
- `launch_dataflow_job` — pulls GCS path from XCom, launches Dataflow Flex Template, waits for completion

---

#### Stage 3: validation_tg
```python
with TaskGroup(group_id='validation_tg', dag=dag) as validation_tg:
    def validate_data_quality(**context):
        """Check that today's data has arrived."""
        project_id = Variable.get('gcp_project_id')
        dataset = Variable.get('raw_dataset', 'cricket_raw')
        table = Variable.get('raw_table', 'batting_rankings')
        
        bq_client = bigquery.Client(project=project_id)
        query = f"""
            SELECT COUNT(*) as count
            FROM `{project_id}.{dataset}.{table}`
            WHERE DATE(ingested_at) = CURRENT_DATE()
        """
        result = bq_client.query(query).result()
        row = list(result)[0]
        
        if row['count'] < 100:
            raise AirflowException(
                f"Data validation failed: only {row['count']} records found (expected >= 100)"
            )
        
        print(f"✓ Validation passed: {row['count']} records in raw table")
    
    validation_task = PythonOperator(
        task_id='validate_data_quality',
        python_callable=validate_data_quality,
    )
```

**Tasks**:
- `validate_data_quality` — queries BigQuery for today's record count
- Raises exception if count < 100 (fails the DAG)

---

#### Stage 4: staging_transformation
```python
with TaskGroup(group_id='staging_transformation', dag=dag) as staging_tg:
    # Task 1: Transform dim_player
    transform_player = BigQueryInsertJobOperator(
        task_id='transform_dim_player',
        configuration={
            'query': {
                'query': f"""
                    MERGE INTO `{project_id}.{staging_dataset}.dim_player` tgt
                    USING (
                        SELECT DISTINCT player_id,
                               MAX(player_name) as player_name,
                               MAX(country_id) as country_id,
                               CURRENT_TIMESTAMP() as last_updated
                        FROM `{project_id}.{raw_dataset}.batting_rankings`
                        WHERE DATE(ingested_at) = CURRENT_DATE()
                        GROUP BY player_id
                    ) src
                    ON tgt.player_id = src.player_id
                    WHEN MATCHED THEN UPDATE SET
                        player_name = src.player_name,
                        country_id = src.country_id,
                        last_updated = src.last_updated
                    WHEN NOT MATCHED THEN INSERT
                        (player_id, player_name, country_id, last_updated)
                    VALUES (src.player_id, src.player_name, src.country_id, src.last_updated)
                """,
                'useLegacySql': False,
            }
        }
    )
    
    # Task 2: Transform dim_country
    transform_country = BigQueryInsertJobOperator(
        task_id='transform_dim_country',
        configuration={
            'query': {
                'query': f"""
                    MERGE INTO `{project_id}.{staging_dataset}.dim_country` tgt
                    USING (
                        SELECT DISTINCT country_id,
                               MAX(country) as country_name,
                               CURRENT_TIMESTAMP() as last_updated
                        FROM `{project_id}.{raw_dataset}.batting_rankings`
                        WHERE DATE(ingested_at) = CURRENT_DATE()
                        GROUP BY country_id
                    ) src
                    ON tgt.country_id = src.country_id
                    WHEN MATCHED THEN UPDATE SET
                        country_name = src.country_name,
                        last_updated = src.last_updated
                    WHEN NOT MATCHED THEN INSERT
                        (country_id, country_name, last_updated)
                    VALUES (src.country_id, src.country_name, src.last_updated)
                """,
                'useLegacySql': False,
            }
        }
    )
    
    # Task 3: Transform fact_batting_rankings
    transform_fact = BigQueryInsertJobOperator(
        task_id='transform_fact_batting',
        configuration={
            'query': {
                'query': f"""
                    MERGE INTO `{project_id}.{staging_dataset}.fact_batting_rankings` tgt
                    USING (
                        SELECT
                            CONCAT(
                                FORMAT_DATE('%Y%m%d', CURRENT_DATE()),
                                '-',
                                player_id,
                                '-',
                                CASE format WHEN 'TEST' THEN '1' WHEN 'ODI' THEN '2' ELSE '3' END
                            ) as fact_id,
                            CAST(FORMAT_DATE('%Y%m%d', CURRENT_DATE()) AS INT64) as date_id,
                            player_id,
                            CASE format WHEN 'TEST' THEN 1 WHEN 'ODI' THEN 2 ELSE 3 END as format_id,
                            country_id,
                            rank,
                            rating,
                            points,
                            best_rank,
                            CURRENT_TIMESTAMP() as loaded_at
                        FROM `{project_id}.{raw_dataset}.batting_rankings`
                        WHERE DATE(ingested_at) = CURRENT_DATE()
                    ) src
                    ON tgt.fact_id = src.fact_id
                    WHEN MATCHED THEN UPDATE SET
                        rank = src.rank,
                        rating = src.rating,
                        points = src.points,
                        loaded_at = src.loaded_at
                    WHEN NOT MATCHED THEN INSERT
                        (fact_id, date_id, player_id, format_id, country_id, rank, rating, points, best_rank, loaded_at)
                    VALUES (src.fact_id, src.date_id, src.player_id, src.format_id, src.country_id, src.rank, src.rating, src.points, src.best_rank, src.loaded_at)
                """,
                'useLegacySql': False,
            }
        }
    )
    
    # Task dependencies: dims before fact
    transform_player >> transform_country >> transform_fact
```

**Tasks** (sequential):
1. `transform_dim_player` — MERGE to upsert player dimension
2. `transform_dim_country` — MERGE to upsert country dimension
3. `transform_fact_batting` — MERGE to upsert fact table (depends on dims above)

---

#### Stage 5: notify_completion
```python
with TaskGroup(group_id='notify_completion', dag=dag) as notify_tg:
    notify_task = PythonOperator(
        task_id='notify_completion',
        python_callable=lambda: print("✓ Cricket analytics pipeline completed successfully!"),
        trigger_rule='all_success',
    )
```

### DAG Dependency Chain
```
ingestion_tg >> processing_tg >> validation_tg >> staging_transformation >> notify_completion
```

### Data Quality Monitoring DAG

**File**: `airflow/dags/data_quality_monitoring_dag.py`

```python
dag_monitoring = DAG(
    'cricket_data_quality_monitoring',
    default_args=default_args,
    description='Monitor data freshness and quality',
    schedule_interval='0 10 * * *',  # 10:00 UTC (4 hours after main pipeline)
    max_active_runs=1,
    tags=['cricket', 'monitoring', 'quality'],
)
```

**Stages**:

```
freshness_checks → completeness_checks → consistency_checks → generate_quality_report
```

- **freshness_checks** — Verify data < 48 hours old in raw and staging
- **completeness_checks** — Null count + minimum 50 records per format
- **consistency_checks** — Compare distinct player_id counts; warn if difference > 5
- **generate_quality_report** — Aggregate all checks; push to XCom

---

## 7. Terraform Module

**Files**: `terraform/main.tf`, `cloud_composer.tf`, `variables.tf`, `outputs.tf`

### Purpose
Infrastructure as Code (IaC) for all GCP resources using Terraform.

### 7.1 Core Infrastructure (main.tf)

#### Google Cloud APIs
```hcl
resource "google_project_service" "required_apis" {
  for_each = toset([
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "dataflow.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudscheduler.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
  ])
  
  project = var.gcp_project_id
  service = each.value
  disable_on_destroy = false
}
```

#### Service Accounts
```hcl
# Dataflow service account
resource "google_service_account" "dataflow_sa" {
  account_id   = "cricket-dataflow-sa"
  display_name = "Cricket Analytics Dataflow Service Account"
  project      = var.gcp_project_id
}

# Dataflow permissions
resource "google_project_iam_member" "dataflow_roles" {
  for_each = toset([
    "roles/bigquery.admin",
    "roles/storage.admin",
    "roles/dataflow.worker",
  ])
  
  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.dataflow_sa.email}"
}

# Cloud Function service account
resource "google_service_account" "cloud_function_sa" {
  account_id   = "cricket-cloud-function-sa"
  display_name = "Cricket Analytics Cloud Function Service Account"
  project      = var.gcp_project_id
}

resource "google_project_iam_member" "cloud_function_roles" {
  for_each = toset([
    "roles/dataflow.admin",
    "roles/storage.objectViewer",
  ])
  
  project = var.gcp_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_function_sa.email}"
}
```

#### Google Cloud Storage
```hcl
resource "google_storage_bucket" "raw_data" {
  name          = "${var.bucket_prefix}-raw-data"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false
  
  lifecycle {
    prevent_destroy = true
  }
  
  versioning {
    enabled = false
  }
}

resource "google_storage_bucket_folder" "batting_folder" {
  bucket = google_storage_bucket.raw_data.name
  name   = "batting/"
}

resource "google_storage_bucket" "dataflow_templates" {
  name          = "${var.bucket_prefix}-dataflow-templates"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false
}

resource "google_storage_bucket" "dataflow_temp" {
  name          = "${var.bucket_prefix}-dataflow-temp"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false
  
  lifecycle {
    ignore_changes = [lifecycle[0].rule[0].delete_storage_class_days]
  }
}
```

#### BigQuery Datasets
```hcl
resource "google_bigquery_dataset" "raw" {
  dataset_id    = "cricket_raw"
  project       = var.gcp_project_id
  location      = var.gcp_region
  description   = "Raw cricket data layer"
  
  default_table_expiration_ms = 7776000000  # 90 days
}

resource "google_bigquery_dataset" "staging" {
  dataset_id = "cricket_staging"
  project    = var.gcp_project_id
  location   = var.gcp_region
  description = "Staging cricket data layer (star schema)"
}

resource "google_bigquery_dataset" "curated" {
  dataset_id = "cricket_curated"
  project    = var.gcp_project_id
  location   = var.gcp_region
  description = "Curated cricket analytics layer"
}
```

#### Artifact Registry
```hcl
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.gcp_region
  repository_id = "cricket-docker"
  description   = "Docker repository for Dataflow Flex Templates"
  format        = "DOCKER"
  project       = var.gcp_project_id
}
```

#### Cloud Run Service
```hcl
resource "google_cloud_run_service" "ingestion" {
  name     = "cricket-ingestion"
  location = var.gcp_region
  project  = var.gcp_project_id
  
  template {
    spec {
      service_account_name = google_service_account.dataflow_sa.email
      
      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/cricket-docker/ingestion:latest"
        
        env {
          name  = "RAPIDAPI_KEY"
          value = var.rapidapi_key
        }
        
        env {
          name  = "GCP_PROJECT"
          value = var.gcp_project_id
        }
      }
    }
  }
}
```

#### Cloud Scheduler
```hcl
resource "google_cloud_scheduler_job" "cricket_ingestion" {
  name        = "cricket-daily-ingestion"
  location    = var.gcp_region
  schedule    = "0 6 * * *"  # 06:00 UTC daily
  time_zone   = "UTC"
  project     = var.gcp_project_id
  description = "Trigger cricket rankings ingestion"
  
  http_target {
    http_method = "POST"
    uri         = "${google_cloud_run_service.ingestion.status[0].url}/"
    
    oidc_token {
      service_account_email = google_service_account.cloud_function_sa.email
    }
  }
}
```

#### Cloud Function
```hcl
resource "google_cloudfunctions2_function" "gcs_dataflow_trigger" {
  name        = "cricket-gcs-dataflow-trigger"
  location    = var.gcp_region
  project     = var.gcp_project_id
  description = "Trigger Dataflow job on new GCS files"
  
  runtime = "python311"
  
  entry_point = "process_batting_file"
  
  source_repository {
    url = "https://github.com/youruser/cricket-analytics-pipeline"
  }
  
  service_config {
    max_instance_count  = 10
    timeout_seconds     = 600
    available_memory_mb = 512
    
    service_account_email = google_service_account.cloud_function_sa.email
    
    environment_variables = {
      GCP_PROJECT                 = var.gcp_project_id
      GCP_REGION                  = var.gcp_region
      DATAFLOW_TEMPLATE_LOCATION  = "gs://${google_storage_bucket.dataflow_templates.name}/batting-pipeline/metadata"
      BQ_DATASET                  = "cricket_raw"
      BQ_TABLE                    = "batting_rankings"
      TEMP_BUCKET                 = google_storage_bucket.dataflow_temp.name
    }
  }
  
  event_trigger {
    event_type = "google.cloud.storage.object.v1.finalized"
    retry_policy = "RETRY_POLICY_UNSPECIFIED"
    
    service_account_email = google_service_account.cloud_function_sa.email
    
    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.raw_data.name
    }
  }
}
```

#### Eventarc Trigger
```hcl
resource "google_eventarc_trigger" "gcs_to_dataflow" {
  name        = "cricket-gcs-trigger"
  location    = var.gcp_region
  project     = var.gcp_project_id
  description = "Route GCS events to Cloud Function"
  
  event_data_content_type = "application/json"
  
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  
  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.raw_data.name
  }
  
  destination {
    cloud_function = google_cloudfunctions2_function.gcs_dataflow_trigger.id
  }
  
  service_account = google_service_account.cloud_function_sa.email
}
```

#### BigQuery Scheduled Query
```hcl
resource "google_bigquery_data_transfer_config" "curated_views" {
  display_name = "cricket-curated-views-refresh"
  project      = var.gcp_project_id
  location     = var.gcp_region
  
  data_source_id       = "scheduled_query"
  schedule             = "every day 08:00"
  destination_dataset_id = google_bigquery_dataset.curated.dataset_id
  
  params = {
    query                                = file("${path.module}/../bigquery/sql/07_create_curated_views.sql")
    destination_table_name_template      = "project:dataset.table"
    write_disposition                    = "WRITE_TRUNCATE"
    partitioning_field                   = ""
  }
  
  service_account_name = google_service_account.dataflow_sa.email
}
```

### 7.2 Cloud Composer (cloud_composer.tf)

```hcl
resource "google_composer_environment" "cricket_airflow" {
  name    = "cricket-analytics-composer"
  region  = var.gcp_region
  project = var.gcp_project_id
  
  config {
    software_config {
      airflow_config_overrides = {
        "core-load_examples" = "False"
      }
      
      pypi_packages = {
        apache-airflow-providers-google   = "10.10.1"
        apache-airflow-providers-apache-beam = "5.3.0"
        google-cloud-storage              = "2.10.0"
        google-cloud-bigquery             = "3.13.0"
        pandas                            = "2.0.3"
        pyyaml                            = "6.0"
        requests                          = "2.31.0"
      }
    }
    
    node_config {
      zone         = var.gcp_zone
      machine_type = var.composer_machine_type
      disk_size_gb = 30
    }
    
    node_count = var.composer_node_count
    
    encryption_config {
      kms_key_name = google_kms_crypto_key.composer_key.id
    }
  }
  
  depends_on = [google_project_service.required_apis]
}
```

#### KMS Encryption
```hcl
resource "google_kms_key_ring" "composer_kr" {
  name     = "cricket-composer-kr"
  location = var.gcp_region
  project  = var.gcp_project_id
}

resource "google_kms_crypto_key" "composer_key" {
  name            = "cricket-composer-key"
  key_ring        = google_kms_key_ring.composer_kr.id
  rotation_period = "7776000s"  # 90 days
}
```

#### DAG Deployment
```hcl
resource "google_storage_bucket_object" "main_dag" {
  name   = "dags/cricket_analytics_dag.py"
  bucket = google_composer_environment.cricket_airflow.storage_config[0].bucket
  source = "${path.module}/../airflow/dags/cricket_analytics_dag.py"
}

resource "google_storage_bucket_object" "monitoring_dag" {
  name   = "dags/data_quality_monitoring_dag.py"
  bucket = google_composer_environment.cricket_airflow.storage_config[0].bucket
  source = "${path.module}/../airflow/dags/data_quality_monitoring_dag.py"
}
```

#### Cloud Monitoring Alerts
```hcl
resource "google_monitoring_alert_policy" "dag_failure" {
  display_name = "Cricket DAG Task Failure"
  combiner     = "OR"
  project      = var.gcp_project_id
  
  conditions {
    display_name = "DAG task failed"
    
    condition_threshold {
      filter          = "resource.type=\"cloud_composer_environment\" AND metric.type=\"composer.googleapis.com/dag_run/failed\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email.name]
}
```

### 7.3 Variables (variables.tf)

```hcl
variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "bucket_prefix" {
  description = "Prefix for GCS bucket names"
  type        = string
}

variable "dataflow_machine_type" {
  description = "Machine type for Dataflow workers"
  type        = string
  default     = "n1-standard-2"
}

variable "dataflow_num_workers" {
  description = "Number of Dataflow workers"
  type        = number
  default     = 2
}

variable "dataflow_max_workers" {
  description = "Max number of Dataflow workers"
  type        = number
  default     = 5
}

variable "rapidapi_key" {
  description = "RapidAPI key for Cricbuzz API"
  type        = string
  sensitive   = true
}

variable "composer_machine_type" {
  description = "Machine type for Composer nodes"
  type        = string
  default     = "n1-standard-4"
}

variable "composer_node_count" {
  description = "Number of Composer nodes"
  type        = number
  default     = 3
}

variable "enable_cloud_composer" {
  description = "Enable Cloud Composer (Airflow)"
  type        = bool
  default     = true
}
```

### 7.4 Outputs (outputs.tf)

```hcl
output "raw_bucket" {
  value = google_storage_bucket.raw_data.name
}

output "dataflow_template_bucket" {
  value = google_storage_bucket.dataflow_templates.name
}

output "cloud_function_url" {
  value = google_cloudfunctions2_function.gcs_dataflow_trigger.service_config[0].uri
}

output "composer_environment_name" {
  value = google_composer_environment.cricket_airflow.name
}

output "airflow_web_ui_url" {
  value = "https://console.cloud.google.com/composer/environments/detail/${var.gcp_region}/${google_composer_environment.cricket_airflow.name}/dags"
}

output "bigquery_raw_dataset" {
  value = google_bigquery_dataset.raw.dataset_id
}

output "bigquery_staging_dataset" {
  value = google_bigquery_dataset.staging.dataset_id
}

output "bigquery_curated_dataset" {
  value = google_bigquery_dataset.curated.dataset_id
}
```

---

## Summary

This module documentation provides:
- **Configuration**: YAML structure and usage
- **Ingestion**: API fetching, CSV generation, GCS upload
- **Cloud Function**: Event-driven triggering, Dataflow orchestration
- **Dataflow**: Apache Beam pipeline, parsing, BigQuery writes
- **BigQuery**: Three-layer data warehouse, schemas, views
- **Airflow**: DAG orchestration, task groups, MERGE operations
- **Terraform**: Complete IaC for all GCP resources

Each module is designed for scalability, idempotency, and observability. The pipeline can process 100–1M+ records daily with automatic scaling and cost efficiency.
