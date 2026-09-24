-- ============================================================================
-- 08_cac_analysis.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- Q1: What is the overall CAC?
-- ============================================================================

WITH total_spend AS (
    SELECT
        SUM(spend) AS spend
    FROM fact_marketing_spend
),

total_customers AS (
    SELECT
        COUNT(DISTINCT customer_key) AS customers
    FROM fact_conversions
    WHERE conversion_stage = 'Customer'
)

SELECT
    ts.spend AS total_marketing_spend,
    tc.customers AS total_customers_acquired,
    ROUND(
        ts.spend / NULLIF(tc.customers, 0),
        2
    ) AS overall_cac
FROM total_spend ts,
     total_customers tc;


-- ============================================================================
-- Q2: Which channel has the lowest CAC?
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
        COUNT(*) AS customers_acquired
    FROM first_customer_conversion fcc
    JOIN dim_campaign dcamp
        ON fcc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE fcc.rn = 1
    GROUP BY dch.channel_name
),

channel_spend AS (
    SELECT
        dch.channel_name,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_channel dch
        ON fms.channel_key = dch.channel_key
    GROUP BY dch.channel_name
)

SELECT
    cs.channel_name,
    cs.total_spend,
    COALESCE(cc.customers_acquired, 0) AS customers_acquired,
    ROUND(
        cs.total_spend / NULLIF(cc.customers_acquired, 0),
        2
    ) AS cac,
    RANK() OVER (
        ORDER BY
            cs.total_spend / NULLIF(cc.customers_acquired, 0) ASC
    ) AS cac_rank_best_to_worst
FROM channel_spend cs
LEFT JOIN channel_customers cc
    ON cs.channel_name = cc.channel_name
ORDER BY cac_rank_best_to_worst;


-- ============================================================================
-- Q3: Which campaign has the highest CAC?
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

campaign_customers AS (
    SELECT
        dcamp.campaign_id,
        dcamp.campaign_name,
        COUNT(*) AS customers_acquired
    FROM first_customer_conversion fcc
    JOIN dim_campaign dcamp
        ON fcc.campaign_key = dcamp.campaign_key
    WHERE fcc.rn = 1
    GROUP BY
        dcamp.campaign_id,
        dcamp.campaign_name
),

campaign_spend AS (
    SELECT
        dcamp.campaign_id,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_campaign dcamp
        ON fms.campaign_key = dcamp.campaign_key
    GROUP BY dcamp.campaign_id
)

SELECT
    csp.campaign_id,
    cc.campaign_name,
    csp.total_spend,
    COALESCE(cc.customers_acquired, 0) AS customers_acquired,
    ROUND(
        csp.total_spend / NULLIF(cc.customers_acquired, 0),
        2
    ) AS cac
FROM campaign_spend csp
LEFT JOIN campaign_customers cc
    ON csp.campaign_id = cc.campaign_id
WHERE COALESCE(cc.customers_acquired, 0) > 0
ORDER BY cac DESC
LIMIT 15;


-- ============================================================================
-- Q4: Is CAC increasing over time?
-- ============================================================================

WITH first_customer_conversion AS (
    SELECT
        fc.customer_key,
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
),

monthly_customers AS (
    SELECT
        DATE_FORMAT(conversion_date, '%Y-%m') AS month,
        COUNT(*) AS customers_acquired
    FROM first_customer_conversion
    WHERE rn = 1
    GROUP BY DATE_FORMAT(conversion_date, '%Y-%m')
),

monthly_spend AS (
    SELECT
        dd.year_month AS month,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_date dd
        ON fms.date_key = dd.date_key
    WHERE dd.date_key <> 19000101
    GROUP BY dd.year_month
),

monthly_cac AS (
    SELECT
        ms.month,
        ms.total_spend,
        COALESCE(mc.customers_acquired, 0) AS customers_acquired,
        ROUND(
            ms.total_spend / NULLIF(mc.customers_acquired, 0),
            2
        ) AS cac
    FROM monthly_spend ms
    LEFT JOIN monthly_customers mc
        ON ms.month = mc.month
)

SELECT
    month,
    total_spend,
    customers_acquired,
    cac,
    LAG(cac) OVER (
        ORDER BY month
    ) AS prev_month_cac,
    ROUND(
        cac - LAG(cac) OVER (ORDER BY month),
        2
    ) AS cac_change_vs_prev_month,
    ROUND(
        AVG(cac) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cac_3month_moving_avg
FROM monthly_cac
ORDER BY month;


-- ============================================================================
-- Q5: Which channels spend heavily without acquiring enough customers?
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
        COUNT(*) AS customers_acquired
    FROM first_customer_conversion fcc
    JOIN dim_campaign dcamp
        ON fcc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE fcc.rn = 1
    GROUP BY dch.channel_name
),

channel_spend AS (
    SELECT
        dch.channel_name,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_channel dch
        ON fms.channel_key = dch.channel_key
    GROUP BY dch.channel_name
)

SELECT
    cs.channel_name,
    cs.total_spend,
    COALESCE(cc.customers_acquired, 0) AS customers_acquired,
    ROUND(
        cs.total_spend / NULLIF(cc.customers_acquired, 0),
        2
    ) AS cac,
    ROUND(
        AVG(cs.total_spend) OVER (),
        0
    ) AS avg_spend_all_channels,
    ROUND(
        AVG(
            cs.total_spend / NULLIF(cc.customers_acquired, 0)
        ) OVER (),
        2
    ) AS avg_cac_all_channels,
    CASE
        WHEN cs.total_spend > AVG(cs.total_spend) OVER ()
             AND (
                 cs.total_spend
                 / NULLIF(cc.customers_acquired, 0)
             ) >
             AVG(
                 cs.total_spend
                 / NULLIF(cc.customers_acquired, 0)
             ) OVER ()
            THEN 'HIGH SPEND / HIGH CAC'
        WHEN cs.total_spend > AVG(cs.total_spend) OVER ()
            THEN 'HIGH SPEND / OK CAC'
        ELSE 'LOW SPEND'
    END AS flag
FROM channel_spend cs
LEFT JOIN channel_customers cc
    ON cs.channel_name = cc.channel_name
ORDER BY cac DESC;