# 📋 Schema Drift Handling Guide

**Author**: Satish Mudde  
**Date**: 2026-06-07  
**Status**: Comprehensive Schema Drift Strategy  

---

## 🎯 What is Schema Drift?

Schema drift occurs when the actual data structure diverges from the expected schema:

| Type | Example | Impact |
|------|---------|--------|
| **New Columns** | API adds `last_updated_date` field | Extra data ignored, potential info loss |
| **Missing Columns** | API removes `best_rank` field | Pipeline fails, missing required column |
| **Type Changes** | `rating` changes from STRING to FLOAT | Type mismatch errors |
| **Column Reorder** | API reorders field positions | Wrong data in wrong columns |
| **Field Rename** | `player_id` → `playerId` | Column not found, null values |

---

## 🔒 Current Schema Drift Handling

### **1. Defensive Parsing in Ingestion**

**File**: `ingestion/fetch_batting_rankings.py`

```python
def parse_rankings(data: dict, format_type: str) -> pd.DataFrame:
    """Parse API response with schema drift protection"""
    rankings = []
    for rank_entry in rank_list:
        try:
            rankings.append({
                # Use .get() with defaults - handles missing fields
                "rank": int(rank_entry.get("rank", 0)),
                "player_id": rank_entry.get("id", ""),
                "player_name": rank_entry.get("name", ""),
                "country": rank_entry.get("country", ""),
                "country_id": rank_entry.get("countryId", ""),
                "rating": float(rank_entry.get("rating", 0)),
                "points": float(rank_entry.get("points", 0)),
                "best_rank": int(rank_entry.get("bestRank", 
                         rank_entry.get("rank", 0))),
                "format": format_type.upper(),
                "ingested_at": datetime.utcnow().isoformat()
            })
        except Exception as e:
            # Log and skip malformed records
            logger.warning(f"Failed to parse entry: {e}")
            continue
```

**Protections**:
✅ Uses `.get()` with defaults → missing fields → null values  
✅ Try-catch blocks → malformed records skipped, logged  
✅ Handles alternate field names (`id`, `name` instead of `player_id`, `player_name`)  
✅ Type casting with fallbacks

### **2. Row Validation in Dataflow**

**File**: `dataflow/pipeline.py`

```python
class ParseCsvLine(beam.DoFn):
    """Parse CSV with schema validation"""
    
    def process(self, line: str, source_file: str):
        try:
            if line.startswith("rank"):  # Skip header
                return
            
            reader = csv.reader(StringIO(line))
            row = next(reader)
            
            # Validate minimum columns (schema drift check)
            if len(row) < 10:
                logger.warning(f"Skipping line with {len(row)} columns: {line}")
                return
            
            record = {
                "rank": int(row[0]) if row[0] else None,
                "player_id": row[1] if row[1] else None,
                # ... other fields
            }
            yield record
        
        except ValueError as e:
            # Type conversion error - schema drift detected
            logger.warning(f"Type error: {e}")
        except Exception as e:
            # Unexpected error
            logger.error(f"Parse error: {e}")
```

**Protections**:
✅ Validates column count (< 10 columns = skip)  
✅ Type validation with try-catch  
✅ Logs all errors for investigation  
✅ Gracefully skips bad records  

---

## 🚨 Schema Drift Detection Mechanisms

### **1. Column Count Validation**

```python
EXPECTED_COLUMNS = 10

if len(row) < EXPECTED_COLUMNS:
    logger.warning(
        f"Column count mismatch: expected {EXPECTED_COLUMNS}, got {len(row)}"
    )
    # Skip this record
    return
```

**Detects**: Missing columns, truncated records

### **2. Type Validation**

```python
try:
    rank = int(row[0])
except ValueError:
    logger.warning(f"Type error: 'rank' is not an integer: {row[0]}")
    # Skip this record or use NULL
    return
```

**Detects**: Type changes (STRING → INTEGER, etc.)

### **3. Required Field Check**

```python
REQUIRED_FIELDS = ["rank", "player_id", "player_name"]

for field in REQUIRED_FIELDS:
    if not record.get(field):
        logger.warning(f"Missing required field: {field}")
        # Raise error or mark for review
        raise ValueError(f"Missing {field}")
```

**Detects**: Missing or null required fields

### **4. Data Range Validation**

```python
# Rank should be 1-500
if rank < 1 or rank > 500:
    logger.warning(f"Rank out of expected range: {rank}")

# Rating should be 0-1000
if rating < 0 or rating > 1000:
    logger.warning(f"Rating out of expected range: {rating}")
```

**Detects**: Data anomalies, possible data corruption

---

## 📊 Current Implementation Status

### **What IS Protected**

| Protection | Where | Status |
|-----------|-------|--------|
| Missing fields | `ingestion/fetch_batting_rankings.py` | ✅ Implemented |
| Type errors | `dataflow/pipeline.py` | ✅ Implemented |
| Column count | `dataflow/pipeline.py` | ✅ Implemented |
| Alternate field names | `ingestion/fetch_batting_rankings.py` | ✅ Implemented |
| Bad records logged | Both files | ✅ Implemented |

### **What is NOT Protected**

| Issue | Impact | Solution |
|-------|--------|----------|
| Extra columns | Ignored silently | Needs explicit logging |
| Type narrowing | Data truncation | Needs validation range checks |
| Silent NULLs | Data quality issue | Needs alerting |
| Format changes | May pass invalid | Needs format enum validation |
| No schema versioning | Can't track changes | Needs metadata tracking |

---

## 🛡️ Enhanced Schema Drift Handling Strategy

### **Level 1: Defensive Parsing** (Already Implemented ✅)
```python
# Use .get() with defaults
field_value = record.get("field_name", default_value)

# Type-safe casting
try:
    value = int(field_value)
except ValueError:
    logger.warning(f"Type error: {field}")
    value = None
```

### **Level 2: Schema Validation** (Recommended Implementation)
```python
class SchemaValidator:
    """Validate incoming data against expected schema"""
    
    EXPECTED_SCHEMA = {
        "rank": {"type": int, "required": True, "range": (1, 500)},
        "player_id": {"type": str, "required": True},
        "player_name": {"type": str, "required": True},
        "rating": {"type": float, "required": False, "range": (0, 1000)},
        "format": {"type": str, "required": True, 
                   "allowed_values": ["TEST", "ODI", "T20I"]},
    }
    
    @classmethod
    def validate_record(cls, record: dict) -> tuple[bool, str]:
        """
        Validate record against schema.
        Returns: (is_valid, error_message)
        """
        for field, spec in cls.EXPECTED_SCHEMA.items():
            # Check required fields
            if spec.get("required") and field not in record:
                return False, f"Missing required field: {field}"
            
            if field not in record:
                continue
            
            value = record[field]
            
            # Check type
            if value is not None:
                if not isinstance(value, spec["type"]):
                    return False, f"{field}: expected {spec['type']}, got {type(value)}"
                
                # Check range
                if "range" in spec and value is not None:
                    min_val, max_val = spec["range"]
                    if not (min_val <= value <= max_val):
                        return False, f"{field}: value {value} out of range {spec['range']}"
                
                # Check allowed values
                if "allowed_values" in spec and value not in spec["allowed_values"]:
                    return False, f"{field}: {value} not in allowed {spec['allowed_values']}"
        
        return True, ""

# Usage in pipeline:
is_valid, error_msg = SchemaValidator.validate_record(record)
if not is_valid:
    logger.warning(f"Schema validation failed: {error_msg}")
    return  # Skip record
```

### **Level 3: Schema Versioning** (For Major Changes)
```python
class SchemaVersion:
    """Track schema versions for compatibility"""
    
    VERSION_1 = {  # 2015-2025
        "fields": [
            "rank", "player_id", "player_name", "country", "country_id",
            "rating", "points", "best_rank", "format", "ingested_at"
        ],
        "version": 1,
        "description": "Original 10-field schema"
    }
    
    VERSION_2 = {  # If API changes (future)
        "fields": [
            "rank", "player_id", "player_name", "country", "country_id",
            "rating", "points", "best_rank", "format", "ingested_at",
            "updated_date", "data_quality_score"  # New fields
        ],
        "version": 2,
        "description": "Added metadata fields"
    }
    
    @classmethod
    def detect_version(cls, record: dict) -> int:
        """Detect which schema version the record matches"""
        v1_fields = set(cls.VERSION_1["fields"])
        record_fields = set(record.keys())
        
        if record_fields == v1_fields:
            return 1
        elif record_fields == set(cls.VERSION_2["fields"]):
            return 2
        else:
            return -1  # Unknown version
    
    @classmethod
    def handle_version_mismatch(cls, record: dict, detected_version: int):
        """Handle schema version mismatch"""
        expected_version = 1
        
        if detected_version == -1:
            logger.error(f"Unknown schema version")
            # Alert team
            raise SchemaException("Schema version mismatch detected")
        
        elif detected_version > expected_version:
            logger.warning(f"Future schema detected (v{detected_version})")
            # Accept but log - this is a new field we're not using yet
        
        elif detected_version < expected_version:
            logger.warning(f"Old schema detected (v{detected_version})")
            # May need backwards compatibility mapping
```

### **Level 4: Monitoring & Alerting** (For Operations)
```python
class SchemaMetrics:
    """Track schema drift metrics"""
    
    def __init__(self):
        self.records_processed = 0
        self.records_skipped = 0
        self.validation_errors = {}
        self.column_mismatches = 0
        self.type_errors = 0
    
    def report(self):
        """Generate drift report"""
        return {
            "total_records": self.records_processed,
            "skipped_records": self.records_skipped,
            "skip_rate": self.records_skipped / self.records_processed if self.records_processed > 0 else 0,
            "validation_errors": self.validation_errors,
            "column_mismatches": self.column_mismatches,
            "type_errors": self.type_errors,
            "alert": self.should_alert()
        }
    
    def should_alert(self):
        """Determine if alert should be triggered"""
        # Alert if skip rate > 1%
        skip_rate = self.records_skipped / self.records_processed if self.records_processed > 0 else 0
        
        if skip_rate > 0.01:
            return f"ALERT: {skip_rate*100:.2f}% of records skipped (expected < 1%)"
        
        if self.column_mismatches > 0:
            return f"ALERT: {self.column_mismatches} column mismatches detected"
        
        return None

# Usage:
metrics = SchemaMetrics()
# ... process records ...
report = metrics.report()
if report["alert"]:
    # Send alert to Cloud Monitoring
    logging.error(report["alert"])
```

---

## 🔄 Workflow: Handling Schema Drift When It Occurs

### **Scenario 1: New Column Added by API**

**What happens**:
- API adds `last_updated_date` field
- Current code ignores it (not in expected schema)
- No error, data silently flows through

**Detection**:
```python
# Log unexpected columns
unexpected_columns = set(record.keys()) - set(EXPECTED_SCHEMA.keys())
if unexpected_columns:
    logger.info(f"Unexpected columns: {unexpected_columns}")
```

**Response**:
1. ✅ Data continues flowing (graceful)
2. 📊 New column is logged
3. 👥 Team reviews and decides:
   - Add to schema? → Update SQL files + schema JSON + TF
   - Ignore? → Continue as is

### **Scenario 2: Required Column Missing**

**What happens**:
- API removes or renames `player_id`
- Code tries to access missing field
- Record fails validation

**Detection**:
```python
if "player_id" not in record:
    logger.error("SCHEMA DRIFT: Missing required field 'player_id'")
    # Trigger alert
    raise SchemaException("Missing player_id")
```

**Response**:
1. 🚨 Pipeline fails fast (intentional)
2. 📧 Team gets notified
3. 🔧 Manual intervention needed:
   - Verify API change
   - Update code to new field name
   - Test before redeploying

### **Scenario 3: Type Change (STRING → FLOAT)**

**What happens**:
- API changes `rating` from "8.5" (STRING) to 8.5 (FLOAT)
- Type casting might work or fail

**Detection**:
```python
try:
    rating = float(record["rating"])
except ValueError:
    logger.error(f"Type error: rating is {type(record['rating'])}, expected float")
    raise SchemaException("Type mismatch on rating")
```

**Response**:
1. ✅ If compatible types → silently works
2. ⚠️ If incompatible types → error logged + record skipped
3. 👥 Team investigates anomaly

---

## 📋 Current Implementation Gaps

### **Gap 1: No Explicit Schema Validation**
**Current**: Rely on error handling  
**Recommended**: Implement SchemaValidator class above  
**Impact**: Missing early drift detection

### **Gap 2: No Column Drift Logging**
**Current**: Extra columns silently ignored  
**Recommended**: Log all unexpected columns  
**Impact**: May miss important API changes

### **Gap 3: No Schema Version Tracking**
**Current**: No versioning  
**Recommended**: Track schema versions for compatibility  
**Impact**: Can't easily handle major version changes

### **Gap 4: No Monitoring Dashboard**
**Current**: Errors only in logs  
**Recommended**: Cloud Monitoring metrics  
**Impact**: No visibility into schema drift trends

---

## ✅ Recommended Implementation Plan

### **Phase 1: Immediate (This Sprint)**
- [ ] Add explicit schema validation in dataflow/pipeline.py
- [ ] Log all unexpected columns
- [ ] Add range validation for numeric fields
- [ ] Create schema drift alert threshold

### **Phase 2: Short-term (Next Sprint)**
- [ ] Implement SchemaValidator class
- [ ] Add schema versioning mechanism
- [ ] Create drift detection unit tests
- [ ] Set up Cloud Monitoring dashboard

### **Phase 3: Long-term (Future)**
- [ ] Implement schema registry (Apache Avro/Protobuf)
- [ ] Auto-migration for compatible changes
- [ ] Schema change notifications to stakeholders
- [ ] Historical schema tracking

---

## 🔗 Related Files

- **dataflow/pipeline.py** - Row validation
- **ingestion/fetch_batting_rankings.py** - Field parsing
- **bigquery/schemas/*.json** - Expected schemas (source of truth)
- **SQL_DEVELOPER_GUIDE.md** - Column definitions

---

## 📞 What to Do If Schema Drift Detected

### **Step 1: Identify the Drift**
```bash
# Check logs for validation errors
gcloud functions logs read cricket-gcs-dataflow-trigger --limit 100

# Check Dataflow job logs
gcloud dataflow jobs show JOB_ID --region us-central1 --messages
```

### **Step 2: Verify the Change**
- Check Cricbuzz API documentation
- Compare old vs new API response
- Verify in RapidAPI dashboard

### **Step 3: Update Schema**
If adding/modifying columns:
1. Update `bigquery/schemas/raw_batting_rankings.json`
2. Update `bigquery/sql/raw_batting_rankings.sql`
3. Update `dataflow/pipeline.py` RAW_SCHEMA
4. Update `ingestion/fetch_batting_rankings.py` parse logic

### **Step 4: Deploy & Test**
```bash
# Test locally first
python ingestion/fetch_batting_rankings.py

# Deploy to production
cd terraform && terraform apply
```

---

## 📊 Monitoring Schema Health

### **Key Metrics to Track**

```python
{
    "records_processed": 1500,
    "records_skipped": 5,
    "skip_rate": 0.33,  # % - should be < 1%
    "validation_errors": {
        "type_errors": 2,
        "column_mismatches": 0,
        "required_field_missing": 3
    },
    "schema_version": 1,
    "last_schema_change": "2026-06-07",
    "alerts_triggered": 0
}
```

### **Alert Thresholds**
- Skip rate > 1% → Alert
- Column mismatch detected → Alert
- Type error rate > 0.5% → Alert
- Unknown schema version → Alert

---

**Status**: ✅ Baseline protection in place  
**Next**: Implement enhanced validation (Phase 1)  

All code is configuration-driven and ready for scale! 🚀
