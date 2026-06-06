# 📥 Data Ingestion: API to GCS Pipeline

**Author**: Satish Mudde | **Date**: 2026-06-07 | **Status**: Complete Ingestion Guide

Complete guide for data ingestion from Cricbuzz API to Google Cloud Storage.

---

## 📋 Overview

| Component | Details | Status |
|-----------|---------|--------|
| **Source** | Cricbuzz API via RapidAPI | ✅ |
| **Formats** | TEST, ODI, T20I | ✅ |
| **Frequency** | Daily @ 06:00 UTC | ✅ |
| **Output** | CSV to GCS | ✅ |
| **Error Handling** | Graceful degradation | ✅ |

---

## 🎯 Purpose

**Fetch batting rankings** from Cricbuzz API for all 3 cricket formats, combine into single CSV, upload to GCS bucket.

---

## 💻 Code: ingestion/fetch_batting_rankings.py

```python
#!/usr/bin/env python3
"""
Fetch ICC Men's Batting Rankings from Cricbuzz API via RapidAPI.
Saves timestamped CSV to GCS bucket.
"""

import sys
import logging
from datetime import datetime
from pathlib import Path

import requests
import pandas as pd
import yaml
from google.cloud import storage

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

CONFIG_PATH = Path(__file__).parent.parent / "config" / "config.yaml"

def load_config():
    """Load configuration from YAML."""
    with open(CONFIG_PATH, "r") as f:
        return yaml.safe_load(f)

def get_api_key(config: dict) -> str:
    """Get RapidAPI key from environment variable."""
    api_key = os.getenv("RAPIDAPI_KEY")
    if not api_key:
        raise ValueError("RAPIDAPI_KEY environment variable not set")
    return api_key

def fetch_rankings(format_type: str, api_key: str, config: dict) -> dict:
    """Fetch rankings for specific format from Cricbuzz API."""
    api_config = config["apis"]["rapidapi"]
    
    headers = {
        "X-RapidAPI-Key": api_key,
        "X-RapidAPI-Host": api_config["host"]
    }
    
    params = {
        "formatType": format_type,
        "rankType": api_config.get("rank_type", "batsmen")
    }
    
    url = f"{api_config['base_url']}{api_config['endpoint']}"
    timeout = api_config.get("request_timeout", 30)
    
    logger.info(f"Fetching {format_type.upper()} batting rankings...")
    response = requests.get(url, headers=headers, params=params, timeout=timeout)
    response.raise_for_status()
    
    return response.json()

def parse_rankings(data: dict, format_type: str) -> pd.DataFrame:
    """Parse API response into DataFrame."""
    if not data:
        logger.warning(f"No data returned for {format_type}")
        return pd.DataFrame()
    
    # Handle both response formats
    rank_list = data.get("rank", data.get("data", {}).get("rank", []))
    
    if not rank_list:
        logger.warning(f"No rankings found for {format_type}")
        return pd.DataFrame()
    
    rankings = []
    for rank_entry in rank_list:
        try:
            rankings.append({
                "rank": int(rank_entry.get("rank", 0)),
                "player_id": rank_entry.get("id", ""),
                "player_name": rank_entry.get("name", ""),
                "country": rank_entry.get("country", ""),
                "country_id": rank_entry.get("countryId", ""),
                "rating": float(rank_entry.get("rating", 0)),
                "points": float(rank_entry.get("points", 0)),
                "best_rank": int(rank_entry.get("bestRank", rank_entry.get("rank", 0))),
                "format": format_type.upper(),
                "ingested_at": datetime.utcnow().isoformat()
            })
        except Exception as e:
            logger.warning(f"Failed to parse entry: {e}")
            continue
    
    return pd.DataFrame(rankings)

def upload_to_gcs(df: pd.DataFrame, bucket: str, prefix: str) -> str:
    """Upload CSV to GCS bucket."""
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"batting_rankings_{timestamp}.csv"
    gcs_path = f"{prefix}{filename}"
    
    # Convert to CSV in memory
    csv_data = df.to_csv(index=False)
    
    # Upload to GCS
    client = storage.Client()
    bucket_obj = client.bucket(bucket)
    blob = bucket_obj.blob(gcs_path)
    
    logger.info(f"Uploading to gs://{bucket}/{gcs_path}")
    blob.upload_from_string(csv_data, content_type="text/csv")
    
    logger.info(f"Successfully uploaded {len(df)} records")
    return f"gs://{bucket}/{gcs_path}"

def main():
    """Main execution flow."""
    try:
        config = load_config()
        api_key = get_api_key(config)
        
        all_data = []
        
        # Fetch rankings for all formats
        for format_type in config["apis"]["formats"]:
            try:
                raw_data = fetch_rankings(format_type, api_key, config)
                df = parse_rankings(raw_data, format_type)
                
                if not df.empty:
                    all_data.append(df)
                    logger.info(f"Parsed {len(df)} {format_type.upper()} rankings")
            
            except requests.RequestException as e:
                logger.error(f"API request failed for {format_type}: {e}")
                continue
        
        if not all_data:
            logger.error("No data fetched for any format")
            return 1
        
        # Combine all formats
        combined_df = pd.concat(all_data, ignore_index=True)
        logger.info(f"Total records: {len(combined_df)}")
        
        # Upload to GCS
        gcs_path = upload_to_gcs(
            combined_df,
            config["gcs"]["raw_bucket"],
            config["gcs"]["raw_prefix"]
        )
        logger.info(f"Pipeline complete. Data available at: {gcs_path}")
        
        return 0
    
    except Exception as e:
        logger.error(f"Pipeline failed: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
```

---

## 📋 Requirements: ingestion/requirements.txt

```
requests
pandas
pyyaml
google-cloud-storage
```

---

## 🚀 Execution

### Manual Execution

```bash
# Set API key
export RAPIDAPI_KEY="your-api-key-here"

# Run script
cd ingestion
python fetch_batting_rankings.py

# Expected output:
# 2026-06-07 10:00:00 - INFO - Fetching TEST batting rankings...
# 2026-06-07 10:00:02 - INFO - Parsed 500 TEST rankings
# 2026-06-07 10:00:03 - INFO - Fetching ODI batting rankings...
# 2026-06-07 10:00:05 - INFO - Parsed 450 ODI rankings
# 2026-06-07 10:00:06 - INFO - Fetching T20I batting rankings...
# 2026-06-07 10:00:08 - INFO - Parsed 400 T20I rankings
# 2026-06-07 10:00:09 - INFO - Total records: 1350
# 2026-06-07 10:00:12 - INFO - Successfully uploaded 1350 records
```

### Scheduled Execution (Cloud Scheduler)

Via Cloud Scheduler (Terraform):
```hcl
resource "google_cloud_scheduler_job" "ingestion" {
  name             = "cricket-daily-ingestion"
  schedule         = var.ingestion_schedule  # "0 6 * * *"
  time_zone        = "UTC"
  attempt_deadline = "600s"
  
  http_target {
    http_method = "POST"
    uri         = google_cloudrun_service.ingestion.status[0].url
    
    oidc_token {
      service_account_email = google_service_account.cloud_function_sa.email
    }
  }
}
```

---

## 📊 Data Flow

```
Cricbuzz API
    ↓
fetch_rankings() - 3 HTTP requests (1 per format)
    ├─ TEST: ~500 records
    ├─ ODI:  ~450 records
    └─ T20I: ~400 records
    
    ↓
parse_rankings() - For each format:
    ├─ Extract ranking list from JSON
    ├─ For each player:
    │   ├─ Map API fields to expected columns
    │   ├─ Type casting (int, float)
    │   └─ Add format & timestamp
    └─ Create DataFrame
    
    ↓
pd.concat() - Combine all formats
    └─ Single DataFrame: ~1350 rows
    
    ↓
upload_to_gcs() - Serialize & upload
    ├─ Convert DataFrame to CSV
    ├─ Generate timestamp filename
    └─ Upload to gs://bucket/batting/
    
    ↓
CSV in GCS (Triggers Cloud Function)
```

---

## 📋 Output CSV Format

**Filename**: `batting_rankings_YYYYMMDD_HHMMSS.csv`

**Columns**:
1. rank (INT)
2. player_id (STRING)
3. player_name (STRING)
4. country (STRING)
5. country_id (STRING)
6. rating (FLOAT)
7. points (FLOAT)
8. best_rank (INT)
9. format (STRING) - TEST, ODI, or T20I
10. ingested_at (TIMESTAMP) - UTC

**Example**:
```csv
rank,player_id,player_name,country,country_id,rating,points,best_rank,format,ingested_at
1,12345,Virat Kohli,India,IND,912.0,9120,1,TEST,2026-06-07T06:00:00
2,67890,Steve Smith,Australia,AUS,890.0,8900,1,TEST,2026-06-07T06:00:00
```

---

## 🛡️ Error Handling

### Missing API Key

```
Error: RAPIDAPI_KEY environment variable not set

Solution:
export RAPIDAPI_KEY="your-key-here"
python fetch_batting_rankings.py
```

### API Rate Limit

```
Error: HTTP 429 Too Many Requests

Solution:
- Check RapidAPI plan at https://rapidapi.com/settings/apps
- Wait for monthly reset
- Consider upgrading plan
```

### One Format Fails

```
Error: API request failed for T20I

Result: ✅ Graceful - Script continues
- TEST & ODI data still uploaded
- T20I skipped with error logged
- Job considered success (1 out of 3 formats)
```

---

## 📊 Monitoring

### Check GCS Upload

```bash
gsutil ls -lh gs://cricket-raw-data-PROJECT_ID/batting/
```

### Verify CSV Content

```bash
gsutil cp gs://cricket-raw-data-PROJECT_ID/batting/batting_rankings_*.csv - | head -20
```

### View Logs

```bash
gcloud logging read "resource.type=cloud_run_revision" \
  --limit 50 --format json
```

---

## ✅ Checklist

- [ ] RAPIDAPI_KEY environment variable set
- [ ] config/config.yaml has correct API endpoint
- [ ] GCS bucket exists and is accessible
- [ ] Service account has Storage Writer role
- [ ] Script runs without errors locally
- [ ] CSV uploaded to GCS successfully
- [ ] Cloud Scheduler job created for daily execution

---

**Status**: ✅ Data Ingestion Complete  
**Frequency**: Daily @ 06:00 UTC  
**Output**: CSV to GCS  
**Last Updated**: 2026-06-07  

Reliable data ingestion pipeline! 📥
