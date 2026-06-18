#!/usr/bin/env python3
"""
Debug: Check what the Cricbuzz API actually returns
"""

import os
import json
import requests

api_key = os.getenv("RAPIDAPI_KEY")
if not api_key:
    print("Error: RAPIDAPI_KEY not set!")
    exit(1)

api_url = "https://cricbuzz-cricket.p.rapidapi.com/stats/v1/rankings/batsmen"
headers = {
    "X-RapidAPI-Key": api_key,
    "X-RapidAPI-Host": "cricbuzz-cricket.p.rapidapi.com",
}

params = {
    "formatType": "test",
    "rankType": "batsmen",
}

print("Calling API...")
response = requests.get(api_url, headers=headers, params=params, timeout=30)
print(f"Status: {response.status_code}")
print()

data = response.json()
print("API Response Structure:")
print(json.dumps(data, indent=2)[:2000])  # First 2000 chars
print()

if "data" in data:
    print("Has 'data' key")
    print(f"Keys in data: {list(data['data'].keys())}")
else:
    print(f"Top-level keys: {list(data.keys())}")
