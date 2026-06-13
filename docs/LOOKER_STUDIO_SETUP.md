# Looker Studio Dashboard Setup Guide

## 🎯 Quick Start

### 1. Create Data Source
- Go to https://lookerstudio.google.com/
- Click **Create** → **Report**
- Click **Create New Data Source**
- Select **BigQuery**
- Choose dataset: `cricket_raw`
- Choose table: `batting_rankings`

---

## 📊 Visualizations to Create

### Chart 1: Rankings by Format
**Query:**
```sql
SELECT 
  format,
  player_name,
  country,
  rank,
  rating
FROM `cricbuzz-satish-dev.cricket_raw.batting_rankings`
ORDER BY format, rank
```
**Visualization:** Table
**Dimensions:** Format, Player Name, Country, Rank
**Metrics:** Rating

---

### Chart 2: Top Players by Rating
**Query:**
```sql
SELECT 
  player_name,
  country,
  format,
  rating,
  points
FROM `cricbuzz-satish-dev.cricket_raw.batting_rankings`
WHERE rank <= 5
ORDER BY format, rating DESC
```
**Visualization:** Bar Chart
**X-Axis:** Format
**Y-Axis:** Rating
**Color:** Country

---

### Chart 3: Players by Format Distribution
**Query:**
```sql
SELECT 
  format,
  COUNT(*) as player_count,
  AVG(rating) as avg_rating
FROM `cricbuzz-satish-dev.cricket_raw.batting_rankings`
GROUP BY format
```
**Visualization:** Pie Chart
**Dimensions:** Format
**Metrics:** Player Count

---

### Chart 4: Country Performance
**Query:**
```sql
SELECT 
  country,
  COUNT(*) as total_players,
  AVG(rating) as avg_rating,
  MAX(rating) as highest_rating,
  MIN(rank) as best_rank
FROM `cricbuzz-satish-dev.cricket_raw.batting_rankings`
GROUP BY country
ORDER BY avg_rating DESC
```
**Visualization:** Scorecards + Table
**Metrics:** Total Players, Avg Rating, Highest Rating

---

### Chart 5: Rating Distribution
**Query:**
```sql
SELECT 
  CASE 
    WHEN rating >= 850 THEN 'Excellent (850+)'
    WHEN rating >= 800 THEN 'Good (800-849)'
    WHEN rating >= 750 THEN 'Average (750-799)'
    ELSE 'Below Average (<750)'
  END as rating_category,
  COUNT(*) as player_count
FROM `cricbuzz-satish-dev.cricket_raw.batting_rankings`
GROUP BY rating_category
ORDER BY player_count DESC
```
**Visualization:** Column Chart

---

## 🔗 Connecting to BigQuery

### Authentication
- Make sure you're logged in with the same Google account that has access to `cricbuzz-satish-dev` project
- Looker Studio will auto-authenticate with BigQuery

### Refresh Settings
- Set refresh to **Daily** or **Hourly** once real data is ingesting
- Currently set to **Manual** for test data

---

## 📍 Dashboard Layout Suggestion

```
┌─────────────────────────────────────────┐
│     Cricket Batting Rankings Analytics   │
├──────────────┬──────────────────────────┤
│ Rankings by  │  Top 5 Players by Rating │
│   Format     │      (Bar Chart)         │
│  (Table)     │                          │
├──────────────┴──────────────────────────┤
│  Country Performance (Cards + Table)     │
├──────────────┬──────────────────────────┤
│  Format Dist │  Rating Distribution     │
│  (Pie)       │  (Column Chart)          │
└──────────────┴──────────────────────────┘
```

---

## 🎨 Style Suggestions

- **Theme:** Dark mode (matches GCP console)
- **Color scheme:** 
  - Blue for Test
  - Green for ODI
  - Orange for T20I
- **Font:** Roboto (Google font)
- **Update frequency:** Daily at 07:00 UTC (after pipeline runs)

---

## 🔄 Once Real Data Arrives

When you have live data from RapidAPI:
1. Historical data will auto-populate
2. Dashboard will show trending rankings
3. Add time-series charts showing player movement
4. Add alerts for rank changes (±5 positions)

---

## 📞 Support

For issues:
- Check BigQuery data exists: `bq ls cricket_raw`
- Verify columns: `bq show cricket_raw.batting_rankings`
- Check Looker Studio data source connection status

