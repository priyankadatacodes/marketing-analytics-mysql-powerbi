-- ============================================================================
-- 04_populate_star_schema.sql
-- ============================================================================
SET SESSION cte_max_recursion_depth = 2000;
USE marketing_analytics;


-- ============================================================================
-- STEP 1: POPULATE dim_date
-- ============================================================================

INSERT INTO dim_date (
    date_key,
    full_date,
    `day`,
    `month`,
    month_name,
    quarter,
    `year`,
    `week`,
    `year_month`
)
WITH RECURSIVE calendar AS (
    SELECT DATE('2023-01-01') AS full_date

    UNION ALL

    SELECT full_date + INTERVAL 1 DAY
    FROM calendar
    WHERE full_date + INTERVAL 1 DAY <= '2026-12-31'
)

SELECT
    CAST(DATE_FORMAT(full_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    full_date,
    DAY(full_date) AS `day`,
    MONTH(full_date) AS `month`,
    MONTHNAME(full_date) AS month_name,
    QUARTER(full_date) AS quarter,
    YEAR(full_date) AS `year`,
    WEEK(full_date) AS `week`,
    DATE_FORMAT(full_date, '%Y-%m') AS `year_month`
FROM calendar;


INSERT INTO dim_date (
    date_key,
    full_date,
    `day`,
    `month`,
    month_name,
    quarter,
    `year`,
    `week`,
    `year_month`
)
VALUES (
    19000101,
    '1900-01-01',
    1,
    1,
    'Unknown',
    1,
    1900,
    1,
    'Unknown'
);


SELECT COUNT(*) AS dim_date_rows
FROM dim_date;


-- ============================================================================
-- STEP 2: POPULATE dim_channel
-- ============================================================================

INSERT INTO dim_channel (
    channel_name,
    channel_type
)
VALUES
    ('Paid Search', 'Paid'),
    ('Social',       'Paid'),
    ('Display',      'Paid'),
    ('Affiliate',    'Paid'),
    ('Email',        'Owned'),
    ('Organic',      'Organic'),
    ('Referral',     'Earned');


SELECT *
FROM dim_channel;


-- ============================================================================
-- STEP 3: POPULATE dim_customer
-- ============================================================================

INSERT INTO dim_customer (
    customer_id,
    customer_name,
    email,
    country,
    region,
    industry,
    acquisition_channel,
    signup_date
)
SELECT
    customer_id,
    customer_name,
    email,
    country,
    region,
    industry,
    acquisition_channel,
    signup_date
FROM stg_customers;


SELECT COUNT(*) AS dim_customer_rows
FROM dim_customer;


-- ============================================================================
-- STEP 4: POPULATE dim_campaign
-- ============================================================================

INSERT INTO dim_campaign (
    campaign_id,
    campaign_name,
    channel_key,
    campaign_type,
    start_date,
    end_date
)
SELECT
    sc.campaign_id,
    sc.campaign_name,
    dc.channel_key,
    sc.campaign_type,
    sc.start_date,
    sc.end_date
FROM stg_campaigns sc
JOIN dim_channel dc
    ON dc.channel_name = sc.channel;


SELECT COUNT(*) AS dim_campaign_rows
FROM dim_campaign;


SELECT COUNT(*) AS campaigns_missing_channel_match
FROM stg_campaigns sc
LEFT JOIN dim_channel dc
    ON dc.channel_name = sc.channel
WHERE dc.channel_key IS NULL;


-- ============================================================================
-- STEP 5: POPULATE fact_marketing_spend
-- ============================================================================

INSERT INTO fact_marketing_spend (
    date_key,
    campaign_key,
    channel_key,
    spend
)
SELECT
    dd.date_key,
    dcamp.campaign_key,
    dcamp.channel_key,
    sp.spend
FROM stg_campaign_performance sp
JOIN dim_campaign dcamp
    ON dcamp.campaign_id = sp.campaign_id
JOIN dim_date dd
    ON dd.full_date = COALESCE(sp.date, '1900-01-01');


SELECT COUNT(*) AS fact_marketing_spend_rows
FROM fact_marketing_spend;


-- ============================================================================
-- STEP 6: POPULATE fact_campaign_performance
-- ============================================================================

INSERT INTO fact_campaign_performance (
    date_key,
    campaign_key,
    channel_key,
    impressions,
    clicks,
    leads
)
SELECT
    dd.date_key,
    dcamp.campaign_key,
    dcamp.channel_key,
    sp.impressions,
    sp.clicks,
    sp.leads
FROM stg_campaign_performance sp
JOIN dim_campaign dcamp
    ON dcamp.campaign_id = sp.campaign_id
JOIN dim_date dd
    ON dd.full_date = COALESCE(sp.date, '1900-01-01');


SELECT COUNT(*) AS fact_campaign_performance_rows
FROM fact_campaign_performance;


-- ============================================================================
-- STEP 7: POPULATE fact_customer_revenue
-- ============================================================================

INSERT INTO fact_customer_revenue (
    transaction_id,
    customer_key,
    campaign_key,
    date_key,
    revenue,
    is_refund
)
SELECT
    t.transaction_id,
    dcust.customer_key,
    dcamp.campaign_key,
    dd.date_key,
    t.revenue,
    t.is_refund
FROM stg_transactions t
JOIN dim_customer dcust
    ON dcust.customer_id = t.customer_id
LEFT JOIN dim_campaign dcamp
    ON dcamp.campaign_id = t.campaign_id
JOIN dim_date dd
    ON dd.full_date = COALESCE(t.transaction_date, '1900-01-01');


SELECT COUNT(*) AS fact_customer_revenue_rows
FROM fact_customer_revenue;


-- ============================================================================
-- STEP 8: POPULATE fact_customer_activity
-- ============================================================================

INSERT INTO fact_customer_activity (
    activity_id,
    customer_key,
    date_key,
    activity_type
)
SELECT
    a.activity_id,
    dcust.customer_key,
    dd.date_key,
    a.activity_type
FROM stg_activity a
JOIN dim_customer dcust
    ON dcust.customer_id = a.customer_id
JOIN dim_date dd
    ON dd.full_date = COALESCE(a.activity_date, '1900-01-01');


SELECT COUNT(*) AS fact_customer_activity_rows
FROM fact_customer_activity;


-- ============================================================================
-- STEP 9: POPULATE fact_conversions
-- ============================================================================

INSERT INTO fact_conversions (
    conversion_id,
    customer_key,
    campaign_key,
    date_key,
    conversion_stage
)
SELECT
    c.conversion_id,
    dcust.customer_key,
    dcamp.campaign_key,
    dd.date_key,
    c.conversion_stage
FROM stg_conversions c
JOIN dim_customer dcust
    ON dcust.customer_id = c.customer_id
JOIN dim_campaign dcamp
    ON dcamp.campaign_id = c.campaign_id
JOIN dim_date dd
    ON dd.full_date = COALESCE(c.conversion_date, '1900-01-01');


SELECT COUNT(*) AS fact_conversions_rows
FROM fact_conversions;


-- ============================================================================
-- FINAL SANITY CHECK
-- ============================================================================

SELECT
    'dim_customer' AS table_name,
    COUNT(*) AS row_count
FROM dim_customer

UNION ALL

SELECT
    'dim_campaign',
    COUNT(*)
FROM dim_campaign

UNION ALL

SELECT
    'dim_channel',
    COUNT(*)
FROM dim_channel

UNION ALL

SELECT
    'dim_date',
    COUNT(*)
FROM dim_date

UNION ALL

SELECT
    'fact_marketing_spend',
    COUNT(*)
FROM fact_marketing_spend

UNION ALL

SELECT
    'fact_campaign_performance',
    COUNT(*)
FROM fact_campaign_performance

UNION ALL

SELECT
    'fact_customer_revenue',
    COUNT(*)
FROM fact_customer_revenue

UNION ALL

SELECT
    'fact_customer_activity',
    COUNT(*)
FROM fact_customer_activity

UNION ALL

SELECT
    'fact_conversions',
    COUNT(*)
FROM fact_conversions;