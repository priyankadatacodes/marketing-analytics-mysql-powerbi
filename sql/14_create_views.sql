-- ============================================================================
-- 14_create_views.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- MATERIALIZED TABLE 1: tbl_customer_first_touch
-- ============================================================================

DROP TABLE IF EXISTS tbl_customer_first_touch;

CREATE TABLE tbl_customer_first_touch (
    customer_key          INT PRIMARY KEY,
    first_conversion_date DATE,
    campaign_key          INT,
    campaign_name         VARCHAR(150),
    channel_key           INT,
    channel_name          VARCHAR(50)
);

INSERT INTO tbl_customer_first_touch
WITH ranked_conversions AS (
    SELECT
        fc.customer_key,
        fc.campaign_key,
        dd.full_date AS conversion_date,
        ROW_NUMBER() OVER (
            PARTITION BY fc.customer_key
            ORDER BY dd.full_date ASC
        ) AS rn
    FROM fact_conversions fc
    JOIN dim_date dd
        ON fc.date_key = dd.date_key
    WHERE fc.conversion_stage = 'Customer'
      AND dd.date_key <> 19000101
)

SELECT
    rc.customer_key,
    rc.conversion_date,
    dcamp.campaign_key,
    dcamp.campaign_name,
    dch.channel_key,
    dch.channel_name
FROM ranked_conversions rc
JOIN dim_campaign dcamp
    ON rc.campaign_key = dcamp.campaign_key
JOIN dim_channel dch
    ON dcamp.channel_key = dch.channel_key
WHERE rc.rn = 1;

SELECT COUNT(*) AS tbl_customer_first_touch_rows
FROM tbl_customer_first_touch;

ALTER TABLE tbl_customer_first_touch
    ADD INDEX idx_channel (channel_key);

ALTER TABLE tbl_customer_first_touch
    ADD INDEX idx_campaign (campaign_key);


-- ============================================================================
-- MATERIALIZED TABLE 2: tbl_customer_ltv
-- ============================================================================

DROP TABLE IF EXISTS tbl_customer_ltv;

CREATE TABLE tbl_customer_ltv (
    customer_key         INT PRIMARY KEY,
    customer_id          VARCHAR(20),
    acquisition_channel  VARCHAR(50),
    total_transactions   INT,
    customer_ltv         DECIMAL(14,2)
);

INSERT INTO tbl_customer_ltv
SELECT
    dc.customer_key,
    dc.customer_id,
    dc.acquisition_channel,
    COUNT(fcr.transaction_id),
    COALESCE(SUM(fcr.revenue), 0)
FROM dim_customer dc
LEFT JOIN fact_customer_revenue fcr
    ON dc.customer_key = fcr.customer_key
GROUP BY
    dc.customer_key,
    dc.customer_id,
    dc.acquisition_channel;

SELECT COUNT(*) AS tbl_customer_ltv_rows
FROM tbl_customer_ltv;

ALTER TABLE tbl_customer_ltv
    ADD INDEX idx_channel (acquisition_channel);


-- ============================================================================
-- MATERIALIZED TABLE 3: tbl_customer_retention
-- ============================================================================

DROP TABLE IF EXISTS tbl_customer_retention;

CREATE TABLE tbl_customer_retention (
    customer_key         INT PRIMARY KEY,
    acquisition_channel  VARCHAR(50),
    is_retained          BOOLEAN
);

INSERT INTO tbl_customer_retention
WITH post_signup_engagement AS (
    SELECT
        dc.customer_key,
        dd.full_date AS event_date
    FROM fact_customer_activity fca
    JOIN dim_customer dc
        ON fca.customer_key = dc.customer_key
    JOIN dim_date dd
        ON fca.date_key = dd.date_key
    WHERE dd.full_date > dc.signup_date
      AND dd.date_key <> 19000101

    UNION ALL

    SELECT
        dc.customer_key,
        dd.full_date AS event_date
    FROM fact_customer_revenue fcr
    JOIN dim_customer dc
        ON fcr.customer_key = dc.customer_key
    JOIN dim_date dd
        ON fcr.date_key = dd.date_key
    WHERE dd.full_date > dc.signup_date
      AND dd.date_key <> 19000101
)

SELECT
    dc.customer_key,
    dc.acquisition_channel,
    MAX(
        CASE
            WHEN pse.event_date > dc.signup_date + INTERVAL 30 DAY
            THEN 1
            ELSE 0
        END
    )
FROM dim_customer dc
LEFT JOIN post_signup_engagement pse
    ON dc.customer_key = pse.customer_key
GROUP BY
    dc.customer_key,
    dc.acquisition_channel;

SELECT COUNT(*) AS tbl_customer_retention_rows
FROM tbl_customer_retention;

ALTER TABLE tbl_customer_retention
    ADD INDEX idx_channel (acquisition_channel);


-- ============================================================================
-- VIEW: vw_monthly_marketing_performance
-- ============================================================================

DROP VIEW IF EXISTS vw_monthly_marketing_performance;

CREATE VIEW vw_monthly_marketing_performance AS
SELECT
    dd.year_month AS month,
    SUM(fms.spend) AS total_spend,
    SUM(fcp.impressions) AS total_impressions,
    SUM(fcp.clicks) AS total_clicks,
    SUM(fcp.leads) AS total_leads
FROM fact_marketing_spend fms
JOIN dim_date dd
    ON fms.date_key = dd.date_key
LEFT JOIN fact_campaign_performance fcp
    ON fcp.campaign_key = fms.campaign_key
   AND fcp.date_key = fms.date_key
WHERE dd.date_key <> 19000101
GROUP BY dd.year_month;


DROP VIEW IF EXISTS vw_monthly_revenue;

CREATE VIEW vw_monthly_revenue AS
SELECT
    dd.year_month AS month,
    SUM(fcr.revenue) AS total_revenue
FROM fact_customer_revenue fcr
JOIN dim_date dd
    ON fcr.date_key = dd.date_key
WHERE dd.date_key <> 19000101
GROUP BY dd.year_month;


-- ============================================================================
-- VIEW: vw_channel_performance
-- ============================================================================

DROP VIEW IF EXISTS vw_channel_performance;

CREATE VIEW vw_channel_performance AS
SELECT
    dch.channel_name,
    COALESCE(sp.total_spend, 0) AS total_spend,
    COALESCE(rev.total_revenue, 0) AS total_revenue,
    COALESCE(cust.customers_acquired, 0) AS customers_acquired,
    ROUND(
        sp.total_spend / NULLIF(cust.customers_acquired, 0),
        2
    ) AS cac,
    ROUND(ltv.avg_ltv, 2) AS avg_ltv,
    ROUND(
        ltv.avg_ltv /
        NULLIF(
            sp.total_spend / NULLIF(cust.customers_acquired, 0),
            0
        ),
        3
    ) AS ltv_cac_ratio,
    ROUND(
        COALESCE(rev.total_revenue, 0) /
        NULLIF(sp.total_spend, 0),
        3
    ) AS roas,
    ROUND(
        (
            COALESCE(rev.total_revenue, 0) - sp.total_spend
        ) / NULLIF(sp.total_spend, 0),
        3
    ) AS roi,
    ROUND(
        100.0 * ret.retained /
        NULLIF(cust.customers_acquired, 0),
        2
    ) AS retention_rate_pct
FROM dim_channel dch

LEFT JOIN (
    SELECT
        channel_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
    GROUP BY channel_key
) sp
    ON dch.channel_key = sp.channel_key

LEFT JOIN (
    SELECT
        dcamp.channel_key,
        SUM(fcr.revenue) AS total_revenue
    FROM fact_customer_revenue fcr
    JOIN dim_campaign dcamp
        ON fcr.campaign_key = dcamp.campaign_key
    GROUP BY dcamp.channel_key
) rev
    ON dch.channel_key = rev.channel_key

LEFT JOIN (
    SELECT
        channel_key,
        COUNT(*) AS customers_acquired
    FROM tbl_customer_first_touch
    GROUP BY channel_key
) cust
    ON dch.channel_key = cust.channel_key

LEFT JOIN (
    SELECT
        tft.channel_key,
        AVG(tl.customer_ltv) AS avg_ltv
    FROM tbl_customer_first_touch tft
    JOIN tbl_customer_ltv tl
        ON tft.customer_key = tl.customer_key
    GROUP BY tft.channel_key
) ltv
    ON dch.channel_key = ltv.channel_key

LEFT JOIN (
    SELECT
        tft.channel_key,
        SUM(tr.is_retained) AS retained
    FROM tbl_customer_first_touch tft
    JOIN tbl_customer_retention tr
        ON tft.customer_key = tr.customer_key
    GROUP BY tft.channel_key
) ret
    ON dch.channel_key = ret.channel_key;


-- ============================================================================
-- VIEW: vw_campaign_performance
-- ============================================================================

DROP VIEW IF EXISTS vw_campaign_performance;

CREATE VIEW vw_campaign_performance AS
SELECT
    dcamp.campaign_name,
    dch.channel_name,
    COALESCE(sp.total_spend, 0) AS total_spend,
    COALESCE(cust.customers_acquired, 0) AS customers_acquired,
    ROUND(
        sp.total_spend / NULLIF(cust.customers_acquired, 0),
        2
    ) AS cac,
    COALESCE(rev.total_revenue, 0) AS total_revenue,
    ROUND(
        COALESCE(rev.total_revenue, 0) /
        NULLIF(sp.total_spend, 0),
        3
    ) AS roas,
    ROUND(
        (
            COALESCE(rev.total_revenue, 0) - sp.total_spend
        ) / NULLIF(sp.total_spend, 0),
        3
    ) AS roi,
    ROUND(
        ltv.avg_ltv /
        NULLIF(
            sp.total_spend / NULLIF(cust.customers_acquired, 0),
            0
        ),
        3
    ) AS ltv_cac_ratio
FROM dim_campaign dcamp
JOIN dim_channel dch
    ON dcamp.channel_key = dch.channel_key

LEFT JOIN (
    SELECT
        campaign_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
    GROUP BY campaign_key
) sp
    ON dcamp.campaign_key = sp.campaign_key

LEFT JOIN (
    SELECT
        campaign_key,
        SUM(revenue) AS total_revenue
    FROM fact_customer_revenue
    WHERE campaign_key IS NOT NULL
    GROUP BY campaign_key
) rev
    ON dcamp.campaign_key = rev.campaign_key

LEFT JOIN (
    SELECT
        campaign_key,
        COUNT(*) AS customers_acquired
    FROM tbl_customer_first_touch
    GROUP BY campaign_key
) cust
    ON dcamp.campaign_key = cust.campaign_key

LEFT JOIN (
    SELECT
        tft.campaign_key,
        AVG(tl.customer_ltv) AS avg_ltv
    FROM tbl_customer_first_touch tft
    JOIN tbl_customer_ltv tl
        ON tft.customer_key = tl.customer_key
    GROUP BY tft.campaign_key
) ltv
    ON dcamp.campaign_key = ltv.campaign_key;


-- ============================================================================
-- VIEW: vw_funnel_performance
-- ============================================================================

DROP VIEW IF EXISTS vw_funnel_performance;

CREATE VIEW vw_funnel_performance AS
SELECT
    dch.channel_name,
    SUM(fcp.impressions) AS total_impressions,
    SUM(fcp.clicks) AS total_clicks,
    SUM(fcp.leads) AS total_leads,
    COALESCE(cust.customers_acquired, 0) AS total_customers,
    ROUND(
        100.0 * SUM(fcp.clicks) /
        NULLIF(SUM(fcp.impressions), 0),
        2
    ) AS ctr_pct,
    ROUND(
        100.0 * SUM(fcp.leads) /
        NULLIF(SUM(fcp.clicks), 0),
        2
    ) AS lead_conversion_pct,
    ROUND(
        100.0 * COALESCE(cust.customers_acquired, 0) /
        NULLIF(SUM(fcp.leads), 0),
        2
    ) AS customer_conversion_pct,
    ROUND(
        100.0 * COALESCE(cust.customers_acquired, 0) /
        NULLIF(SUM(fcp.impressions), 0),
        4
    ) AS overall_conversion_pct
FROM dim_channel dch
LEFT JOIN fact_campaign_performance fcp
    ON dch.channel_key = fcp.channel_key
LEFT JOIN (
    SELECT
        channel_key,
        COUNT(*) AS customers_acquired
    FROM tbl_customer_first_touch
    GROUP BY channel_key
) cust
    ON dch.channel_key = cust.channel_key
GROUP BY
    dch.channel_name,
    cust.customers_acquired;


-- ============================================================================
-- VIEW: vw_customer_economics
-- ============================================================================

DROP VIEW IF EXISTS vw_customer_economics;

CREATE VIEW vw_customer_economics AS
SELECT
    tl.customer_id,
    tl.acquisition_channel,
    tl.total_transactions,
    tl.customer_ltv,
    tr.is_retained
FROM tbl_customer_ltv tl
JOIN tbl_customer_retention tr
    ON tl.customer_key = tr.customer_key;


-- ============================================================================
-- VIEW: vw_channel_ltv_cac
-- ============================================================================

DROP VIEW IF EXISTS vw_channel_ltv_cac;

CREATE VIEW vw_channel_ltv_cac AS
SELECT
    channel_name,
    cac,
    avg_ltv,
    ltv_cac_ratio
FROM vw_channel_performance;


-- ============================================================================
-- VIEW: vw_retention
-- ============================================================================

DROP VIEW IF EXISTS vw_retention;

CREATE VIEW vw_retention AS
SELECT
    acquisition_channel AS channel_name,
    COUNT(*) AS total_customers,
    SUM(is_retained) AS retained_customers,
    ROUND(
        100.0 * SUM(is_retained) / COUNT(*),
        2
    ) AS retention_rate_pct
FROM tbl_customer_retention
GROUP BY acquisition_channel;


-- ============================================================================
-- VIEW: vw_cohort_retention
-- ============================================================================

DROP VIEW IF EXISTS vw_cohort_retention;

CREATE VIEW vw_cohort_retention AS
WITH customer_cohort AS (
    SELECT
        customer_key,
        signup_date,
        DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month
    FROM dim_customer
    WHERE signup_date IS NOT NULL
),

engagement_events AS (
    SELECT
        fca.customer_key,
        dd.full_date AS event_date
    FROM fact_customer_activity fca
    JOIN dim_date dd
        ON fca.date_key = dd.date_key
    WHERE dd.date_key <> 19000101

    UNION ALL

    SELECT
        fcr.customer_key,
        dd.full_date AS event_date
    FROM fact_customer_revenue fcr
    JOIN dim_date dd
        ON fcr.date_key = dd.date_key
    WHERE dd.date_key <> 19000101
),

customer_month_offsets AS (
    SELECT
        cc.customer_key,
        cc.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            cc.signup_date,
            ee.event_date
        ) AS month_offset
    FROM customer_cohort cc
    JOIN engagement_events ee
        ON cc.customer_key = ee.customer_key
    WHERE ee.event_date >= cc.signup_date
      AND TIMESTAMPDIFF(
            MONTH,
            cc.signup_date,
            ee.event_date
          ) BETWEEN 0 AND 4
)

SELECT
    cc.cohort_month,
    COUNT(DISTINCT cc.customer_key) AS cohort_size,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 1
                THEN cmo.customer_key
            END
        ) / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m1_retention_pct,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 2
                THEN cmo.customer_key
            END
        ) / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m2_retention_pct,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 3
                THEN cmo.customer_key
            END
        ) / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m3_retention_pct,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 4
                THEN cmo.customer_key
            END
        ) / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m4_retention_pct
FROM customer_cohort cc
LEFT JOIN customer_month_offsets cmo
    ON cc.customer_key = cmo.customer_key
GROUP BY cc.cohort_month;

SELECT COUNT(*) AS vw_cohort_retention_rows
FROM vw_cohort_retention;


-- ============================================================================
-- VIEW: vw_channel_cohort_performance
-- ============================================================================

DROP VIEW IF EXISTS vw_channel_cohort_performance;

CREATE VIEW vw_channel_cohort_performance AS
WITH customer_cohort AS (
    SELECT
        customer_key,
        acquisition_channel,
        signup_date,
        DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month
    FROM dim_customer
    WHERE signup_date IS NOT NULL
),

engagement_events AS (
    SELECT
        fca.customer_key,
        dd.full_date AS event_date
    FROM fact_customer_activity fca
    JOIN dim_date dd
        ON fca.date_key = dd.date_key
    WHERE dd.date_key <> 19000101

    UNION ALL

    SELECT
        fcr.customer_key,
        dd.full_date AS event_date
    FROM fact_customer_revenue fcr
    JOIN dim_date dd
        ON fcr.date_key = dd.date_key
    WHERE dd.date_key <> 19000101
),

customer_month_offsets AS (
    SELECT
        cc.customer_key,
        cc.acquisition_channel,
        cc.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            cc.signup_date,
            ee.event_date
        ) AS month_offset
    FROM customer_cohort cc
    JOIN engagement_events ee
        ON cc.customer_key = ee.customer_key
    WHERE ee.event_date >= cc.signup_date
      AND TIMESTAMPDIFF(
            MONTH,
            cc.signup_date,
            ee.event_date
          ) IN (1, 4)
)

SELECT
    cc.acquisition_channel AS channel_name,
    cc.cohort_month,
    COUNT(DISTINCT cc.customer_key) AS cohort_size,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 1
                THEN cmo.customer_key
            END
        ) / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m1_retention_pct,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 4
                THEN cmo.customer_key
            END
        ) / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m4_retention_pct
FROM customer_cohort cc
LEFT JOIN customer_month_offsets cmo
    ON cc.customer_key = cmo.customer_key
GROUP BY
    cc.acquisition_channel,
    cc.cohort_month;

SELECT COUNT(*) AS vw_channel_cohort_performance_rows
FROM vw_channel_cohort_performance;


-- ============================================================================
-- FINAL VERIFICATION: LIST ALL VIEWS AND ROW COUNTS
-- ============================================================================

SELECT
    'vw_monthly_marketing_performance' AS view_name,
    COUNT(*) AS row_count
FROM vw_monthly_marketing_performance

UNION ALL
SELECT 'vw_monthly_revenue', COUNT(*)
FROM vw_monthly_revenue

UNION ALL
SELECT 'vw_channel_performance', COUNT(*)
FROM vw_channel_performance

UNION ALL
SELECT 'vw_campaign_performance', COUNT(*)
FROM vw_campaign_performance

UNION ALL
SELECT 'vw_funnel_performance', COUNT(*)
FROM vw_funnel_performance

UNION ALL
SELECT 'vw_customer_economics', COUNT(*)
FROM vw_customer_economics

UNION ALL
SELECT 'vw_channel_ltv_cac', COUNT(*)
FROM vw_channel_ltv_cac

UNION ALL
SELECT 'vw_retention', COUNT(*)
FROM vw_retention

UNION ALL
SELECT 'vw_cohort_retention', COUNT(*)
FROM vw_cohort_retention

UNION ALL
SELECT 'vw_channel_cohort_performance', COUNT(*)
FROM vw_channel_cohort_performance;