-- ============================================================================
-- 03_database_schema.sql
-- ============================================================================

CREATE DATABASE IF NOT EXISTS marketing_analytics;
USE marketing_analytics;


-- ============================================================================
-- SECTION A: DIMENSION TABLES
-- ============================================================================

DROP TABLE IF EXISTS dim_customer;

CREATE TABLE dim_customer (
    customer_key         INT AUTO_INCREMENT PRIMARY KEY,
    customer_id          VARCHAR(20) NOT NULL UNIQUE,
    customer_name        VARCHAR(150),
    email                VARCHAR(150),
    country              VARCHAR(100),
    region               VARCHAR(100),
    industry             VARCHAR(100),
    acquisition_channel  VARCHAR(50),
    signup_date          DATE
);


DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_date (
    date_key      INT PRIMARY KEY,
    full_date     DATE NOT NULL,
    `day`         INT,
    `month`       INT,
    month_name    VARCHAR(20),
    quarter       INT,
    `year`        INT,
    `week`        INT,
    `year_month`  VARCHAR(7)
);


DROP TABLE IF EXISTS dim_channel;

CREATE TABLE dim_channel (
    channel_key   INT AUTO_INCREMENT PRIMARY KEY,
    channel_name  VARCHAR(50) NOT NULL UNIQUE,
    channel_type  VARCHAR(50)
);


DROP TABLE IF EXISTS dim_campaign;

CREATE TABLE dim_campaign (
    campaign_key   INT AUTO_INCREMENT PRIMARY KEY,
    campaign_id    VARCHAR(20) NOT NULL UNIQUE,
    campaign_name  VARCHAR(150),
    channel_key    INT,
    campaign_type  VARCHAR(50),
    start_date     DATE,
    end_date       DATE,
    CONSTRAINT fk_campaign_channel
        FOREIGN KEY (channel_key)
        REFERENCES dim_channel(channel_key)
);


-- ============================================================================
-- SECTION B: FACT TABLES
-- ============================================================================

DROP TABLE IF EXISTS fact_marketing_spend;

CREATE TABLE fact_marketing_spend (
    spend_fact_id  BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_key       INT NOT NULL,
    campaign_key   INT NOT NULL,
    channel_key    INT NOT NULL,
    spend          DECIMAL(12,2),
    CONSTRAINT fk_spend_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),
    CONSTRAINT fk_spend_campaign
        FOREIGN KEY (campaign_key)
        REFERENCES dim_campaign(campaign_key),
    CONSTRAINT fk_spend_channel
        FOREIGN KEY (channel_key)
        REFERENCES dim_channel(channel_key)
);


DROP TABLE IF EXISTS fact_campaign_performance;

CREATE TABLE fact_campaign_performance (
    performance_fact_id  BIGINT AUTO_INCREMENT PRIMARY KEY,
    date_key             INT NOT NULL,
    campaign_key        INT NOT NULL,
    channel_key         INT NOT NULL,
    impressions         INT,
    clicks              INT,
    leads               INT,
    CONSTRAINT fk_perf_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),
    CONSTRAINT fk_perf_campaign
        FOREIGN KEY (campaign_key)
        REFERENCES dim_campaign(campaign_key),
    CONSTRAINT fk_perf_channel
        FOREIGN KEY (channel_key)
        REFERENCES dim_channel(channel_key)
);


DROP TABLE IF EXISTS fact_customer_revenue;

CREATE TABLE fact_customer_revenue (
    transaction_id  VARCHAR(20) PRIMARY KEY,
    customer_key    INT NOT NULL,
    campaign_key    INT,
    date_key        INT NOT NULL,
    revenue         DECIMAL(12,2),
    is_refund       BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_revenue_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_revenue_campaign
        FOREIGN KEY (campaign_key)
        REFERENCES dim_campaign(campaign_key),
    CONSTRAINT fk_revenue_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key)
);


DROP TABLE IF EXISTS fact_customer_activity;

CREATE TABLE fact_customer_activity (
    activity_id    VARCHAR(20) PRIMARY KEY,
    customer_key   INT NOT NULL,
    date_key       INT NOT NULL,
    activity_type  VARCHAR(50),
    CONSTRAINT fk_activity_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_activity_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key)
);


DROP TABLE IF EXISTS fact_conversions;

CREATE TABLE fact_conversions (
    conversion_id      VARCHAR(20) PRIMARY KEY,
    customer_key       INT NOT NULL,
    campaign_key       INT NOT NULL,
    date_key           INT NOT NULL,
    conversion_stage   VARCHAR(30),
    CONSTRAINT fk_conv_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer(customer_key),
    CONSTRAINT fk_conv_campaign
        FOREIGN KEY (campaign_key)
        REFERENCES dim_campaign(campaign_key),
    CONSTRAINT fk_conv_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key)
);


-- ============================================================================
-- SECTION C: INDEXES
-- ============================================================================

CREATE INDEX idx_spend_date
    ON fact_marketing_spend(date_key);

CREATE INDEX idx_spend_campaign
    ON fact_marketing_spend(campaign_key);


CREATE INDEX idx_perf_date
    ON fact_campaign_performance(date_key);

CREATE INDEX idx_perf_campaign
    ON fact_campaign_performance(campaign_key);


CREATE INDEX idx_revenue_customer
    ON fact_customer_revenue(customer_key);

CREATE INDEX idx_revenue_date
    ON fact_customer_revenue(date_key);

CREATE INDEX idx_revenue_campaign
    ON fact_customer_revenue(campaign_key);


CREATE INDEX idx_activity_customer
    ON fact_customer_activity(customer_key);

CREATE INDEX idx_activity_date
    ON fact_customer_activity(date_key);


CREATE INDEX idx_conv_customer
    ON fact_conversions(customer_key);

CREATE INDEX idx_conv_campaign
    ON fact_conversions(campaign_key);

CREATE INDEX idx_conv_date
    ON fact_conversions(date_key);