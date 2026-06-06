-- Create STAGING layer - Dimension: Format

CREATE OR REPLACE TABLE `{PROJECT_ID}.cricket_staging.dim_format` (
  format_id INT64 NOT NULL,
  format_name STRING NOT NULL,
  description STRING,
  PRIMARY KEY (format_id) NOT ENFORCED
)
OPTIONS (
  description="Cricket format dimension (Test, ODI, T20I)"
);

-- Insert format values
INSERT INTO `{PROJECT_ID}.cricket_staging.dim_format`
  (format_id, format_name, description)
VALUES
  (1, 'TEST', 'Test Cricket'),
  (2, 'ODI', 'One Day International'),
  (3, 'T20I', 'Twenty20 International')
ON CONFLICT DO NOTHING;
