-- Create STAGING layer - Dimension: Date
-- Generates date dimension for a 10-year period
-- Note: Dataset names are placeholders - substitute {STAGING_DATASET} with actual dataset name from config

CREATE OR REPLACE TABLE `{PROJECT_ID}.{STAGING_DATASET}.dim_date` (
  date_id INT64 NOT NULL,
  full_date DATE NOT NULL,
  year INT64,
  quarter INT64,
  month INT64,
  day INT64,
  week INT64,
  day_of_week INT64,
  day_name STRING,
  month_name STRING,
  PRIMARY KEY (date_id) NOT ENFORCED
)
OPTIONS (
  description="Date dimension for time series analysis"
);

-- Generate dates from 2015 to 2035
INSERT INTO `{PROJECT_ID}.{STAGING_DATASET}.dim_date`
SELECT
  CAST(FORMAT_DATE('%Y%m%d', d) AS INT64) as date_id,
  d as full_date,
  EXTRACT(YEAR FROM d) as year,
  EXTRACT(QUARTER FROM d) as quarter,
  EXTRACT(MONTH FROM d) as month,
  EXTRACT(DAY FROM d) as day,
  EXTRACT(WEEK FROM d) as week,
  EXTRACT(DAYOFWEEK FROM d) as day_of_week,
  FORMAT_DATE('%A', d) as day_name,
  FORMAT_DATE('%B', d) as month_name
FROM (
  SELECT DATE_ADD('2015-01-01', INTERVAL CAST(ROW_NUMBER() OVER() - 1 AS INT64) DAY) as d
  FROM UNNEST(GENERATE_ARRAY(1, 7305)) -- 20 years of dates
) dates
ORDER BY d;
