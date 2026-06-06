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
    """Get RapidAPI key from config file."""
    api_key = config.get("apis", {}).get("rapidapi", {}).get("api_key")
    if not api_key:
        raise ValueError("API key not found in config.yaml")
    return api_key

def fetch_rankings(format_type: str, api_key: str, config: dict) -> dict:
    """Fetch rankings for a specific format from Cricbuzz API."""
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

    # Handle both response formats: {"data": {"rank": [...]}} and {"rank": [...]}
    rank_list = data.get("rank", data.get("data", {}).get("rank", []))

    if not rank_list:
        logger.warning(f"No rankings found in response for {format_type}")
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
            logger.warning(f"Failed to parse ranking entry: {e}")
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
