# 🔍 Schema Drift Handling - What's Actually In Our Pipeline

**Author**: Satish Mudde  
**Date**: 2026-06-07  
**File**: This document explains the actual code implementations  

---

## 📍 Location Map: Where Schema Drift is Handled

```
Cricbuzz API
    │
    ├─ PROTECTION 1: Error Handling (fetch_rankings)
    │
    ↓
API Response (JSON)
    │
    ├─ PROTECTION 2: Defensive Field Parsing (parse_rankings)
    │   ├─ Missing field → .get() with default
    │   ├─ Type mismatch → try-catch
    │   └─ Alternative field names → .get("id") for player_id
    │
    ├─ PROTECTION 3: Record-level Error Handling
    │   └─ Bad record → logged and skipped
    │
    ↓
CSV File (GCS)
    │
    ├─ PROTECTION 4: Column Count Validation (dataflow)
    │
    ↓
BigQuery Table
```

---

## 🛡️ Protection 1: Empty Response Check

**File**: `ingestion/fetch_batting_rankings.py:60-71`

```python
def parse_rankings(data: dict, format_type: str) -> pd.DataFrame:
    """Parse API response into DataFrame."""
    
    # PROTECTION: Check if data is None/empty
    if not data:
        logger.warning(f"No data returned for {format_type}")
        return pd.DataFrame()
    
    # PROTECTION: Handle multiple response formats
    rank_list = data.get("rank", 
                data.get("data", {}).get("rank", []))
    
    # PROTECTION: Check if rankings list is empty
    if not rank_list:
        logger.warning(f"No rankings found in response for {format_type}")
        return pd.DataFrame()
```

**What it catches**:
- ✅ API returns null/empty response
- ✅ API changes response structure (data.rank vs rank)
- ✅ No rankings in response

**Example**:
```
Before:     {"rank": [...]}
After:      {"data": {"rank": [...]}}
Protected:  ✅ Works with both
```

---

## 🛡️ Protection 2: Defensive Field Parsing with .get()

**File**: `ingestion/fetch_batting_rankings.py:74-90`

This is the **MAIN schema drift protection**. Every field uses `.get()` with a default:

```python
rankings = []
for rank_entry in rank_list:
    try:
        rankings.append({
            # ┌─ PROTECTION: Use .get() instead of direct access
            # │  If field missing → use default value
            "rank": int(rank_entry.get("rank", 0)),
            #                           ↑─ Missing? Use 0
            
            "player_id": rank_entry.get("id", ""),
            #                          ↑─ Missing? Use ""
            #                          Note: Maps API "id" to "player_id"
            
            "player_name": rank_entry.get("name", ""),
            #                          ↑─ Missing? Use ""
            
            "country": rank_entry.get("country", ""),
            "country_id": rank_entry.get("countryId", ""),
            
            "rating": float(rank_entry.get("rating", 0)),
            #         ↑─ Type cast with try-catch below
            
            "points": float(rank_entry.get("points", 0)),
            
            "best_rank": int(rank_entry.get("bestRank", 
                                rank_entry.get("rank", 0))),
            #           ↑─ Fallback: If bestRank missing, use rank
            
            "format": format_type.upper(),
            "ingested_at": datetime.utcnow().isoformat()
        })
    except Exception as e:
        # ┌─ PROTECTION 3: Catch type conversion errors
        logger.warning(f"Failed to parse ranking entry: {e}")
        continue  # Skip bad record
```

**What it catches**:

| Scenario | Handling |
|----------|----------|
| API adds `last_updated_date` | Ignored (not in .get() list) ✅ |
| API removes `best_rank` | Falls back to `rank` value ✅ |
| API removes `rating` | Uses default `0` ✅ |
| `rating` is STRING not FLOAT | Type error caught by try-catch ✅ |
| `player_id` field renamed to `pid` | Falls back to `""` - **ISSUE** ❌ |
| `rank` is "abc" not int | Type conversion fails, caught ✅ |

---

## 🛡️ Protection 3: Record-Level Error Handling

**File**: `ingestion/fetch_batting_rankings.py:88-90`

```python
except Exception as e:
    logger.warning(f"Failed to parse ranking entry: {e}")
    continue  # Skip this record, continue with next
```

**What happens**:
```
Bad Record Input
    ↓
Type conversion fails (e.g., int("abc"))
    ↓
Exception caught
    ↓
Logged as WARNING
    ↓
Record skipped (not added to list)
    ↓
Continue to next record (pipeline doesn't stop)
```

**Example**:
```python
# If this record fails:
{
    "rank": "top-100",  # ❌ Can't convert to int
    "player_id": "123",
    ...
}

# Output: WARNING: Failed to parse ranking entry: 
#         invalid literal for int(): 'top-100'
#
# Result: Record skipped, next record processed ✅
```

---

## 🛡️ Protection 4: Format-Level Error Handling

**File**: `ingestion/fetch_batting_rankings.py:123-134`

```python
for format_type in config["apis"]["formats"]:
    try:
        raw_data = fetch_rankings(format_type, api_key, config)
        df = parse_rankings(raw_data, format_type)
        
        if not df.empty:
            all_data.append(df)
            logger.info(f"Parsed {len(df)} {format_type.upper()} rankings")
    
    except requests.RequestException as e:
        # ┌─ PROTECTION: API request fails for 1 format
        logger.error(f"API request failed for {format_type}: {e}")
        continue  # Continue with next format (TEST→ODI→T20I)
```

**What it catches**:
- ✅ API timeout for one format (T20I) → skip it, get TEST & ODI
- ✅ API returns 401 (auth error) → logged, try next format
- ✅ Network error → retry not needed, fail gracefully

**Example**:
```
Fetch TEST    ✅ 500 records
Fetch ODI     ❌ API timeout → ERROR logged, skip
Fetch T20I    ✅ 450 records
Result        ✅ 950 records total (missing ODI)
```

---

## 🛡️ Protection 5: Final Validation

**File**: `ingestion/fetch_batting_rankings.py:136-138`

```python
if not all_data:
    logger.error("No data fetched for any format")
    return 1  # Exit with error code
```

**What it catches**:
- ✅ All 3 formats failed → don't upload empty data
- ✅ API completely down → fail fast

---

## 🛡️ Protection 6: Dataflow Row Validation

**File**: `dataflow/pipeline.py:46-76`

```python
class ParseCsvLine(beam.DoFn):
    """Parse CSV line with validation"""
    
    def process(self, line: str, source_file: str):
        try:
            if line.startswith("rank"):  # Skip CSV header
                return
            
            reader = csv.reader(StringIO(line))
            row = next(reader)
            
            # ┌─ PROTECTION: Validate column count
            if len(row) < 10:
                logger.warning(f"Skipping line with {len(row)} columns: {line}")
                return
            #                         Expected 10 columns
            #                         If CSV only has 8 → skip
            
            # ┌─ PROTECTION: Type validation with try-catch
            record = {
                "rank": int(row[0]) if row[0] else None,
                "player_id": row[1] if row[1] else None,
                ...
            }
            yield record
        
        except ValueError as e:
            # ┌─ PROTECTION: Type conversion error
            logger.warning(f"Validation error: {e}")
        except Exception as e:
            # ┌─ PROTECTION: Any other error
            logger.error(f"Parse error: {e}")
```

**What it catches**:
- ✅ CSV has fewer than 10 columns
- ✅ Column value can't be converted to expected type
- ✅ CSV header or malformed line

**Example**:
```
CSV Line: rank,player_id,player_name,country,...
          1,123,Virat,India

Validation:
  len(row) = 4 (should be 10)
           ↓
  SKIP line, log warning ✅
```

---

## 📊 Complete Data Flow with All Protections

```
┌─────────────────────────────────────────┐
│ Cricbuzz API                            │
│ Returns JSON with batting rankings      │
└──────────────┬──────────────────────────┘
               │
               ├─ Response is null/empty?
               │  ├─ YES → Return empty DataFrame ✅
               │  └─ NO → Continue
               │
               ├─ Multiple response formats?
               │  ├─ Try {"rank": [...]}
               │  ├─ Try {"data": {"rank": [...]}}
               │  └─ No rankings? → Return empty ✅
               │
               ↓
        ┌──────────────────────────────┐
        │ For each ranking entry:      │
        └──────────────────────────────┘
               │
               ├─ Field missing?
               │  └─ Use .get() default value ✅
               │
               ├─ Type conversion fails?
               │  └─ Catch exception, skip record ✅
               │
               ├─ Format is valid?
               │  └─ TEST, ODI, or T20I ✅
               │
               ↓
        ┌──────────────────────────────┐
        │ DataFrame created            │
        │ with valid records          │
        └──────────────────────────────┘
               │
               ├─ Any data?
               │  ├─ YES → Continue
               │  └─ NO → Stop with error ✅
               │
               ↓
        ┌──────────────────────────────┐
        │ Upload to GCS as CSV         │
        │ with metadata                │
        └──────────────────────────────┘
               │
               ↓
        ┌──────────────────────────────┐
        │ Dataflow reads CSV           │
        └──────────────────────────────┘
               │
               ├─ CSV line is header?
               │  └─ Skip it ✅
               │
               ├─ Row has < 10 columns?
               │  └─ Skip & log warning ✅
               │
               ├─ Type conversion fails?
               │  └─ Catch & skip record ✅
               │
               ↓
        ┌──────────────────────────────┐
        │ Write valid records to       │
        │ BigQuery                     │
        └──────────────────────────────┘
```

---

## ✅ What IS Currently Protected

| Protection | Code Location | Type |
|-----------|---------------|------|
| Empty API response | `parse_rankings:62` | Return empty |
| Multiple response formats | `parse_rankings:67` | Try multiple paths |
| Missing fields | `parse_rankings:77-86` | `.get()` defaults |
| Type conversion errors | `parse_rankings:74-90` | Try-catch |
| Format-level errors | `main:123-134` | Try-catch |
| All formats failed | `main:136-138` | Check empty |
| CSV header line | `dataflow:48` | Skip |
| Column count | `dataflow:54-56` | Validate |
| CSV type errors | `dataflow:73-76` | Try-catch |

---

## ⚠️ What is NOT Currently Protected

| Issue | Impact | Example |
|-------|--------|---------|
| **New column added** | Silently ignored | API adds `updated_at` field |
| **Column renamed** | Falls back to default | `playerId` instead of `id` |
| **Unexpected column count (>10)** | Extra columns ignored | API adds 5 new fields |
| **Silent NULLs** | Data quality issue | Record has null player_id but continues |
| **No schema version** | Can't track changes | If API changes in future |
| **No alerting** | Warnings only logged | Skip rate > 1% not detected |
| **No monitoring** | No visibility | Can't see drift trends |

---

## 🔧 Code Quality Analysis

### **Strengths**
✅ **Defensive `.get()` usage** - Handles missing fields gracefully  
✅ **Try-catch blocks** - Type errors caught and logged  
✅ **Format-level error handling** - One format failure doesn't stop pipeline  
✅ **Graceful degradation** - Bad records skipped, good ones continue  
✅ **Detailed logging** - Every error logged with context  
✅ **Multiple response formats** - Handles API response variations  

### **Weaknesses**
⚠️ **Silent default values** - Missing critical field uses 0 or ""  
⚠️ **No explicit validation** - No SchemaValidator class  
⚠️ **No field requirement checking** - Missing player_id doesn't fail  
⚠️ **No monitoring/alerting** - Errors only in logs  
⚠️ **No schema versioning** - Can't track schema changes  
⚠️ **No metrics** - Skip rate not calculated  

---

## 📈 Real-World Examples

### **Example 1: API Adds New Column**

```json
Before:
{"rank": 1, "id": "123", "name": "Virat", ...}

After:
{"rank": 1, "id": "123", "name": "Virat", ..., "updated_at": "2026-06-07"}
```

**What happens**:
1. ✅ New field `updated_at` is in API response
2. ✅ Code doesn't call `.get("updated_at")` 
3. ✅ New field is silently ignored
4. ✅ Record still created with original 10 fields
5. ✅ **Result**: Pipeline works, info lost

**Issue**: No warning that new data exists

---

### **Example 2: API Removes Optional Field**

```json
Before:
{"rank": 1, "id": "123", "name": "Virat", "bestRank": 1, ...}

After:
{"rank": 1, "id": "123", "name": "Virat", ...}  # bestRank removed
```

**What happens**:
1. ✅ `bestRank` missing from API response
2. ✅ Code: `rank_entry.get("bestRank", rank_entry.get("rank", 0))`
3. ✅ Falls back to `rank` value (1)
4. ✅ Record created: `"best_rank": 1`
5. ✅ **Result**: Pipeline works seamlessly

**Issue**: No warning that field changed

---

### **Example 3: API Changes Field Name**

```json
Before:
{"rank": 1, "id": "123", ...}

After:
{"rank": 1, "player_id": "123", ...}  # id → player_id
```

**What happens**:
1. ⚠️ API field is now `player_id`, code looks for `id`
2. ⚠️ Code: `rank_entry.get("id", "")`
3. ⚠️ Field not found, uses default `""`
4. ⚠️ Record created: `"player_id": ""`
5. ❌ **Result**: Records have null player_id!

**Issue**: Silent failure, data quality degradation

**Fix needed**: Track field mapping or add validation

---

### **Example 4: Type Change (INT → STRING)**

```json
Before:
{"rank": 1, ...}

After:
{"rank": "1", ...}  # Now a string
```

**What happens**:
1. ✅ API returns `"rank": "1"` (string)
2. ✅ Code: `int(rank_entry.get("rank", 0))`
3. ✅ `int("1")` works fine!
4. ✅ Record created: `"rank": 1`
5. ✅ **Result**: Works due to type compatibility

**Issue**: None, this type change is handled

---

## 🎯 Recommendation: Add These Protections

### **Quick Add (This Sprint)**
```python
# 1. Log unexpected columns
unexpected = set(rank_entry.keys()) - {"rank", "id", "name", ...}
if unexpected:
    logger.info(f"Unexpected columns: {unexpected}")

# 2. Validate required fields
required = ["rank", "id", "name", "country", "rating"]
for field in required:
    if field not in rank_entry or not rank_entry[field]:
        logger.warning(f"Required field missing: {field}")
        continue  # Skip record

# 3. Track metrics
self.records_processed += 1
self.records_skipped += 1  # if skipped
skip_rate = self.records_skipped / self.records_processed
```

### **Medium Add (Next Sprint)**
```python
# SchemaValidator class
class SchemaValidator:
    EXPECTED_SCHEMA = {
        "rank": {"type": int, "required": True, "range": (1, 500)},
        "id": {"type": str, "required": True},
        # ...
    }
    
    @classmethod
    def validate(cls, record):
        for field, spec in cls.EXPECTED_SCHEMA.items():
            if not record.get(field) and spec["required"]:
                raise ValueError(f"Missing {field}")
```

---

## 📊 Summary Table

| Aspect | Current | Recommended | Effort |
|--------|---------|-------------|--------|
| **Missing fields** | ✅ Handled | ✅ Good | Low |
| **Type errors** | ✅ Caught | ✅ Good | Low |
| **New columns** | ⚠️ Ignored | 📋 Log them | Low |
| **Required field validation** | ❌ None | 📋 Add check | Low |
| **Schema versioning** | ❌ None | 📋 Implement | Medium |
| **Monitoring/alerts** | ❌ None | 📋 Add metrics | Medium |

---

## ✨ Status

**Current Protection Level**: 🟢 **GOOD** (Baseline)
- Handles most common scenarios
- Graceful error handling
- Detailed logging

**Recommended Next Level**: 🟡 **BETTER** (Recommended)
- Add explicit validation
- Add monitoring/alerting
- Track schema changes

**Future Level**: 🟢 **BEST** (Nice-to-have)
- Schema registry
- Auto-migration
- Version tracking

---

**Conclusion**: Your pipeline IS handling schema drift with `.get()` defaults and try-catch blocks. The handling is **graceful but passive** — it works silently without alerting you to changes. Recommended next step: **Add active monitoring** to detect drift early.

