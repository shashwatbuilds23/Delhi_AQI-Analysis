-- Step 1 : Create a database : 

CREATE DATABASE AQI_project;
USE AQI_project;

-- step 2: Import cleaned dataset after exploration : 
-- successfully imported 

-- Step 1) Quick checks & schema info: 

-- Confirm table & row count
SHOW TABLES;
SELECT COUNT(*) AS total_rows FROM delhi_aqi_cleaned;

-- change table name for ease : 

ALTER TABLE delhi_aqi_cleaned 
RENAME TO delhi_aqi;

-- change column name for queries become cleaner and error free :

ALTER TABLE delhi_aqi
CHANGE COLUMN `PM2.5` PM25 FLOAT,
CHANGE COLUMN `PM10` PM10 FLOAT,
CHANGE COLUMN `NO2` NO2 FLOAT,
CHANGE COLUMN `SO2` SO2 FLOAT,
CHANGE COLUMN `CO` CO FLOAT,
CHANGE COLUMN `Ozone` Ozone FLOAT;

-- Add a primary key :

ALTER TABLE delhi_aqi
ADD COLUMN id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;

describe delhi_aqi;

-- Null / data quality checks :

SELECT 
  COUNT(*) total_rows,
  SUM(Date IS NULL) AS date_nulls,
  SUM(PM25 IS NULL) AS pm25_nulls,
  SUM(PM10 IS NULL) AS pm10_nulls,
  SUM(AQI IS NULL)  AS aqi_nulls
FROM delhi_aqi;


-- AQI CATEGORY : 

-- 1.1 Check distinct categories & counts
SELECT AQI_Category, COUNT(*) AS cnt
FROM delhi_aqi
GROUP BY AQI_Category
ORDER BY cnt DESC;

-- 1.2 Check for NULL / empty values
SELECT 
  SUM(AQI_Category IS NULL) AS null_count,
  SUM(TRIM(AQI_Category) = '') AS empty_count
FROM delhi_aqi;

-- For Power BI dashboards

UPDATE delhi_aqi
SET AQI_Category = CASE
  WHEN AQI <= 50 THEN 'Good'
  WHEN AQI <= 100 THEN 'Satisfactory'
  WHEN AQI <= 200 THEN 'Moderate'
  WHEN AQI <= 300 THEN 'Poor'
  WHEN AQI <= 400 THEN 'Very Poor'
  WHEN AQI <= 500 THEN 'Severe'
END;
-- Use these six categories only:
-- Good, Satisfactory, Moderate, Poor, Very Poor, Severe
-- and order them properly for charts:

SELECT AQI_Category, COUNT(*) AS days
FROM delhi_aqi
GROUP BY AQI_Category
ORDER BY FIELD(AQI_Category, 
  'Good','Satisfactory','Moderate','Poor','Very Poor','Severe');
  
-- Check column types & sample rows

DESCRIBE delhi_aqi;
SELECT * FROM delhi_aqi LIMIT 10;

-- STEP 2 : 2) Basic summaries : 
-- Basic aggregate stats
SELECT 
  ROUND(AVG(AQI),2) AS avg_aqi,
  ROUND(MIN(AQI),2) AS min_aqi,
  ROUND(MAX(AQI),2) AS max_aqi
FROM delhi_aqi;

-- Year wise averages
SELECT Year, ROUND(AVG(AQI),2) AS avg_aqi
FROM delhi_aqi
GROUP BY Year
ORDER BY Year;

-- Month wise averages (useful for seasonal pattern)
SELECT Month, ROUND(AVG(AQI),2) AS avg_aqi
FROM delhi_aqi
GROUP BY Month
ORDER BY FIELD(Month,'January','February','March','April','May','June','July','August','September','October','November','December');


-- STEP 3) Seasonal / Quarter analysis :

-- Average AQI by Quarter and Year
SELECT Year, Quarter, ROUND(AVG(AQI),2) AS avg_aqi
FROM delhi_aqi
GROUP BY Year, Quarter
ORDER BY Year, Quarter;

-- Which quarter is worst overall
SELECT Quarter, ROUND(AVG(AQI),2) AS avg_aqi
FROM delhi_aqi
GROUP BY Quarter
ORDER BY avg_aqi DESC;

-- STEP 4) Holiday vs Non-holiday analysis :

SELECT Holiday, ROUND(AVG(AQI),2) AS avg_aqi, COUNT(*) AS total_rows
FROM delhi_aqi
GROUP BY Holiday;

-- Compare by Year and Holiday
SELECT Year, Holiday, ROUND(AVG(AQI),2) AS avg_aqi
FROM delhi_aqi
GROUP BY Year, Holiday
ORDER BY Year;

-- STEP 5) Distribution and categories :

SELECT AQI_Category, COUNT(*) AS cnt
FROM delhi_aqi
GROUP BY AQI_Category
ORDER BY cnt DESC;

-- STEP 6) Top / worst days and pollutant peaks :

-- Top 10 worst AQI days
SELECT Date, Year, AQI
FROM delhi_aqi
ORDER BY AQI DESC
LIMIT 10;

-- Days with highest PM2.5
SELECT Date, PM25
FROM delhi_aqi
ORDER BY PM25 DESC
LIMIT 10;

-- STEP 7) Correlation / relationship (approximate):

-- Pearson correlation between PM2.5 and AQI

SELECT
  ROUND(
    (SUM((PM25 - avg_pm25) * (AQI - avg_aqi)) /
     SQRT(SUM(POW(PM25 - avg_pm25,2)) * SUM(POW(AQI - avg_aqi,2))))
  , 3) AS corr_pm25_aqi
FROM (
  SELECT PM25, AQI,
         (SELECT AVG(PM25) FROM delhi_aqi) AS avg_pm25,
         (SELECT AVG(AQI)  FROM delhi_aqi) AS avg_aqi
  FROM delhi_aqi
) t;

-- PM10 vs AQI
SELECT
ROUND(
  (SUM((PM10 - avg_pm10) * (AQI - avg_aqi)) /
   SQRT(SUM(POW(PM10 - avg_pm10,2)) * SUM(POW(AQI - avg_aqi,2)))) ,3) AS corr_PM10_AQI
FROM (
  SELECT PM10, AQI,
         (SELECT AVG(PM10) FROM delhi_aqi) AS avg_pm10,
         (SELECT AVG(AQI)  FROM delhi_aqi) AS avg_aqi
  FROM delhi_aqi
) t;

-- NO2 vs AQI
SELECT
ROUND(
  (SUM((NO2 - avg_no2) * (AQI - avg_aqi)) /
   SQRT(SUM(POW(NO2 - avg_no2,2)) * SUM(POW(AQI - avg_aqi,2)))) , 3)AS corr_NO2_AQI
FROM (
  SELECT NO2, AQI,
         (SELECT AVG(NO2) FROM delhi_aqi) AS avg_no2,
         (SELECT AVG(AQI)  FROM delhi_aqi) AS avg_aqi
  FROM delhi_aqi
) t;

-- STEP 8) Time series / rolling averages (useful in dashboards):

-- Daily 7-day rolling average : 
SELECT Date, AQI,
  ROUND(AVG(AQI) OVER (ORDER BY Date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS aqi_7day_ma
FROM delhi_aqi
ORDER BY Date;

-- Monthly average and month-over-month change
SELECT Year, Month,
  ROUND(AVG(AQI),2) AS avg_aqi,
  ROUND(AVG(AQI) - LAG(AVG(AQI)) OVER (ORDER BY Year, FIELD(Month,'January','February','March','April','May','June','July','August','September','October','November','December')),2) AS mom_change
FROM delhi_aqi
GROUP BY Year, Month
ORDER BY Year, Month;


-- STEP 10) Indexing & performance :


-- Index on Date and Year for faster time queries
CREATE INDEX idx_date ON delhi_aqi(Date);
CREATE INDEX idx_year ON delhi_aqi(Year);
CREATE INDEX idx_aqi ON delhi_aqi(AQI);
CREATE INDEX idx_monthnum ON delhi_aqi(Month_num);
CREATE INDEX idx_year_month ON delhi_aqi(Year, Month_num);


SHOW INDEX FROM delhi_aqi;

-- confirm views exist : 

SHOW FULL TABLES WHERE TABLE_TYPE = 'VIEW';

-- verify rows and some aggregates match your Python results
SELECT COUNT(*) FROM delhi_aqi;
SELECT Year, ROUND(AVG(AQI),2) FROM delhi_aqi GROUP BY Year ORDER BY Year;

-- check indexes
SHOW INDEX FROM delhi_aqi;

-- Month should be numeric for sorting & indexing:

ALTER TABLE delhi_aqi ADD COLUMN Month_num TINYINT;
UPDATE delhi_aqi
SET Month_num = CASE
  WHEN Month='January' THEN 1 WHEN Month='February' THEN 2 WHEN Month='March' THEN 3
  WHEN Month='April' THEN 4 WHEN Month='May' THEN 5 WHEN Month='June' THEN 6
  WHEN Month='July' THEN 7 WHEN Month='August' THEN 8 WHEN Month='September' THEN 9
  WHEN Month='October' THEN 10 WHEN Month='November' THEN 11 WHEN Month='December' THEN 12
END;
CREATE INDEX idx_monthnum ON delhi_aqi(Month_num);

-- Views vs materialized tables:


--  Refresh materialized summary table for dashboards
-- (Recreate it whenever new AQI data is imported)

DROP TABLE IF EXISTS monthly_metrics;

CREATE TABLE monthly_metrics AS
SELECT 
    Year, 
    Month_num, 
    Month,
    ROUND(AVG(AQI), 2) AS avg_aqi,
    ROUND(AVG(PM25), 2) AS avg_pm25,
    ROUND(AVG(PM10), 2) AS avg_pm10,
    ROUND(AVG(NO2), 2) AS avg_no2,
    ROUND(AVG(SO2), 2) AS avg_so2,
    ROUND(AVG(CO), 2) AS avg_co,
    ROUND(AVG(Ozone), 2) AS avg_ozone,
    COUNT(*) AS total_days
FROM delhi_aqi
GROUP BY Year, Month_num, Month;

-- To refresh later: just re-run this block after loading new CSV data


DESCRIBE monthly_metrics;


-- Create convenient views for dashboards :

-- monthly metrics (Year + Month_num helps sorting)

CREATE OR REPLACE VIEW vw_monthly_metrics AS
SELECT 
    Year,
    MONTH(Date) AS Month_num,
    Month,
    ROUND(AVG(AQI), 2) AS avg_aqi,
    ROUND(AVG(PM25), 2) AS avg_pm25,
    ROUND(AVG(PM10), 2) AS avg_pm10,
    ROUND(AVG(NO2), 2) AS avg_no2,
    COUNT(*) AS days
FROM delhi_aqi
GROUP BY Year, MONTH(Date), Month;
-- Note: do ordering when you SELECT FROM this view (e.g. ORDER BY Year, Month_num)


SHOW FULL TABLES WHERE TABLE_TYPE = 'VIEW';


-- quarterly metrics

CREATE OR REPLACE VIEW vw_quarterly_aqi AS
SELECT Year, Quarter, ROUND(AVG(AQI),2) AS avg_aqi
FROM delhi_aqi
GROUP BY Year, Quarter
ORDER BY Year, Quarter;


-- yearly metrics (if not already)
CREATE OR REPLACE VIEW vw_yearly_aqi AS
SELECT Year, ROUND(AVG(AQI),2) AS avg_aqi, COUNT(*) AS days
FROM delhi_aqi
GROUP BY Year;


-- KPI Summary View (for Power BI dashboards) :

CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT 
  ROUND(AVG(AQI),2) AS avg_aqi_overall,
  (SELECT Date FROM delhi_aqi ORDER BY AQI DESC LIMIT 1) AS worst_date,
  (SELECT AQI FROM delhi_aqi ORDER BY AQI DESC LIMIT 1) AS worst_aqi,
  (SELECT Date FROM delhi_aqi ORDER BY AQI ASC LIMIT 1) AS best_date,
  (SELECT AQI FROM delhi_aqi ORDER BY AQI ASC LIMIT 1) AS best_aqi
FROM delhi_aqi;

SELECT * FROM vw_kpi_summary;

-- ===========================
-- TEST SECTION (optional)
-- Run these manually for verification
-- ===========================

SELECT * FROM vw_yearly_aqi LIMIT 10;
SELECT * FROM vw_quarterly_aqi LIMIT 10;
SELECT * FROM vw_monthly_metrics LIMIT 10;
SELECT * FROM monthly_metrics LIMIT 10;
SELECT * FROM vw_pollutant_corr;

-- Correlations (rounded) :
--  This version computes global averages once (via a derived single-row stats) and uses them in each pollutant block:

-- (rest of your correlation query here)


DROP VIEW IF EXISTS vw_pollutant_corr;

CREATE OR REPLACE VIEW vw_pollutant_corr AS
SELECT 'PM25' AS Pollutant, ROUND(corr,3) AS correlation FROM (
  SELECT 
    (SUM((PM25 - AVG_PM25)*(AQI - AVG_AQI)) /
     (NULLIF(SQRT(SUM(POW(PM25 - AVG_PM25,2))),0) * NULLIF(SQRT(SUM(POW(AQI - AVG_AQI,2))),0))
    ) AS corr
  FROM (
    SELECT PM25, AQI,
      (SELECT AVG(PM25) FROM delhi_aqi) AS AVG_PM25,
      (SELECT AVG(AQI)  FROM delhi_aqi) AS AVG_AQI
    FROM delhi_aqi
  ) t1
) x
UNION ALL
SELECT 'PM10', ROUND(corr,3) FROM (
  SELECT 
    (SUM((PM10 - AVG_PM10)*(AQI - AVG_AQI)) /
     (NULLIF(SQRT(SUM(POW(PM10 - AVG_PM10,2))),0) * NULLIF(SQRT(SUM(POW(AQI - AVG_AQI,2))),0))
    ) AS corr
  FROM (
    SELECT PM10, AQI,
      (SELECT AVG(PM10) FROM delhi_aqi) AS AVG_PM10,
      (SELECT AVG(AQI)  FROM delhi_aqi) AS AVG_AQI
    FROM delhi_aqi
  ) t2
) y
UNION ALL
SELECT 'NO2', ROUND(corr,3) FROM (
  SELECT 
    (SUM((NO2 - AVG_NO2)*(AQI - AVG_AQI)) /
     (NULLIF(SQRT(SUM(POW(NO2 - AVG_NO2,2))),0) * NULLIF(SQRT(SUM(POW(AQI - AVG_AQI,2))),0))
    ) AS corr
  FROM (
    SELECT NO2, AQI,
      (SELECT AVG(NO2) FROM delhi_aqi) AS AVG_NO2,
      (SELECT AVG(AQI)  FROM delhi_aqi) AS AVG_AQI
    FROM delhi_aqi
  ) t3
) z
UNION ALL
SELECT 'SO2', ROUND(corr,3) FROM (
  SELECT 
    (SUM((SO2 - AVG_SO2)*(AQI - AVG_AQI)) /
     (NULLIF(SQRT(SUM(POW(SO2 - AVG_SO2,2))),0) * NULLIF(SQRT(SUM(POW(AQI - AVG_AQI,2))),0))
    ) AS corr
  FROM (
    SELECT SO2, AQI,
      (SELECT AVG(SO2) FROM delhi_aqi) AS AVG_SO2,
      (SELECT AVG(AQI)  FROM delhi_aqi) AS AVG_AQI
    FROM delhi_aqi
  ) t4
) a
UNION ALL
SELECT 'CO', ROUND(corr,3) FROM (
  SELECT 
    (SUM((CO - AVG_CO)*(AQI - AVG_AQI)) /
     (NULLIF(SQRT(SUM(POW(CO - AVG_CO,2))),0) * NULLIF(SQRT(SUM(POW(AQI - AVG_AQI,2))),0))
    ) AS corr
  FROM (
    SELECT CO, AQI,
      (SELECT AVG(CO) FROM delhi_aqi) AS AVG_CO,
      (SELECT AVG(AQI)  FROM delhi_aqi) AS AVG_AQI
    FROM delhi_aqi
  ) t5
) b
UNION ALL
SELECT 'Ozone', ROUND(corr,3) FROM (
  SELECT 
    (SUM((Ozone - AVG_OZONE)*(AQI - AVG_AQI)) /
     (NULLIF(SQRT(SUM(POW(Ozone - AVG_OZONE,2))),0) * NULLIF(SQRT(SUM(POW(AQI - AVG_AQI,2))),0))
    ) AS corr
  FROM (
    SELECT Ozone, AQI,
      (SELECT AVG(Ozone) FROM delhi_aqi) AS AVG_OZONE,
      (SELECT AVG(AQI)  FROM delhi_aqi) AS AVG_AQI
    FROM delhi_aqi
  ) t6
) c;

SELECT * FROM vw_pollutant_corr;




-- Useful analytics queries to run now:

-- 1. Average AQI by quarter:

SELECT Quarter, ROUND(AVG(AQI),2) AS avg_aqi FROM delhi_aqi GROUP BY Quarter ORDER BY avg_aqi DESC;

-- 2. Holiday effect by year:

SELECT Year, Holiday, ROUND(AVG(AQI),2) AS avg_aqi FROM delhi_aqi GROUP BY Year, Holiday ORDER BY Year;

-- 3. Top worst days:

SELECT Date, AQI FROM delhi_aqi ORDER BY AQI DESC LIMIT 10;


-- Quick verification commands

-- check month_num index & indexes
DESCRIBE delhi_aqi;

SHOW INDEX FROM delhi_aqi;

-- check views exist
SHOW FULL TABLES WHERE TABLE_TYPE='VIEW';

-- sanity compare with pandas (if you still have df)

SELECT COUNT(*) FROM delhi_aqi;
SELECT Year, ROUND(AVG(AQI),2) FROM delhi_aqi GROUP BY Year ORDER BY Year;
