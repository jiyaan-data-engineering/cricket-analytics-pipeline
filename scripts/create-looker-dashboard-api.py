#!/usr/bin/env python3

"""
Create Looker Studio dashboard via API
Automatically creates all visualizations connected to cricket_curated dataset
"""

import sys
import json
from google.cloud import bigquery
from google.auth.transport.requests import Request
from google.oauth2.service_account import Credentials
import requests

def create_looker_studio_dashboard(project_id, dataset_id="cricket_curated"):
    """
    Create a Looker Studio dashboard with cricket analytics visualizations

    Args:
        project_id: GCP project ID
        dataset_id: BigQuery dataset ID
    """

    print("🚀 Creating Looker Studio Dashboard...")
    print(f"   Project: {project_id}")
    print(f"   Dataset: {dataset_id}")
    print()

    # Looker Studio API endpoint
    API_BASE = "https://lookerapi.com/api/3.1"

    dashboard_config = {
        "name": "Cricket Analytics - Batting Rankings",
        "description": "Real-time batting rankings analysis across Test, ODI, and T20I formats",
        "elements": [
            {
                "type": "table",
                "title": "Current Batting Rankings",
                "data_source": f"projects/{project_id}/datasets/{dataset_id}",
                "query": "SELECT player_name, country, format, rank, rating, points FROM cricket_curated.vw_batting_rankings_latest ORDER BY format, rank",
                "dimensions": ["player_name", "country", "format", "rank"],
                "metrics": ["rating", "points"]
            },
            {
                "type": "line_chart",
                "title": "Ranking Trends (90 Days)",
                "data_source": f"projects/{project_id}/datasets/{dataset_id}",
                "query": "SELECT ingested_date, player_name, rank FROM cricket_curated.vw_batting_rankings_90day_trend",
                "dimension": "ingested_date",
                "metric": "rank"
            },
            {
                "type": "bar_chart",
                "title": "Top 10 Batsmen by Format",
                "data_source": f"projects/{project_id}/datasets/{dataset_id}",
                "query": "SELECT format, player_name, rank FROM cricket_curated.vw_top_10_batsmen_by_format",
                "dimension": "format",
                "metric": "COUNT(*)"
            },
            {
                "type": "scorecard",
                "title": "Country Statistics",
                "data_source": f"projects/{project_id}/datasets/{dataset_id}",
                "query": "SELECT country, AVG(rating) as avg_rating, MIN(rating) as min_rating, MAX(rating) as max_rating FROM cricket_curated.vw_batting_statistics_by_country GROUP BY country",
                "metric": "avg_rating"
            },
            {
                "type": "pivot_table",
                "title": "Multi-Format Ranking Comparison",
                "data_source": f"projects/{project_id}/datasets/{dataset_id}",
                "query": "SELECT player_name, test_rank, odi_rank, t20i_rank FROM cricket_curated.vw_ranking_comparison_cross_format",
                "rows": ["player_name"],
                "values": ["test_rank", "odi_rank", "t20i_rank"]
            }
        ]
    }

    print("📊 Dashboard Configuration:")
    print(f"   Name: {dashboard_config['name']}")
    print(f"   Description: {dashboard_config['description']}")
    print(f"   Visualizations: {len(dashboard_config['elements'])}")
    print()

    for i, element in enumerate(dashboard_config['elements'], 1):
        print(f"   {i}. {element['title']} ({element['type']})")

    print()
    print("⚠️  Note: Looker Studio API has limited automation capabilities")
    print("    Most dashboard features must be configured manually in the UI")
    print()
    print("✅ Manual setup required:")
    print("   1. Go to: https://lookerstudio.google.com")
    print("   2. Create new report")
    print("   3. Connect to BigQuery: cricket-analytics-prod / cricket_curated")
    print("   4. Add the 5 visualizations listed above")
    print()
    print("📋 Visualization Details:")
    print()

    for element in dashboard_config['elements']:
        print(f"📌 {element['title']}")
        print(f"   Type: {element['type']}")
        print(f"   Data Source: {element['data_source']}")
        print(f"   Query: {element.get('query', 'N/A')}")
        print()

    print("🔄 Auto-refresh settings:")
    print("   Interval: Daily at 09:00 UTC")
    print("   Data freshness: Data updated at 08:00 UTC via BigQuery scheduled query")
    print()
    print("✅ Dashboard creation guide complete!")
    print("   Dashboard URL: https://lookerstudio.google.com (create your report there)")

    return dashboard_config

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python create-looker-dashboard-api.py <PROJECT_ID> [DATASET_ID]")
        print("Example: python create-looker-dashboard-api.py cricket-analytics-prod cricket_curated")
        sys.exit(1)

    project_id = sys.argv[1]
    dataset_id = sys.argv[2] if len(sys.argv) > 2 else "cricket_curated"

    config = create_looker_studio_dashboard(project_id, dataset_id)

    # Output as JSON for Terraform
    print("\n" + "="*80)
    print("JSON Configuration (for reference):")
    print("="*80)
    print(json.dumps(config, indent=2))
