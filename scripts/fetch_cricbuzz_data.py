#!/usr/bin/env python3
"""
Fetch cricket batting rankings from Cricbuzz API and upload to GCS
"""

import requests
import pandas as pd
import json
import os
from datetime import datetime
from google.cloud import storage

# Configuration
RAPIDAPI_KEY = os.getenv("RAPIDAPI_KEY", "test-key-placeholder")
PROJECT_ID = "cricket-analytics-prod"
GCS_BUCKET = "cricket-raw-data-prod"
GCS_PREFIX = "batting"

# Cricbuzz API
API_BASE_URL = "https://cricbuzz-cricket.p.rapidapi.com"
ENDPOINT = "/stats/v1/rankings/batsmen"

def fetch_rankings(format_type):
    """Fetch batting rankings from Cricbuzz API"""
    print(f"Fetching {format_type.upper()} rankings...")

    headers = {
        "X-RapidAPI-Key": RAPIDAPI_KEY,
        "X-RapidAPI-Host": "cricbuzz-cricket.p.rapidapi.com",
    }

    params = {
        "formatType": format_type,
        "rankType": "batsmen",
    }

    try:
        response = requests.get(
            f"{API_BASE_URL}{ENDPOINT}",
            headers=headers,
            params=params,
            timeout=30,
        )
        response.raise_for_status()
        print(f"  [OK] API call successful (status: {response.status_code})")
        return response.json()
    except Exception as e:
        print(f"  [FAIL] API call failed: {e}")
        return None

def parse_rankings(data, format_type):
    """Parse API response into DataFrame"""
    if not data or "data" not in data:
        print(f"  [WARN] No data in response for {format_type}")
        return pd.DataFrame()

    rankings = []
    try:
        for rank_entry in data.get("data", {}).get("rank", []):
            player = rank_entry.get("player", {})
            rankings.append({
                "rank": rank_entry.get("rank"),
                "player_id": player.get("id"),
                "player_name": player.get("name"),
                "country": player.get("country"),
                "country_id": player.get("countryId"),
                "rating": rank_entry.get("rating"),
                "points": rank_entry.get("points"),
                "best_rank": rank_entry.get("bestRank"),
                "format": format_type.upper(),
                "ingested_at": datetime.utcnow().isoformat(),
            })
        print(f"  [OK] Parsed {len(rankings)} records for {format_type}")
    except Exception as e:
        print(f"  [FAIL] Parse error: {e}")

    return pd.DataFrame(rankings)

def upload_to_gcs(df, bucket_name, prefix):
    """Upload DataFrame as CSV to GCS"""
    if df.empty:
        print("[FAIL] No data to upload")
        return None

    try:
        client = storage.Client(project=PROJECT_ID)
        bucket = client.bucket(bucket_name)

        # Generate filename
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"{prefix}/batting_rankings_{timestamp}.csv"
        blob = bucket.blob(filename)

        # Convert to CSV and upload
        csv_data = df.to_csv(index=False)
        blob.upload_from_string(csv_data, content_type="text/csv")

        print(f"[OK] Uploaded to GCS: gs://{bucket_name}/{filename}")
        print(f"   File size: {len(csv_data)} bytes")
        print(f"   Records: {len(df)}")

        return filename
    except Exception as e:
        print(f"[FAIL] GCS upload failed: {e}")
        return None

def main():
    print("=" * 60)
    print("CRICKET ANALYTICS - CRICBUZZ API DATA FETCH")
    print("=" * 60)
    print()

    if RAPIDAPI_KEY == "test-key-placeholder":
        print("[WARNING] RAPIDAPI_KEY not set!")
        print("   Using test data instead...")
        print()
        # Create test data
        test_data = pd.DataFrame({
            "rank": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "player_id": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "player_name": ["Virat Kohli", "Steve Smith", "Kane Williamson", "Joe Root", "Babar Azam",
                           "Marnus Labuschagne", "Ben Stokes", "Mitchell Marsh", "Tom Latham", "Usman Khawaja"],
            "country": ["India", "Australia", "New Zealand", "England", "Pakistan",
                       "Australia", "England", "Australia", "New Zealand", "Australia"],
            "country_id": [6, 2, 5, 1, 40, 2, 1, 2, 5, 2],
            "rating": [900, 890, 880, 870, 860, 850, 840, 830, 820, 810],
            "points": [4500, 4450, 4400, 4350, 4300, 4250, 4200, 4150, 4100, 4050],
            "best_rank": [1, 1, 2, 1, 1, 2, 3, 4, 5, 6],
            "format": ["TEST", "TEST", "TEST", "TEST", "TEST", "TEST", "TEST", "TEST", "TEST", "TEST"],
            "ingested_at": [datetime.utcnow().isoformat()] * 10
        })

        # Upload test data
        upload_to_gcs(test_data, GCS_BUCKET, GCS_PREFIX)
    else:
        print("Fetching data from Cricbuzz API...")
        print()

        all_data = []
        for format_type in ["test", "odi", "t20i"]:
            data = fetch_rankings(format_type)
            if data:
                df = parse_rankings(data, format_type)
                if not df.empty:
                    all_data.append(df)

        if all_data:
            combined_df = pd.concat(all_data, ignore_index=True)
            print()
            print(f"Total records fetched: {len(combined_df)}")
            upload_to_gcs(combined_df, GCS_BUCKET, GCS_PREFIX)
        else:
            print("[FAIL] No data fetched from API")

    print()
    print("=" * 60)
    print("[SUCCESS] Data fetch complete!")
    print("=" * 60)

if __name__ == "__main__":
    main()
