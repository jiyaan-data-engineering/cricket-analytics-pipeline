-- Create STAGING layer - Dimension: Country

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_staging.dim_country` (
  country_id STRING NOT NULL,
  country_name STRING,
  icc_code STRING,
  last_updated TIMESTAMP NOT NULL,
  PRIMARY KEY (country_id) NOT ENFORCED
)
OPTIONS (
  description="Country dimension for cricket teams",
  require_partition_filter=FALSE
);

-- Merge logic to upsert country data
MERGE `{PROJECT_ID}.cricket_staging.dim_country` T
USING (
  SELECT DISTINCT
    country_id,
    MAX(country) as country_name,
    CURRENT_TIMESTAMP() as last_updated
  FROM `{PROJECT_ID}.cricket_raw.batting_rankings`
  WHERE country_id IS NOT NULL
  GROUP BY country_id
) S
ON T.country_id = S.country_id
WHEN MATCHED THEN
  UPDATE SET
    country_name = S.country_name,
    last_updated = S.last_updated
WHEN NOT MATCHED THEN
  INSERT (country_id, country_name, last_updated)
  VALUES (S.country_id, S.country_name, CURRENT_TIMESTAMP());

-- Populate ICC codes (manual mapping or from external source)
UPDATE `{PROJECT_ID}.cricket_staging.dim_country`
SET icc_code = CASE country_name
  WHEN 'India' THEN 'IND'
  WHEN 'Australia' THEN 'AUS'
  WHEN 'Pakistan' THEN 'PAK'
  WHEN 'England' THEN 'ENG'
  WHEN 'South Africa' THEN 'RSA'
  WHEN 'West Indies' THEN 'WI'
  WHEN 'New Zealand' THEN 'NZ'
  WHEN 'Sri Lanka' THEN 'SL'
  WHEN 'Bangladesh' THEN 'BAN'
  WHEN 'Afghanistan' THEN 'AFG'
  ELSE 'UNK'
END
WHERE icc_code IS NULL;
