-- ============================================================================
-- Author: Satish Mudde
-- Created: 2026-06-07
-- File: dim_format.sql
-- ============================================================================
-- Purpose: Create STAGING layer - Dimension: Format
-- Note: Dataset names are placeholders - substitute {STAGING_DATASET} with actual dataset name from config
-- ============================================================================

CREATE OR REPLACE TABLE `{PROJECT_ID}.{STAGING_DATASET}.dim_format` (
  format_id INT64 NOT NULL,
  format_name STRING NOT NULL,
  description STRING,
  PRIMARY KEY (format_id) NOT ENFORCED
)
OPTIONS (
  description="Cricket format dimension (Test, ODI, T20I)"
);

-- Merge format values for idempotency
MERGE `{PROJECT_ID}.{STAGING_DATASET}.dim_format` T
USING (
  SELECT 1 as format_id, 'TEST' as format_name, 'Test Cricket' as description
  UNION ALL
  SELECT 2, 'ODI', 'One Day International'
  UNION ALL
  SELECT 3, 'T20I', 'Twenty20 International'
) S
ON T.format_id = S.format_id
WHEN NOT MATCHED THEN
  INSERT (format_id, format_name, description)
  VALUES (S.format_id, S.format_name, S.description);
