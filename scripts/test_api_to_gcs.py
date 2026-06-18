#!/usr/bin/env python3
"""
Test: Cricbuzz API -> CSV -> GCS Upload Flow
Simple diagnostic script to verify each step
"""

import os
import sys
import json
from datetime import datetime

print("=" * 70)
print("TEST: API FETCH -> GCS UPLOAD FLOW")
print("=" * 70)
print()

# Step 1: Check RAPIDAPI_KEY
print("[1/5] Checking RAPIDAPI_KEY...")
api_key = os.getenv("RAPIDAPI_KEY")
if api_key:
    print(f"  [OK] RAPIDAPI_KEY found: {api_key[:20]}...{api_key[-5:]}")
else:
    print("  [FAIL] RAPIDAPI_KEY not set!")
    print("  Set it with: export RAPIDAPI_KEY='your-key-here'")
    sys.exit(1)

# Step 2: Check imports
print()
print("[2/5] Checking Python imports...")
try:
    import requests
    print("  [OK] requests imported")
except ImportError as e:
    print(f"  [FAIL] requests: {e}")
    sys.exit(1)

try:
    import pandas as pd
    print("  [OK] pandas imported")
except ImportError as e:
    print(f"  [FAIL] pandas: {e}")
    sys.exit(1)

try:
    from google.cloud import storage
    print("  [OK] google.cloud.storage imported")
except ImportError as e:
    print(f"  [FAIL] google.cloud.storage: {e}")
    sys.exit(1)

# Step 3: Test API Call
print()
print("[3/5] Testing Cricbuzz API call...")
api_url = "https://cricbuzz-cricket.p.rapidapi.com/stats/v1/rankings/batsmen"
headers = {
    "X-RapidAPI-Key": api_key,
    "X-RapidAPI-Host": "cricbuzz-cricket.p.rapidapi.com",
}

try:
    params = {
        "formatType": "test",
        "rankType": "batsmen",
    }
    response = requests.get(api_url, headers=headers, params=params, timeout=30)
    response.raise_for_status()
    print(f"  [OK] API call successful (status: {response.status_code})")

    data = response.json()
    if data and "data" in data:
        rankings = data.get("data", {}).get("rank", [])
        print(f"  [OK] Received {len(rankings)} records")

        if rankings:
            first_player = rankings[0].get("player", {})
            print(f"  [OK] Sample: {first_player.get('name')} ({first_player.get('country')})")
    else:
        print("  [WARN] Unexpected API response structure")

except requests.exceptions.RequestException as e:
    print(f"  [FAIL] API request error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"  [FAIL] Unexpected error: {e}")
    sys.exit(1)

# Step 4: Create CSV
print()
print("[4/5] Creating CSV from API data...")
try:
    all_data = []

    for format_type in ["test", "odi", "t20i"]:
        params = {
            "formatType": format_type,
            "rankType": "batsmen",
        }
        response = requests.get(api_url, headers=headers, params=params, timeout=30)
        response.raise_for_status()

        data = response.json()
        for rank_entry in data.get("data", {}).get("rank", []):
            player = rank_entry.get("player", {})
            all_data.append({
                "rank": rank_entry.get("rank"),
                "player_id": player.get("id"),
                "player_name": player.get("name"),
                "country": player.get("country"),
                "rating": rank_entry.get("rating"),
                "format": format_type.upper(),
                "ingested_at": datetime.utcnow().isoformat(),
            })

    df = pd.DataFrame(all_data)
    csv_data = df.to_csv(index=False)

    print(f"  [OK] Created CSV with {len(df)} total records")
    print(f"  [OK] CSV size: {len(csv_data)} bytes")

except Exception as e:
    print(f"  [FAIL] CSV creation error: {e}")
    sys.exit(1)

# Step 5: Upload to GCS
print()
print("[5/5] Uploading to GCS bucket...")
try:
    client = storage.Client(project="cricket-analytics-prod")
    bucket = client.bucket("cricket-raw-data-prod")

    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"batting/test_batting_rankings_{timestamp}.csv"
    blob = bucket.blob(filename)

    blob.upload_from_string(csv_data, content_type="text/csv")

    print(f"  [OK] Uploaded to GCS!")
    print(f"  [OK] Path: gs://cricket-raw-data-prod/{filename}")

except Exception as e:
    print(f"  [FAIL] GCS upload error: {e}")
    print(f"       Make sure you have GCS credentials configured")
    print(f"       Run: gcloud auth application-default login")
    sys.exit(1)

print()
print("=" * 70)
print("[SUCCESS] API -> CSV -> GCS flow verified!")
print("=" * 70)
print()
print("Next: Check GCS bucket with:")
print("  gsutil ls -lh gs://cricket-raw-data-prod/batting/")
