-- ============================================================================
--  10_ltv_analysis.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- CUSTOMER-LEVEL LTV
-- ============================================================================

SELECT
    dc.customer_id,
    dc.customer_name,
    dc.acquisition_channel,
    COUNT(fcr.transaction_id) AS total_transactions,
    ROUND(COALESCE(SUM(fcr.revenue), 0), 2) AS customer_ltv
FROM dim_customer dc
LEFT JOIN fact_customer_revenue fcr
    ON dc.customer_key = fcr.customer_key
GROUP BY dc.customer_id, dc.customer_name, dc.acquisition_channel
ORDER BY customer_ltv DESC
LIMIT 20;


-- ============================================================================
-- Q1: WHICH ACQUISITION CHANNEL PRODUCES THE HIGHEST-VALUE CUSTOMERS?
-- ============================================================================

WITH customer_ltv AS (
    SELECT
        dc.customer_key,
        dc.acquisition_channel,
        COALESCE(SUM(fcr.revenue), 0) AS ltv
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    GROUP BY dc.customer_key, dc.acquisition_channel
)
SELECT
    acquisition_channel,
    COUNT(*) AS customer_count,
    ROUND(AVG(ltv), 2) AS avg_ltv,
    ROUND(SUM(ltv), 2) AS total_ltv,
    RANK() OVER (ORDER BY AVG(ltv) DESC) AS ltv_rank
FROM customer_ltv
GROUP BY acquisition_channel
ORDER BY ltv_rank;


-- ============================================================================
-- Q2: WHICH CAMPAIGNS GENERATE HIGH-LTV CUSTOMERS?
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
customer_ltv AS (
    SELECT
        dc.customer_key,
        COALESCE(SUM(fcr.revenue), 0) AS ltv
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    GROUP BY dc.customer_key
)
SELECT
    dcamp.campaign_name,
    COUNT(*) AS customers_acquired,
    ROUND(AVG(cl.ltv), 2) AS avg_ltv_per_customer,
    ROUND(SUM(cl.ltv), 2) AS total_ltv_generated
FROM first_customer_conversion fcc
JOIN dim_campaign dcamp
    ON fcc.campaign_key = dcamp.campaign_key
JOIN customer_ltv cl
    ON fcc.customer_key = cl.customer_key
WHERE fcc.rn = 1
GROUP BY dcamp.campaign_name
HAVING COUNT(*) >= 5
ORDER BY avg_ltv_per_customer DESC
LIMIT 15;


-- ============================================================================
-- Q3: DOES THE CHEAPEST ACQUISITION SOURCE PRODUCE VALUABLE CUSTOMERS?
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
        cs.total_spend / NULLIF(COUNT(cc.customer_key), 0) AS cac
    FROM channel_spend cs
    LEFT JOIN channel_customers cc
        ON cs.channel_name = cc.channel_name
    GROUP BY cs.channel_name, cs.total_spend
),
customer_ltv AS (
    SELECT
        dc.customer_key,
        COALESCE(SUM(fcr.revenue), 0) AS ltv
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    GROUP BY dc.customer_key
),
channel_ltv AS (
    SELECT
        cc.channel_name,
        AVG(cl.ltv) AS avg_ltv
    FROM channel_customers cc
    JOIN customer_ltv cl
        ON cc.customer_key = cl.customer_key
    GROUP BY cc.channel_name
)
SELECT
    cac.channel_name,
    ROUND(cac.cac, 2) AS cac,
    RANK() OVER (ORDER BY cac.cac ASC) AS cac_rank_cheapest_first,
    ROUND(ltv.avg_ltv, 2) AS avg_ltv,
    RANK() OVER (ORDER BY ltv.avg_ltv DESC) AS ltv_rank_highest_first
FROM channel_cac cac
JOIN channel_ltv ltv
    ON cac.channel_name = ltv.channel_name
ORDER BY cac_rank_cheapest_first;


-- ============================================================================
-- Q4: IS ACQUISITION VOLUME CORRELATED WITH CUSTOMER VALUE?
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
customer_ltv AS (
    SELECT
        dc.customer_key,
        COALESCE(SUM(fcr.revenue), 0) AS ltv
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    GROUP BY dc.customer_key
),
channel_stats AS (
    SELECT
        cc.channel_name,
        COUNT(*) AS x_customers_acquired,
        AVG(cl.ltv) AS y_avg_ltv
    FROM channel_customers cc
    JOIN customer_ltv cl
        ON cc.customer_key = cl.customer_key
    GROUP BY cc.channel_name
)
SELECT
    COUNT(*) AS n_channels,
    ROUND(
        (
            COUNT(*) * SUM(x_customers_acquired * y_avg_ltv)
            - SUM(x_customers_acquired) * SUM(y_avg_ltv)
        )
        /
        SQRT(
            (
                COUNT(*) * SUM(
                    x_customers_acquired * x_customers_acquired
                )
                - POWER(SUM(x_customers_acquired), 2)
            )
            *
            (
                COUNT(*) * SUM(y_avg_ltv * y_avg_ltv)
                - POWER(SUM(y_avg_ltv), 2)
            )
        ),
        3
    ) AS pearson_correlation
FROM channel_stats;


-- ============================================================================
-- Q5: WHICH CHANNEL HAS STRONGEST LTV:CAC?
-- Q6: WHICH CHANNEL HAS POOR UNIT ECONOMICS?
-- Q7: WHICH CHANNEL LOOKS GOOD ON CAC BUT BAD ON LTV?
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
customer_ltv AS (
    SELECT
        dc.customer_key,
        COALESCE(SUM(fcr.revenue), 0) AS ltv
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    GROUP BY dc.customer_key
),
channel_metrics AS (
    SELECT
        cs.channel_name,
        cs.total_spend,
        COUNT(cc.customer_key) AS customers_acquired,
        cs.total_spend / NULLIF(COUNT(cc.customer_key), 0) AS cac,
        AVG(cl.ltv) AS avg_ltv
    FROM channel_spend cs
    LEFT JOIN channel_customers cc
        ON cs.channel_name = cc.channel_name
    LEFT JOIN customer_ltv cl
        ON cc.customer_key = cl.customer_key
    GROUP BY cs.channel_name, cs.total_spend
)
SELECT
    channel_name,
    ROUND(cac, 2) AS cac,
    ROUND(avg_ltv, 2) AS avg_ltv,
    ROUND(avg_ltv / NULLIF(cac, 0), 3) AS ltv_to_cac_ratio,
    RANK() OVER (
        ORDER BY avg_ltv / NULLIF(cac, 0) DESC
    ) AS ltv_cac_rank,
    CASE
        WHEN avg_ltv / NULLIF(cac, 0) >= 3
            THEN 'STRONG -- healthy unit economics (Q38)'
        WHEN avg_ltv / NULLIF(cac, 0) >= 1
            THEN 'MARGINAL -- breakeven-ish, worth optimizing'
        ELSE 'POOR -- losing money per customer (Q39)'
    END AS unit_economics_verdict
FROM channel_metrics
ORDER BY ltv_cac_rank;


-- ============================================================================
-- Q8: WHERE SHOULD MARKETING INVESTMENT INCREASE?
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
customer_ltv AS (
    SELECT
        dc.customer_key,
        COALESCE(SUM(fcr.revenue), 0) AS ltv
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    GROUP BY dc.customer_key
),
channel_metrics AS (
    SELECT
        cs.channel_name,
        cs.total_spend / NULLIF(COUNT(cc.customer_key), 0) AS cac,
        AVG(cl.ltv) AS avg_ltv
    FROM channel_spend cs
    LEFT JOIN channel_customers cc
        ON cs.channel_name = cc.channel_name
    LEFT JOIN customer_ltv cl
        ON cc.customer_key = cl.customer_key
    GROUP BY cs.channel_name, cs.total_spend
),
channel_ranks AS (
    SELECT
        channel_name,
        ROUND(cac, 2) AS cac,
        ROUND(avg_ltv, 2) AS avg_ltv,
        ROUND(avg_ltv / NULLIF(cac, 0), 3) AS ltv_cac_ratio,
        RANK() OVER (ORDER BY cac ASC) AS cac_rank,
        RANK() OVER (ORDER BY avg_ltv DESC) AS ltv_rank,
        RANK() OVER (
            ORDER BY avg_ltv / NULLIF(cac, 0) DESC
        ) AS ltv_cac_rank
    FROM channel_metrics
)
SELECT
    channel_name,
    cac,
    cac_rank,
    avg_ltv,
    ltv_rank,
    ltv_cac_ratio,
    ltv_cac_rank,
    (cac_rank + ltv_rank + ltv_cac_rank) AS combined_rank_score,
    CASE
        WHEN ltv_cac_rank = 1 AND cac_rank <= 3
            THEN 'TOP CANDIDATE TO SCALE (Q41)'
        WHEN ltv_cac_rank <= 3
            THEN 'GOOD CANDIDATE'
        ELSE 'MONITOR / DO NOT INCREASE YET'
    END AS investment_recommendation
FROM channel_ranks
ORDER BY combined_rank_score ASC;