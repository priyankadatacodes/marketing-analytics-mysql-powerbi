-- ============================================================================
-- 02_data_cleaning.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- CLEANED STAGING TABLES
-- ============================================================================

DROP TABLE IF EXISTS stg_customers;

CREATE TABLE stg_customers (
    customer_id           VARCHAR(20),
    customer_name         VARCHAR(150),
    email                 VARCHAR(150),
    signup_date           DATE,
    country               VARCHAR(100),
    region                VARCHAR(100),
    industry              VARCHAR(100),
    acquisition_channel   VARCHAR(50)
);


DROP TABLE IF EXISTS stg_campaigns;

CREATE TABLE stg_campaigns (
    campaign_id     VARCHAR(20),
    campaign_name   VARCHAR(150),
    channel         VARCHAR(50),
    campaign_type   VARCHAR(50),
    start_date      DATE,
    end_date        DATE
);


DROP TABLE IF EXISTS stg_campaign_performance;

CREATE TABLE stg_campaign_performance (
    campaign_id   VARCHAR(20),
    `date`        DATE,
    impressions   INT,
    clicks        INT,
    leads         INT,
    spend         DECIMAL(12,2)
);


DROP TABLE IF EXISTS stg_conversions;

CREATE TABLE stg_conversions (
    conversion_id      VARCHAR(20),
    customer_id        VARCHAR(20),
    campaign_id        VARCHAR(20),
    conversion_date    DATE,
    conversion_stage   VARCHAR(30)
);


DROP TABLE IF EXISTS stg_transactions;

CREATE TABLE stg_transactions (
    transaction_id     VARCHAR(20),
    customer_id        VARCHAR(20),
    campaign_id        VARCHAR(20),
    transaction_date   DATE,
    revenue            DECIMAL(12,2),
    is_refund          BOOLEAN
);


DROP TABLE IF EXISTS stg_activity;

CREATE TABLE stg_activity (
    activity_id     VARCHAR(20),
    customer_id     VARCHAR(20),
    activity_date   DATE,
    activity_type   VARCHAR(50)
);


-- ============================================================================
-- CLEAN: Customers
-- ============================================================================

INSERT INTO stg_customers (
    customer_id,
    customer_name,
    email,
    signup_date,
    country,
    region,
    industry,
    acquisition_channel
)
WITH normalized AS (
    SELECT
        NULLIF(TRIM(customer_id), '') AS customer_id,
        NULLIF(TRIM(customer_name), '') AS customer_name,
        NULLIF(TRIM(email), '') AS email,
        signup_date,

        CASE
            WHEN LOWER(TRIM(country)) IN ('india','in') THEN 'India'
            WHEN LOWER(TRIM(country)) IN ('united states','usa','u.s.a','us') THEN 'United States'
            WHEN LOWER(TRIM(country)) IN ('united kingdom','uk','u.k.','england') THEN 'United Kingdom'
            WHEN LOWER(TRIM(country)) IN ('germany','de') THEN 'Germany'
            WHEN LOWER(TRIM(country)) IN ('canada','ca') THEN 'Canada'
            WHEN LOWER(TRIM(country)) IN ('australia','aus') THEN 'Australia'
            WHEN LOWER(TRIM(country)) IN ('uae','u.a.e','united arab emirates') THEN 'UAE'
            WHEN LOWER(TRIM(country)) IN ('singapore','sg') THEN 'Singapore'
            WHEN LOWER(TRIM(country)) IN ('france','fr') THEN 'France'
            WHEN LOWER(TRIM(country)) IN ('brazil','br') THEN 'Brazil'
            ELSE TRIM(country)
        END AS country,

        NULLIF(TRIM(region), '') AS region,
        NULLIF(TRIM(industry), '') AS industry,

        CASE
            WHEN LOWER(TRIM(acquisition_channel)) IN
                ('paid search','paid-search','ppc','google ads')
                THEN 'Paid Search'
            WHEN LOWER(TRIM(acquisition_channel)) IN
                ('social','facebook ads','instagram','social media')
                THEN 'Social'
            WHEN LOWER(TRIM(acquisition_channel)) IN
                ('email','e-mail','email marketing')
                THEN 'Email'
            WHEN LOWER(TRIM(acquisition_channel)) IN
                ('organic','organic search','seo')
                THEN 'Organic'
            WHEN LOWER(TRIM(acquisition_channel)) IN
                ('referral','referal')
                THEN 'Referral'
            WHEN LOWER(TRIM(acquisition_channel)) IN
                ('display','display ads','banner')
                THEN 'Display'
            WHEN LOWER(TRIM(acquisition_channel)) IN
                ('affiliate','affliate','partner')
                THEN 'Affiliate'
            ELSE TRIM(acquisition_channel)
        END AS acquisition_channel

    FROM raw_customers
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY (email IS NULL) ASC, customer_id
        ) AS rn
    FROM normalized
    WHERE customer_id IS NOT NULL
)

SELECT
    customer_id,
    customer_name,
    email,

    CASE
        WHEN signup_date IS NULL OR TRIM(signup_date) = '' THEN NULL
        WHEN signup_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(signup_date, '%Y-%m-%d')
        WHEN signup_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%d-%m-%Y')
        WHEN signup_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%m/%d/%Y')
        WHEN signup_date REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%d %b %Y')
        ELSE NULL
    END,

    country,
    region,
    industry,
    acquisition_channel

FROM deduped
WHERE rn = 1;

SELECT COUNT(*) AS stg_customers_rows
FROM stg_customers;

ALTER TABLE stg_customers
ADD PRIMARY KEY (customer_id);


-- ============================================================================
-- CLEAN: Campaigns
-- ============================================================================

INSERT INTO stg_campaigns (
    campaign_id,
    campaign_name,
    channel,
    campaign_type,
    start_date,
    end_date
)
WITH normalized AS (
    SELECT
        NULLIF(TRIM(campaign_id), '') AS campaign_id,
        NULLIF(TRIM(campaign_name), '') AS campaign_name,

        CASE
            WHEN LOWER(TRIM(channel)) IN
                ('paid search','paid-search','ppc','google ads')
                THEN 'Paid Search'
            WHEN LOWER(TRIM(channel)) IN
                ('social','facebook ads','instagram','social media')
                THEN 'Social'
            WHEN LOWER(TRIM(channel)) IN
                ('email','e-mail','email marketing')
                THEN 'Email'
            WHEN LOWER(TRIM(channel)) IN
                ('organic','organic search','seo')
                THEN 'Organic'
            WHEN LOWER(TRIM(channel)) IN
                ('referral','referal')
                THEN 'Referral'
            WHEN LOWER(TRIM(channel)) IN
                ('display','display ads','banner')
                THEN 'Display'
            WHEN LOWER(TRIM(channel)) IN
                ('affiliate','affliate','partner')
                THEN 'Affiliate'
            ELSE TRIM(channel)
        END AS channel,

        NULLIF(TRIM(campaign_type), '') AS campaign_type,
        start_date,
        end_date

    FROM raw_campaigns
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id
            ORDER BY campaign_id
        ) AS rn
    FROM normalized
    WHERE campaign_id IS NOT NULL
)

SELECT
    campaign_id,
    campaign_name,
    channel,
    campaign_type,

    CASE
        WHEN start_date IS NULL OR TRIM(start_date) = '' THEN NULL
        WHEN start_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(start_date, '%Y-%m-%d')
        WHEN start_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(start_date, '%d-%m-%Y')
        WHEN start_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(start_date, '%m/%d/%Y')
        WHEN start_date REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$'
            THEN STR_TO_DATE(start_date, '%d %b %Y')
        ELSE NULL
    END,

    CASE
        WHEN end_date IS NULL OR TRIM(end_date) = '' THEN NULL
        WHEN end_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(end_date, '%Y-%m-%d')
        WHEN end_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(end_date, '%d-%m-%Y')
        WHEN end_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(end_date, '%m/%d/%Y')
        WHEN end_date REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$'
            THEN STR_TO_DATE(end_date, '%d %b %Y')
        ELSE NULL
    END

FROM deduped
WHERE rn = 1;

SELECT COUNT(*) AS stg_campaigns_rows
FROM stg_campaigns;

ALTER TABLE stg_campaigns
ADD PRIMARY KEY (campaign_id);


-- ============================================================================
-- CLEAN: Campaign Performance
-- ============================================================================

INSERT INTO stg_campaign_performance (
    campaign_id,
    `date`,
    impressions,
    clicks,
    leads,
    spend
)
SELECT
    r.campaign_id,

    CASE
        WHEN r.`date` IS NULL OR TRIM(r.`date`) = '' THEN NULL
        WHEN r.`date` REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(r.`date`, '%Y-%m-%d')
        WHEN r.`date` REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(r.`date`, '%d-%m-%Y')
        WHEN r.`date` REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(r.`date`, '%m/%d/%Y')
        WHEN r.`date` REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$'
            THEN STR_TO_DATE(r.`date`, '%d %b %Y')
        ELSE NULL
    END,

    CAST(
        CAST(NULLIF(TRIM(r.impressions), '') AS DECIMAL(12,2))
        AS UNSIGNED
    ),

    CASE
        WHEN CAST(NULLIF(TRIM(r.clicks), '') AS UNSIGNED)
             >
             CAST(
                 CAST(NULLIF(TRIM(r.impressions), '') AS DECIMAL(12,2))
                 AS UNSIGNED
             )
        THEN NULL
        ELSE CAST(NULLIF(TRIM(r.clicks), '') AS UNSIGNED)
    END,

    CAST(NULLIF(TRIM(r.leads), '') AS UNSIGNED),

    CASE
        WHEN r.spend IS NULL OR TRIM(r.spend) = '' THEN NULL
        WHEN REGEXP_REPLACE(r.spend, '[^0-9.-]', '') IN ('', '-', '.') THEN NULL
        WHEN CAST(
            REGEXP_REPLACE(r.spend, '[^0-9.-]', '')
            AS DECIMAL(14,2)
        ) < 0 THEN NULL
        ELSE CAST(
            REGEXP_REPLACE(r.spend, '[^0-9.-]', '')
            AS DECIMAL(14,2)
        )
    END

FROM raw_campaign_performance r
INNER JOIN stg_campaigns c
    ON TRIM(r.campaign_id) = c.campaign_id;

SELECT COUNT(*) AS stg_campaign_performance_rows
FROM stg_campaign_performance;


-- ============================================================================
-- CLEAN: Conversions
-- ============================================================================

INSERT INTO stg_conversions (
    conversion_id,
    customer_id,
    campaign_id,
    conversion_date,
    conversion_stage
)
SELECT
    TRIM(r.conversion_id),
    TRIM(r.customer_id),
    TRIM(r.campaign_id),

    CASE
        WHEN r.conversion_date IS NULL
             OR TRIM(r.conversion_date) = ''
            THEN NULL
        WHEN r.conversion_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(r.conversion_date, '%Y-%m-%d')
        WHEN r.conversion_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(r.conversion_date, '%d-%m-%Y')
        WHEN r.conversion_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(r.conversion_date, '%m/%d/%Y')
        WHEN r.conversion_date REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$'
            THEN STR_TO_DATE(r.conversion_date, '%d %b %Y')
        ELSE NULL
    END,

    COALESCE(
        NULLIF(TRIM(r.conversion_stage), ''),
        'Unknown'
    )

FROM raw_conversions r
INNER JOIN stg_customers cu
    ON TRIM(r.customer_id) = cu.customer_id
INNER JOIN stg_campaigns ca
    ON TRIM(r.campaign_id) = ca.campaign_id;

SELECT COUNT(*) AS stg_conversions_rows
FROM stg_conversions;


-- ============================================================================
-- CLEAN: Transactions
-- ============================================================================

INSERT INTO stg_transactions (
    transaction_id,
    customer_id,
    campaign_id,
    transaction_date,
    revenue,
    is_refund
)
WITH normalized AS (
    SELECT
        NULLIF(TRIM(transaction_id), '') AS transaction_id,
        NULLIF(TRIM(customer_id), '') AS customer_id,
        NULLIF(TRIM(campaign_id), '') AS campaign_id,
        transaction_date,
        revenue

    FROM raw_transactions

    WHERE NOT (
        NULLIF(TRIM(transaction_id), '') IS NULL
        AND NULLIF(TRIM(customer_id), '') IS NULL
        AND NULLIF(TRIM(campaign_id), '') IS NULL
        AND NULLIF(TRIM(transaction_date), '') IS NULL
        AND NULLIF(TRIM(revenue), '') IS NULL
    )
),

required_fields AS (
    SELECT *
    FROM normalized
    WHERE transaction_id IS NOT NULL
      AND customer_id IS NOT NULL
),

deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id
            ORDER BY transaction_id
        ) AS rn

    FROM required_fields
)

SELECT
    d.transaction_id,
    d.customer_id,
    d.campaign_id,

    CASE
        WHEN d.transaction_date IS NULL
             OR TRIM(d.transaction_date) = ''
            THEN NULL
        WHEN d.transaction_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(d.transaction_date, '%Y-%m-%d')
        WHEN d.transaction_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(d.transaction_date, '%d-%m-%Y')
        WHEN d.transaction_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(d.transaction_date, '%m/%d/%Y')
        WHEN d.transaction_date REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$'
            THEN STR_TO_DATE(d.transaction_date, '%d %b %Y')
        ELSE NULL
    END,

    CASE
        WHEN d.revenue IS NULL OR TRIM(d.revenue) = '' THEN NULL
        WHEN REGEXP_REPLACE(d.revenue, '[^0-9.-]', '') IN ('', '-', '.') THEN NULL
        ELSE CAST(
            REGEXP_REPLACE(d.revenue, '[^0-9.-]', '')
            AS DECIMAL(14,2)
        )
    END,

    CASE
        WHEN d.revenue IS NULL OR TRIM(d.revenue) = '' THEN FALSE
        WHEN REGEXP_REPLACE(d.revenue, '[^0-9.-]', '') IN ('', '-', '.') THEN FALSE
        WHEN CAST(
            REGEXP_REPLACE(d.revenue, '[^0-9.-]', '')
            AS DECIMAL(14,2)
        ) < 0 THEN TRUE
        ELSE FALSE
    END

FROM deduped d

INNER JOIN stg_customers cu
    ON d.customer_id = cu.customer_id

WHERE d.rn = 1;

SELECT COUNT(*) AS stg_transactions_rows
FROM stg_transactions;

ALTER TABLE stg_transactions
ADD INDEX idx_txn_customer (customer_id);


-- ============================================================================
-- CLEAN: Activity
-- ============================================================================

INSERT INTO stg_activity (
    activity_id,
    customer_id,
    activity_date,
    activity_type
)
SELECT
    TRIM(r.activity_id),
    TRIM(r.customer_id),

    CASE
        WHEN r.activity_date IS NULL
             OR TRIM(r.activity_date) = ''
            THEN NULL
        WHEN r.activity_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(r.activity_date, '%Y-%m-%d')
        WHEN r.activity_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(r.activity_date, '%d-%m-%Y')
        WHEN r.activity_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(r.activity_date, '%m/%d/%Y')
        WHEN r.activity_date REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$'
            THEN STR_TO_DATE(r.activity_date, '%d %b %Y')
        ELSE NULL
    END,

    COALESCE(
        NULLIF(TRIM(r.activity_type), ''),
        'unknown'
    )

FROM raw_activity r

INNER JOIN stg_customers cu
    ON TRIM(r.customer_id) = cu.customer_id;

SELECT COUNT(*) AS stg_activity_rows
FROM stg_activity;


-- ============================================================================
-- FINAL SUMMARY
-- ============================================================================

SELECT 'stg_customers' AS table_name, COUNT(*) AS row_count
FROM stg_customers

UNION ALL

SELECT 'stg_campaigns', COUNT(*)
FROM stg_campaigns

UNION ALL

SELECT 'stg_campaign_performance', COUNT(*)
FROM stg_campaign_performance

UNION ALL

SELECT 'stg_conversions', COUNT(*)
FROM stg_conversions

UNION ALL

SELECT 'stg_transactions', COUNT(*)
FROM stg_transactions

UNION ALL

SELECT 'stg_activity', COUNT(*)
FROM stg_activity;