-- ============================================================================
-- 06_acquisition_analysis.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- Q1: What is total customer count, and how are customers split by channel?
-- ============================================================================

SELECT
    acquisition_channel,
    COUNT(*) AS total_customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS pct_of_all_customers
FROM dim_customer
GROUP BY acquisition_channel
ORDER BY total_customers DESC;


-- ============================================================================
-- Q2: Which channel acquires the most customers?
-- ============================================================================

SELECT
    acquisition_channel,
    COUNT(*) AS total_customers,
    RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS channel_rank
FROM dim_customer
GROUP BY acquisition_channel
ORDER BY channel_rank;


-- ============================================================================
-- Q3: Which campaign acquires the most customers?
-- ============================================================================

WITH first_customer_conversion AS (
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
    dcamp.campaign_name,
    dch.channel_name,
    COUNT(*) AS customers_acquired
FROM first_customer_conversion fcc
JOIN dim_campaign dcamp
    ON fcc.campaign_key = dcamp.campaign_key
JOIN dim_channel dch
    ON dcamp.channel_key = dch.channel_key
WHERE fcc.rn = 1
GROUP BY
    dcamp.campaign_name,
    dch.channel_name
ORDER BY customers_acquired DESC
LIMIT 20;


-- ============================================================================
-- Q4: Which channel is growing fastest?
-- ============================================================================

WITH monthly_signups AS (
    SELECT
        dc.acquisition_channel,
        DATE_FORMAT(dc.signup_date, '%Y-%m') AS signup_month,
        COUNT(*) AS new_customers
    FROM dim_customer dc
    WHERE dc.signup_date IS NOT NULL
    GROUP BY
        dc.acquisition_channel,
        DATE_FORMAT(dc.signup_date, '%Y-%m')
),

monthly_growth AS (
    SELECT
        acquisition_channel,
        signup_month,
        new_customers,
        LAG(new_customers) OVER (
            PARTITION BY acquisition_channel
            ORDER BY signup_month
        ) AS prev_month_customers
    FROM monthly_signups
)

SELECT
    acquisition_channel,
    signup_month,
    new_customers,
    prev_month_customers,
    CASE
        WHEN prev_month_customers IS NULL
             OR prev_month_customers = 0
            THEN NULL
        ELSE ROUND(
            100.0 * (new_customers - prev_month_customers)
            / prev_month_customers,
            1
        )
    END AS mom_growth_pct
FROM monthly_growth
ORDER BY
    acquisition_channel,
    signup_month;


-- ============================================================================
-- Q5: Is the highest-volume channel the same as the fastest-growing channel?
-- ============================================================================

WITH channel_volume AS (
    SELECT
        acquisition_channel,
        COUNT(*) AS total_customers,
        RANK() OVER (
            ORDER BY COUNT(*) DESC
        ) AS volume_rank
    FROM dim_customer
    GROUP BY acquisition_channel
),

monthly_signups AS (
    SELECT
        acquisition_channel,
        DATE_FORMAT(signup_date, '%Y-%m') AS signup_month,
        COUNT(*) AS new_customers
    FROM dim_customer
    WHERE signup_date IS NOT NULL
    GROUP BY
        acquisition_channel,
        DATE_FORMAT(signup_date, '%Y-%m')
),

monthly_growth AS (
    SELECT
        acquisition_channel,
        new_customers,
        LAG(new_customers) OVER (
            PARTITION BY acquisition_channel
            ORDER BY signup_month
        ) AS prev_month
    FROM monthly_signups
),

avg_growth AS (
    SELECT
        acquisition_channel,
        ROUND(
            AVG(
                CASE
                    WHEN prev_month IS NULL
                         OR prev_month = 0
                        THEN NULL
                    ELSE 100.0 * (new_customers - prev_month)
                         / prev_month
                END
            ),
            1
        ) AS avg_mom_growth_pct,

        RANK() OVER (
            ORDER BY AVG(
                CASE
                    WHEN prev_month IS NULL
                         OR prev_month = 0
                        THEN NULL
                    ELSE 100.0 * (new_customers - prev_month)
                         / prev_month
                END
            ) DESC
        ) AS growth_rank

    FROM monthly_growth
    GROUP BY acquisition_channel
)

SELECT
    cv.acquisition_channel,
    cv.total_customers,
    cv.volume_rank,
    ag.avg_mom_growth_pct,
    ag.growth_rank
FROM channel_volume cv
JOIN avg_growth ag
    ON cv.acquisition_channel = ag.acquisition_channel
ORDER BY cv.volume_rank;