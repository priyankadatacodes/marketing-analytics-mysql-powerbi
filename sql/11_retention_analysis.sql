-- ============================================================================
--  11_retention_analysis.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- DATA CAVEAT CHECK: EVENTS BEFORE SIGNUP DATE
-- ============================================================================

SELECT
    (SELECT COUNT(*)
     FROM fact_customer_activity fca
     JOIN dim_customer dc
        ON fca.customer_key = dc.customer_key
     JOIN dim_date dd
        ON fca.date_key = dd.date_key
     WHERE dd.full_date < dc.signup_date) AS activity_events_before_signup,
    (SELECT COUNT(*)
     FROM fact_customer_revenue fcr
     JOIN dim_customer dc
        ON fcr.customer_key = dc.customer_key
     JOIN dim_date dd
        ON fcr.date_key = dd.date_key
     WHERE dd.full_date < dc.signup_date) AS transactions_before_signup;


-- ============================================================================
-- CUSTOMER-LEVEL RETENTION FLAG
-- ============================================================================

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
),
customer_retention AS (
    SELECT
        dc.customer_key,
        dc.acquisition_channel,
        dc.signup_date,
        MAX(
            CASE
                WHEN pse.event_date > dc.signup_date + INTERVAL 30 DAY
                    THEN 1
                ELSE 0
            END
        ) AS is_retained
    FROM dim_customer dc
    LEFT JOIN post_signup_engagement pse
        ON dc.customer_key = pse.customer_key
    GROUP BY
        dc.customer_key,
        dc.acquisition_channel,
        dc.signup_date
)
SELECT *
FROM customer_retention
LIMIT 20;


-- ============================================================================
-- Q1: WHICH ACQUISITION CHANNEL HAS STRONGEST RETENTION?
-- Q2: WHICH CHANNEL LOSES CUSTOMERS FASTEST?
-- ============================================================================

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
),
customer_retention AS (
    SELECT
        dc.customer_key,
        dc.acquisition_channel,
        MAX(
            CASE
                WHEN pse.event_date > dc.signup_date + INTERVAL 30 DAY
                    THEN 1
                ELSE 0
            END
        ) AS is_retained
    FROM dim_customer dc
    LEFT JOIN post_signup_engagement pse
        ON dc.customer_key = pse.customer_key
    GROUP BY
        dc.customer_key,
        dc.acquisition_channel
)
SELECT
    acquisition_channel,
    COUNT(*) AS total_customers,
    SUM(is_retained) AS retained_customers,
    ROUND(
        100.0 * SUM(is_retained) / COUNT(*),
        2
    ) AS retention_rate_pct,
    RANK() OVER (
        ORDER BY SUM(is_retained) / COUNT(*) DESC
    ) AS retention_rank
FROM customer_retention
GROUP BY acquisition_channel
ORDER BY retention_rank;


-- ============================================================================
-- REPEAT CUSTOMER % BY CHANNEL
-- ============================================================================

SELECT
    dc.acquisition_channel,
    COUNT(DISTINCT dc.customer_key) AS total_customers,
    COUNT(
        DISTINCT CASE
            WHEN txn_counts.transaction_count > 1
                THEN dc.customer_key
        END
    ) AS repeat_customers,
    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN txn_counts.transaction_count > 1
                    THEN dc.customer_key
            END
        )
        / COUNT(DISTINCT dc.customer_key),
        2
    ) AS repeat_customer_pct
FROM dim_customer dc
LEFT JOIN (
    SELECT
        customer_key,
        COUNT(*) AS transaction_count
    FROM fact_customer_revenue
    GROUP BY customer_key
) txn_counts
    ON dc.customer_key = txn_counts.customer_key
GROUP BY dc.acquisition_channel
ORDER BY repeat_customer_pct DESC;


-- ============================================================================
-- REVENUE RETENTION
-- ============================================================================

WITH customer_revenue_windows AS (
    SELECT
        dc.customer_key,
        dc.acquisition_channel,
        SUM(
            CASE
                WHEN dd.full_date <= dc.signup_date + INTERVAL 90 DAY
                    THEN fcr.revenue
                ELSE 0
            END
        ) AS revenue_first_90_days,
        SUM(
            CASE
                WHEN dd.full_date > dc.signup_date + INTERVAL 90 DAY
                    THEN fcr.revenue
                ELSE 0
            END
        ) AS revenue_after_90_days
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    LEFT JOIN dim_date dd
        ON fcr.date_key = dd.date_key
    WHERE dd.full_date > dc.signup_date
       OR dd.full_date IS NULL
    GROUP BY
        dc.customer_key,
        dc.acquisition_channel
)
SELECT
    acquisition_channel,
    ROUND(SUM(revenue_first_90_days), 2) AS total_revenue_first_90_days,
    ROUND(SUM(revenue_after_90_days), 2) AS total_revenue_after_90_days,
    ROUND(
        100.0 * SUM(revenue_after_90_days)
        / NULLIF(SUM(revenue_first_90_days), 0),
        2
    ) AS revenue_retention_pct
FROM customer_revenue_windows
GROUP BY acquisition_channel
ORDER BY revenue_retention_pct DESC;


-- ============================================================================
-- Q3: DO EXPENSIVE ACQUISITION CHANNELS RETAIN BETTER?
-- Q4: DO LOW-CAC CHANNELS HAVE POOR RETENTION?
-- ============================================================================

WITH first_customer_conversion AS (
    SELECT
        fc.customer_key,
        fc.campaign_key,
        ROW_NUMBER() OVER (
            PARTITION BY fc.customer_key
            ORDER BY dd.full_date ASC
        ) AS rn
    FROM fact_conversions fc
    JOIN dim_date dd
        ON fc.date_key = dd.date_key
    WHERE fc.conversion_stage = 'Customer'
      AND dd.date_key <> 19000101
),
channel_customers AS (
    SELECT
        dch.channel_name,
        fcc.customer_key
    FROM first_customer_conversion fcc
    JOIN dim_campaign dcamp
        ON fcc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE fcc.rn = 1
),
channel_spend AS (
    SELECT
        dch.channel_name,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_channel dch
        ON fms.channel_key = dch.channel_key
    GROUP BY dch.channel_name
),
channel_cac AS (
    SELECT
        cs.channel_name,
        cs.total_spend
        / NULLIF(COUNT(cc.customer_key), 0) AS cac
    FROM channel_spend cs
    LEFT JOIN channel_customers cc
        ON cs.channel_name = cc.channel_name
    GROUP BY
        cs.channel_name,
        cs.total_spend
),
post_signup_engagement AS (
    SELECT
        dc.customer_key,
        dd.full_date AS event_date
    FROM fact_customer_activity fca
    JOIN dim_customer dc
        ON fca.customer_key = dc.customer_key
    JOIN dim_date dd
        ON fca.date_key = dd.date_key
    WHERE dd.full_date > dc.signup_date

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
),
customer_retention AS (
    SELECT
        dc.customer_key,
        dc.acquisition_channel,
        MAX(
            CASE
                WHEN pse.event_date > dc.signup_date + INTERVAL 30 DAY
                    THEN 1
                ELSE 0
            END
        ) AS is_retained
    FROM dim_customer dc
    LEFT JOIN post_signup_engagement pse
        ON dc.customer_key = pse.customer_key
    GROUP BY
        dc.customer_key,
        dc.acquisition_channel
),
channel_retention AS (
    SELECT
        acquisition_channel AS channel_name,
        ROUND(
            100.0 * SUM(is_retained) / COUNT(*),
            2
        ) AS retention_rate_pct
    FROM customer_retention
    GROUP BY acquisition_channel
)
SELECT
    cac.channel_name,
    ROUND(cac.cac, 2) AS cac,
    RANK() OVER (
        ORDER BY cac.cac ASC
    ) AS cac_rank_cheapest_first,
    cr.retention_rate_pct,
    RANK() OVER (
        ORDER BY cr.retention_rate_pct DESC
    ) AS retention_rank_best_first
FROM channel_cac cac
JOIN channel_retention cr
    ON cac.channel_name = cr.channel_name
ORDER BY cac_rank_cheapest_first;