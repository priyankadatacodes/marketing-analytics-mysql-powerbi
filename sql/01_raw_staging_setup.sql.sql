-- ============================================================================
-- 01_raw_staging_setup.sql
-- ============================================================================

CREATE DATABASE IF NOT EXISTS marketing_analytics;
USE marketing_analytics;


-- ============================================================================
-- RAW STAGING TABLES
-- ============================================================================

DROP TABLE IF EXISTS raw_customers;
CREATE TABLE raw_customers (
    customer_id           VARCHAR(50),
    customer_name         VARCHAR(200),
    email                 VARCHAR(200),
    signup_date           VARCHAR(50),
    country               VARCHAR(100),
    region                VARCHAR(100),
    industry              VARCHAR(100),
    acquisition_channel   VARCHAR(100)
);

DROP TABLE IF EXISTS raw_campaigns;
CREATE TABLE raw_campaigns (
    campaign_id     VARCHAR(50),
    campaign_name   VARCHAR(200),
    channel         VARCHAR(100),
    campaign_type   VARCHAR(100),
    start_date      VARCHAR(50),
    end_date        VARCHAR(50)
);

DROP TABLE IF EXISTS raw_campaign_performance;
CREATE TABLE raw_campaign_performance (
    campaign_id   VARCHAR(50),
    `date`        VARCHAR(50),
    impressions   VARCHAR(50),
    clicks        VARCHAR(50),
    leads         VARCHAR(50),
    spend         VARCHAR(50)
);

DROP TABLE IF EXISTS raw_conversions;
CREATE TABLE raw_conversions (
    conversion_id       VARCHAR(50),
    customer_id         VARCHAR(50),
    campaign_id         VARCHAR(50),
    conversion_date     VARCHAR(50),
    conversion_stage    VARCHAR(50)
);

DROP TABLE IF EXISTS raw_transactions;
CREATE TABLE raw_transactions (
    transaction_id     VARCHAR(50),
    customer_id        VARCHAR(50),
    campaign_id        VARCHAR(50),
    transaction_date   VARCHAR(50),
    revenue            VARCHAR(50)
);

DROP TABLE IF EXISTS raw_activity;
CREATE TABLE raw_activity (
    activity_id       VARCHAR(50),
    customer_id       VARCHAR(50),
    activity_date     VARCHAR(50),
    activity_type     VARCHAR(50)
);


-- ============================================================================
-- LOAD DATA
-- ============================================================================

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE raw_customers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/campaigns.csv'
INTO TABLE raw_campaigns
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/campaign_performance.csv'
INTO TABLE raw_campaign_performance
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/conversions.csv'
INTO TABLE raw_conversions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/transactions.csv'
INTO TABLE raw_transactions
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

TRUNCATE TABLE raw_activity;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/activity.csv'
INTO TABLE raw_activity
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


-- ============================================================================
-- VERIFY LOAD
-- ============================================================================

SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count FROM raw_customers
UNION ALL SELECT 'raw_campaigns', COUNT(*) FROM raw_campaigns
UNION ALL SELECT 'raw_campaign_performance', COUNT(*) FROM raw_campaign_performance
UNION ALL SELECT 'raw_conversions', COUNT(*) FROM raw_conversions
UNION ALL SELECT 'raw_transactions', COUNT(*) FROM raw_transactions
UNION ALL SELECT 'raw_activity', COUNT(*) FROM raw_activity;

