# End-to-End Cricket Analytics Pipeline Flow 🏏

## 📊 Complete Data Journey

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    CRICKET ANALYTICS PIPELINE                             │
│                         END-TO-END FLOW                                   │
└──────────────────────────────────────────────────────────────────────────┘

                              DAY TIMELINE
        06:00 UTC                                          ONGOING
           ↓                                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 1: SCHEDULING TRIGGER                                         ║
    ║  ─────────────────────────────                                      ║
    ║  • Cloud Scheduler fires at 06:00 UTC                               ║
    ║  • Sends HTTP POST request                                          ║
    ║  • Triggers Cloud Run/Cloud Function                                ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 2: DATA INGESTION (1-2 minutes)                               ║
    ║  ────────────────────────────────────                               ║
    ║  • Cloud Run container starts                                       ║
    ║  • Calls Cricbuzz API via RapidAPI                                  ║
    ║    ├─ /stats/v1/rankings/batsmen?formatType=test                   ║
    ║    ├─ /stats/v1/rankings/batsmen?formatType=odi                    ║
    ║    └─ /stats/v1/rankings/batsmen?formatType=t20i                   ║
    ║  • Fetches ~300-500 records (3 formats × 100+ players)             ║
    ║  • Parses JSON response                                             ║
    ║  • Converts to Pandas DataFrame                                     ║
    ║  • Adds metadata (ingested_at, source_file)                         ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 3: UPLOAD TO GCS (1 minute)                                   ║
    ║  ──────────────────────────                                         ║
    ║  • File: batting_rankings_2026-06-14_06-15-32.csv                   ║
    ║  • Location: gs://cricket-analytics-raw-data/batting/               ║
    ║  • Columns: rank, player_id, player_name, country, rating,         ║
    ║             points, best_rank, format, ingested_at, source_file    ║
    ║  • Size: ~50-100 KB                                                 ║
    ║  ✅ GCS object finalization event triggered                         ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 4: EVENT-DRIVEN TRIGGER (Immediate)                           ║
    ║  ──────────────────────────────────────                             ║
    ║  • Eventarc detects GCS finalization event                          ║
    ║  • Invokes Cloud Function 2nd Gen                                   ║
    ║  • Function: cricket-gcs-dataflow-trigger                           ║
    ║  • Receives: bucket name, file name, event type                     ║
    ║  • Validates: file in batting/ prefix and ends with .csv            ║
    ║  • Creates Dataflow FlexTemplate request                            ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 5: DATAFLOW PROCESSING (5-10 minutes)                         ║
    ║  ───────────────────────────────────────                            ║
    ║                                                                      ║
    ║  Apache Beam Pipeline:                                              ║
    ║  ┌────────────────────────────────────────────────────────┐        ║
    ║  │ 1. Read CSV from GCS                                  │        ║
    ║  │    └─ Input: gs://cricket-analytics-raw-data/...     │        ║
    ║  │                                                        │        ║
    ║  │ 2. Parse Each Line                                   │        ║
    ║  │    └─ CSV → Dictionary                               │        ║
    ║  │    └─ Handle headers, empty lines                    │        ║
    ║  │                                                        │        ║
    ║  │ 3. Type Conversion & Validation                      │        ║
    ║  │    └─ rank: INT64                                    │        ║
    ║  │    └─ rating, points: FLOAT64                        │        ║
    ║  │    └─ ingested_at: TIMESTAMP                         │        ║
    ║  │    └─ Other fields: STRING                           │        ║
    ║  │    └─ Handle NULL values                             │        ║
    ║  │    └─ Log & skip malformed records                   │        ║
    ║  │                                                        │        ║
    ║  │ 4. Data Quality Checks                               │        ║
    ║  │    └─ Validate schema match                          │        ║
    ║  │    └─ Check required fields not NULL                 │        ║
    ║  │    └─ Verify data types                              │        ║
    ║  │    └─ Range checks (rank 1-500, rating 0-1000)       │        ║
    ║  │                                                        │        ║
    ║  │ 5. Add Metadata                                      │        ║
    ║  │    └─ source_file: filename                          │        ║
    ║  │    └─ processing_timestamp: now()                    │        ║
    ║  │                                                        │        ║
    ║  │ 6. Write to BigQuery (APPEND)                        │        ║
    ║  │    └─ Destination: cricket_raw.batting_rankings      │        ║
    ║  │    └─ Write disposition: APPEND                      │        ║
    ║  │    └─ Create disposition: CREATE_IF_NEEDED           │        ║
    ║  │                                                        │        ║
    ║  │ Result: ✅ ~300-500 records inserted                 │        ║
    ║  └────────────────────────────────────────────────────────┘        ║
    ║                                                                      ║
    ║  Dataflow Configuration:                                            ║
    ║  • Template: Flex Template (Docker image)                           ║
    ║  • Machine type: n1-standard-2                                      ║
    ║  • Min workers: 2, Max workers: 5 (auto-scale)                      ║
    ║  • Staging bucket: cricket-analytics-dataflow-templates             ║
    ║  • Temp bucket: cricket-analytics-dataflow-temp                     ║
    ║  • Region: us-central1                                              ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 6: RAW LAYER STORAGE (Already in BigQuery)                    ║
    ║  ──────────────────────────────────────────────                     ║
    ║                                                                      ║
    ║  Table: cricket_raw.batting_rankings                                ║
    ║  ┌────────────────────────────────────────────────────────┐        ║
    ║  │ Column          │ Type      │ Value Example            │        ║
    ║  ├─────────────────┼───────────┼──────────────────────────┤        ║
    ║  │ rank            │ INT64     │ 1                        │        ║
    ║  │ player_id       │ STRING    │ "babar"                  │        ║
    ║  │ player_name     │ STRING    │ "Babar Azam"             │        ║
    ║  │ country         │ STRING    │ "Pakistan"               │        ║
    ║  │ country_id      │ STRING    │ "PAK"                    │        ║
    ║  │ rating          │ FLOAT64   │ 865.0                    │        ║
    ║  │ points          │ FLOAT64   │ 865.0                    │        ║
    ║  │ best_rank       │ INT64     │ 1                        │        ║
    ║  │ format          │ STRING    │ "test"/"odi"/"t20i"      │        ║
    ║  │ ingested_at     │ TIMESTAMP │ 2026-06-14 06:15:32 UTC  │        ║
    ║  │ source_file     │ STRING    │ "batting_rankings_2...   │        ║
    ║  └────────────────────────────────────────────────────────┘        ║
    ║                                                                      ║
    ║  Properties:                                                        ║
    ║  • Partitioned by: DATE(ingested_at)                                ║
    ║  • Clustered by: format, country                                    ║
    ║  • Retention: 90 days (auto-delete)                                 ║
    ║  • ✅ ~300-500 NEW records inserted                                 ║
    ║  • Total records after first run: ~300-500                          ║
    ║  • After 30 days: ~9,000-15,000 records                             ║
    ║  • After 90 days: Starts auto-deleting oldest data                  ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 7: STAGING LAYER TRANSFORMATION (Real-time via View)          ║
    ║  ──────────────────────────────────────────────────────             ║
    ║                                                                      ║
    ║  Dimension Tables (SCD Type 1 - Current values only):               ║
    ║                                                                      ║
    ║  dim_player (cricket_staging)                                       ║
    ║  ┌──────────────────────────────────────────┐                       ║
    ║  │ player_id  │ player_name   │ country_id │                       ║
    ║  ├────────────┼───────────────┼────────────┤                       ║
    ║  │ babar      │ Babar Azam    │ PAK        │                       ║
    ║  │ smith      │ Steve Smith   │ AUS        │                       ║
    ║  │ kohli      │ Virat Kohli   │ IND        │                       ║
    ║  │ ...        │ ...           │ ...        │                       ║
    ║  └──────────────────────────────────────────┘                       ║
    ║  Strategy: MERGE (upsert) - updates names if changed                ║
    ║                                                                      ║
    ║  dim_country (cricket_staging)                                      ║
    ║  ┌──────────────────────────┐                                       ║
    ║  │ country_code │ country   │                                       ║
    ║  ├──────────────┼───────────┤                                       ║
    ║  │ PAK          │ Pakistan  │                                       ║
    ║  │ IND          │ India     │                                       ║
    ║  │ AUS          │ Australia │                                       ║
    ║  │ ...          │ ...       │                                       ║
    ║  └──────────────────────────┘                                       ║
    ║  Strategy: MERGE - adds new countries                               ║
    ║                                                                      ║
    ║  dim_format (cricket_staging)                                       ║
    ║  ┌──────────────┐                                                   ║
    ║  │ format │ name    │                                               ║
    ║  ├────────┼─────────┤                                               ║
    ║  │ 1      │ TEST    │                                               ║
    ║  │ 2      │ ODI     │                                               ║
    ║  │ 3      │ T20I    │                                               ║
    ║  └────────┴─────────┘                                               ║
    ║  Strategy: Static (no changes needed)                               ║
    ║                                                                      ║
    ║  dim_date (cricket_staging)                                         ║
    ║  ┌────────────┐                                                     ║
    ║  │ 2026-06-14 │ (spine for all dates 2015-2034)                    ║
    ║  └────────────┘                                                     ║
    ║  Strategy: Pre-generated static table                               ║
    ║                                                                      ║
    ║  fact_batting_rankings (cricket_staging)                            ║
    ║  ┌─────────────────────────────────────────────────────────────┐  ║
    ║  │ fact_id    │ player_id │ format │ country │ rank │ rating   │  ║
    ║  ├────────────┼───────────┼────────┼─────────┼──────┼──────────┤  ║
    ║  │ 20260614-1 │ babar     │ 1      │ PAK     │ 1    │ 865.0    │  ║
    ║  │ 20260614-2 │ smith     │ 1      │ AUS     │ 2    │ 860.0    │  ║
    ║  │ ...        │ ...       │ ...    │ ...     │ ...  │ ...      │  ║
    ║  └─────────────────────────────────────────────────────────────┘  ║
    ║  Strategy: MERGE (upsert by fact_id)                               ║
    ║  Partitioned by: DATE(loaded_at)                                   ║
    ║  ✅ ~300-500 NEW fact records inserted                              ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 8: CURATED LAYER VIEWS (Instant - Pre-computed)               ║
    ║  ───────────────────────────────────────────────                    ║
    ║                                                                      ║
    ║  These are SQL views - automatically updated when facts change:    ║
    ║                                                                      ║
    ║  vw_batting_rankings_latest                                         ║
    ║  → Latest rank/rating per player+format (TODAY)                    ║
    ║  ┌─────────────────────────────────────────────────────────────┐  ║
    ║  │ player_name │ country │ format │ rank │ rating │ points     │  ║
    ║  ├─────────────┼─────────┼────────┼──────┼────────┼────────────┤  ║
    ║  │ Babar Azam  │ PAK     │ TEST   │ 1    │ 865.0  │ 865.0      │  ║
    ║  │ Babar Azam  │ PAK     │ ODI    │ 1    │ 875.0  │ 875.0      │  ║
    ║  │ Babar Azam  │ PAK     │ T20I   │ 1    │ 880.0  │ 880.0      │  ║
    ║  └─────────────────────────────────────────────────────────────┘  ║
    ║                                                                      ║
    ║  vw_batting_rankings_90day_trend                                    ║
    ║  → Rankings over 90 days with RANK CHANGE calculation             ║
    ║  ┌──────────────────────────────────────────────────────────────┐ ║
    ║  │ player_name │ date       │ rank │ prev_rank │ rank_change    │ ║
    ║  ├─────────────┼────────────┼──────┼───────────┼────────────────┤ ║
    ║  │ Babar Azam  │ 2026-06-14 │ 1    │ 1         │ 0 (same)       │ ║
    ║  │ Babar Azam  │ 2026-06-13 │ 1    │ 2         │ +1 (improved)  │ ║
    ║  │ Babar Azam  │ 2026-06-12 │ 2    │ 3         │ +1 (improved)  │ ║
    ║  └──────────────────────────────────────────────────────────────┘ ║
    ║                                                                      ║
    ║  vw_top_10_batsmen_by_format                                        ║
    ║  → Top 10 players per format (with all 4 dimensions joined)        ║
    ║                                                                      ║
    ║  vw_batting_statistics_by_country                                   ║
    ║  → Country aggregates: avg/min/max rating, player counts           ║
    ║  ┌────────────────────────────────────────────────────────┐       ║
    ║  │ country   │ player_count │ avg_rating │ max_rating     │       ║
    ║  ├───────────┼──────────────┼────────────┼────────────────┤       ║
    ║  │ Pakistan  │ 5            │ 872.0      │ 880.0          │       ║
    ║  │ Australia │ 4            │ 865.0      │ 870.0          │       ║
    ║  │ India     │ 3            │ 870.0      │ 875.0          │       ║
    ║  └────────────────────────────────────────────────────────┘       ║
    ║                                                                      ║
    ║  vw_ranking_comparison_cross_format                                 ║
    ║  → One row per player: test_rank, odi_rank, t20i_rank             ║
    ║  ┌──────────────────────────────────────────────────────────┐     ║
    ║  │ player_name │ test_rank │ odi_rank │ t20i_rank          │     ║
    ║  ├─────────────┼───────────┼──────────┼────────────────────┤     ║
    ║  │ Babar Azam  │ 1         │ 1        │ 1                  │     ║
    ║  │ Steve Smith │ 2         │ 5        │ 15                 │     ║
    ║  └──────────────────────────────────────────────────────────┘     ║
    ║                                                                      ║
    ║  ✅ All views instant - no additional processing needed            ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 9: ANALYTICS & VISUALIZATION (Ongoing)                        ║
    ║  ───────────────────────────────────────────                        ║
    ║                                                                      ║
    ║  Option 1: Looker Studio Dashboard                                  ║
    ║  ┌──────────────────────────────────────────────────────────────┐  ║
    ║  │  Cricket Batting Rankings Analytics                          │  ║
    ║  │  ┌──────────────┐  ┌──────────────────────────────────────┐ │  ║
    ║  │  │Rankings by   │  │      Top 5 Players by Rating        │ │  ║
    ║  │  │  Format      │  │      (Bar Chart)                    │ │  ║
    ║  │  │  (Table)     │  │                                      │ │  ║
    ║  │  └──────────────┘  └──────────────────────────────────────┘ │  ║
    ║  │  ┌──────────────────────────────────────────────────────────┐ │  ║
    ║  │  │    Country Performance (Cards)                           │ │  ║
    ║  │  │    Avg Rating | Top Player | Total Players              │ │  ║
    ║  │  └──────────────────────────────────────────────────────────┘ │  ║
    ║  │  ┌─────────────────┐  ┌──────────────────────────────────┐   │  ║
    ║  │  │ Format Distrib  │  │ Rating Distribution (Histogram)  │   │  ║
    ║  │  │ (Pie Chart)     │  │                                  │   │  ║
    ║  │  └─────────────────┘  └──────────────────────────────────┘   │  ║
    ║  └──────────────────────────────────────────────────────────────┘  ║
    ║                                                                      ║
    ║  Option 2: Custom SQL Queries (BigQuery)                            ║
    ║  Option 3: Data Studio, Tableau, PowerBI (any BI tool)              ║
    ║  Option 4: Machine Learning (Vertex AI)                             ║
    ║                                                                      ║
    ║  ✅ REAL-TIME: Views update as new data arrives                     ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
    ╔═════════════════════════════════════════════════════════════════════╗
    ║  STEP 10: MONITORING & ALERTS (Ongoing)                             ║
    ║  ────────────────────────────────────────                           ║
    ║                                                                      ║
    ║  Cloud Logging - All pipeline activity:                             ║
    ║  ✅ Cloud Scheduler job started                                     ║
    ║  ✅ Cloud Run container launched                                    ║
    ║  ✅ API calls logged (300-500 records fetched)                      ║
    ║  ✅ CSV uploaded to GCS                                             ║
    ║  ✅ GCS finalization event triggered                                ║
    ║  ✅ Cloud Function invoked                                          ║
    ║  ✅ Dataflow job launched (job ID: xxxxx)                           ║
    ║  ✅ Dataflow processing started                                     ║
    ║  ✅ Records read: 300-500                                           ║
    ║  ✅ Records valid: 300-500                                          ║
    ║  ✅ Records failed: 0                                               ║
    ║  ✅ BigQuery insert completed                                       ║
    ║  ✅ Dataflow job finished (duration: 5-10 min)                      ║
    ║  ✅ Pipeline execution complete                                     ║
    ║                                                                      ║
    ║  BigQuery Monitoring:                                               ║
    ║  📊 cricket_raw.batting_rankings: +300-500 rows today              ║
    ║  📊 Total records after 1 day: 300-500                              ║
    ║  📊 Total records after 30 days: 9,000-15,000                       ║
    ║  📊 Total records after 90 days: 27,000-45,000 (then starts delete) ║
    ║                                                                      ║
    ║  Alerts:                                                            ║
    ║  🔴 IF: Pipeline fails                                              ║
    ║      → Alert in Cloud Logging                                       ║
    ║      → Check: API key, GCS permissions, BigQuery quota              ║
    ║                                                                      ║
    ║  🟡 IF: Data quality issue                                          ║
    ║      → Check: Schema mismatch, NULL values, invalid types           ║
    ║      → Review: Dataflow logs                                        ║
    ╚═════════════════════════════════════════════════════════════════════╝
                                  ↓
                    ⏰ REPEAT DAILY AT 06:00 UTC ⏰
```

---

## ⏱️ **Timeline Breakdown**

| Step | Time | Activity |
|------|------|----------|
| **1** | 06:00:00 | Cloud Scheduler triggers |
| **2** | 06:00-06:02 | Cloud Run ingests API data |
| **3** | 06:02-06:03 | CSV uploaded to GCS |
| **4** | 06:03 (instant) | Cloud Function triggered |
| **5** | 06:03-06:13 | Dataflow processes CSV |
| **6** | 06:13 | Data written to BigQuery |
| **7** | 06:13 (instant) | Staging dimensions updated |
| **8** | 06:13 (instant) | Curated views auto-updated |
| **9** | 06:13+ | Dashboard reflects new data |
| **10** | Ongoing | Monitoring tracks execution |

**Total Time:** ~13 minutes per day  
**Data Freshness:** Daily (24-hour latency acceptable for cricket rankings)

---

## 📊 **Data Movement Example**

### Raw Data → Staging → Curated

**EXAMPLE:** When Babar Azam's ranking updates

```
Step 1: API Response (Cricbuzz)
{
  "formatType": "test",
  "players": [
    {
      "rank": 1,
      "player": {"id": "babar", "name": "Babar Azam", "country": "Pakistan"},
      "rating": 865,
      "points": 865
    },
    ...
  ]
}

        ↓ (Dataflow parses + validates)

Step 2: Raw Table Insert
cricket_raw.batting_rankings
  ├─ rank: 1
  ├─ player_id: "babar"
  ├─ player_name: "Babar Azam"
  ├─ country: "Pakistan"
  ├─ rating: 865.0
  ├─ format: "test"
  └─ ingested_at: 2026-06-14 06:15:32 UTC

        ↓ (MERGE statement runs)

Step 3: Staging Dimensions Updated
cricket_staging.dim_player
  ├─ player_id: "babar"
  ├─ player_name: "Babar Azam" (UPDATEDif changed)
  └─ country_id: "PAK"

cricket_staging.dim_country
  └─ "PAK" → "Pakistan"

cricket_staging.fact_batting_rankings
  ├─ fact_id: "20260614-babar-1"
  ├─ player_id: "babar"
  ├─ rank: 1
  ├─ rating: 865.0
  └─ format_id: 1

        ↓ (Views auto-join dimensions)

Step 4: Curated Views Updated (Instant)
vw_batting_rankings_latest
  ├─ player_name: "Babar Azam"
  ├─ country: "Pakistan"
  ├─ format: "TEST"
  ├─ rank: 1
  └─ rating: 865.0

vw_batting_rankings_90day_trend
  ├─ prev_rank: 1
  ├─ current_rank: 1
  └─ rank_change: 0 (no change)

        ↓ (Dashboard queries views)

Step 5: Looker Studio Updates
Dashboard → Latest Rankings (by Format)
  ├─ TEST Rankings
  │  └─ Babar Azam: Rank 1, Rating 865
  ├─ ODI Rankings
  │  └─ Babar Azam: Rank 1, Rating 875
  └─ T20I Rankings
     └─ Babar Azam: Rank 1, Rating 880
```

---

## 🔄 **Daily Cycle (30-Day View)**

```
Day 1:  06:00 UTC → Pipeline runs → 300-500 records
Day 2:  06:00 UTC → Pipeline runs → +300-500 records (600-1,000 total)
Day 3:  06:00 UTC → Pipeline runs → +300-500 records (900-1,500 total)
...
Day 30: 06:00 UTC → Pipeline runs → +300-500 records (9,000-15,000 total)

BigQuery Storage Growth:
├─ Day 1: ~50 KB
├─ Day 7: ~350 KB
├─ Day 30: ~1.5 MB
└─ Day 90: ~4.5 MB (then starts deleting oldest data)
```

---

## 🎯 **Key Metrics You Can Track**

```
Daily Dashboard:
├─ Records ingested today: 300-500
├─ Pipeline run time: ~13 minutes
├─ Data freshness: <24 hours old
├─ Rank changes today: N records (top movers)
├─ New entries: M players
└─ Total in system: X records (cumulative)

Monthly Dashboard:
├─ Total records ingested: 9,000-15,000
├─ Data quality: 99.9% (failed records < 5)
├─ Pipeline success rate: 100% (no failed runs)
├─ Average player rating: XXX
└─ Biggest rank movers: Top 10 this month

90-Day Dashboard:
├─ Total records: 27,000-45,000 (then deletes oldest)
├─ Trending: Rankings over 3 months
├─ Format comparison: Test vs ODI vs T20I
├─ Country performance: Avg ratings by country
└─ Player profiles: Complete ranking history
```

---

## 🎓 **What Happens Next?**

### Real Data Scenario (After RapidAPI Key)

**Day 0 (Setup):**
- ✅ Get RapidAPI key
- ✅ Set environment variable
- ✅ Create Looker Studio dashboard

**Day 1 (First Real Run):**
- 06:00 UTC: Cloud Scheduler triggers
- 06:00-06:02: Cricbuzz API returns real batting rankings
- 06:02-06:03: CSV uploaded to GCS
- 06:03-06:13: Dataflow processes 300-500 real records
- 06:13: BigQuery populated with real cricket data
- 06:13: Dashboard shows real rankings
- 06:13+: Monitoring tracks execution

**Day 2-30:** Repeat daily, accumulating data

**Day 31:** Start seeing 30-day trends

**Day 91:** Start deleting oldest data (retention: 90 days)

---

## ✅ **Current Status**

You have:
- ✅ All infrastructure deployed
- ✅ Pipeline tested with test data
- ✅ End-to-end flow working
- ⏳ Waiting for: RapidAPI key to start ingesting real data

**Next:**
1. Get RapidAPI key
2. Create Looker Studio dashboard
3. Let pipeline run daily automatically

---

## 🚀 **You're All Set!**

The entire end-to-end pipeline is:
- **Automated** ✅ (runs daily at 06:00 UTC)
- **Monitored** ✅ (Cloud Logging tracks everything)
- **Scalable** ✅ (Dataflow auto-scales)
- **Cost-Optimized** ✅ ($5-9/month)
- **Production-Ready** ✅ (All validation built-in)

Just add your RapidAPI key, and it'll run automatically every day!

