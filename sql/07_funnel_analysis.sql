-- ============================================================================
-- 07_funnel_analysis.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- Q1: What is the channel-level funnel performance?
-- ============================================================================

WITH channel_traffic AS (
    SELECT
        dch.channel_name,
        SUM(fcp.impressions) AS total_impressions,
        SUM(fcp.clicks) AS total_clicks,
        SUM(fcp.leads) AS total_leads
    FROM fact_campaign_performance fcp
    JOIN dim_channel dch
        ON fcp.channel_key = dch.channel_key
    WHERE fcp.date_key <> 19000101
    GROUP BY dch.channel_name
),

channel_customers AS (
    SELECT
        dch.channel_name,
        COUNT(DISTINCT fc.customer_key) AS total_customers
    FROM fact_conversions fc
    JOIN dim_campaign dcamp
        ON fc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE fc.conversion_stage = 'Customer'
    GROUP BY dch.channel_name
)

SELECT
    ct.channel_name,
    ct.total_impressions,
    ct.total_clicks,
    ct.total_leads,
    COALESCE(cc.total_customers, 0) AS total_customers,
    ROUND(
        100.0 * ct.total_clicks / NULLIF(ct.total_impressions, 0),
        2
    ) AS ctr_pct,
    ROUND(
        100.0 * ct.total_leads / NULLIF(ct.total_clicks, 0),
        2
    ) AS lead_conversion_pct,
    ROUND(
        100.0 * COALESCE(cc.total_customers, 0)
        / NULLIF(ct.total_leads, 0),
        2
    ) AS customer_conversion_pct,
    ROUND(
        100.0 * COALESCE(cc.total_customers, 0)
        / NULLIF(ct.total_impressions, 0),
        4
    ) AS overall_conversion_pct,
    RANK() OVER (
        ORDER BY
            ROUND(
                100.0 * ct.total_clicks
                / NULLIF(ct.total_impressions, 0),
                2
            ) DESC
    ) AS ctr_rank,
    RANK() OVER (
        ORDER BY
            COALESCE(cc.total_customers, 0)
            / NULLIF(ct.total_impressions, 0) DESC
    ) AS overall_conversion_rank
FROM channel_traffic ct
LEFT JOIN channel_customers cc
    ON ct.channel_name = cc.channel_name
ORDER BY overall_conversion_rank;


-- ============================================================================
-- Q2: What is the overall conversion rate?
-- ============================================================================

SELECT
    SUM(fcp.impressions) AS total_impressions,
    (
        SELECT COUNT(DISTINCT customer_key)
        FROM fact_conversions
        WHERE conversion_stage = 'Customer'
    ) AS total_customers,
    ROUND(
        100.0 * (
            SELECT COUNT(DISTINCT customer_key)
            FROM fact_conversions
            WHERE conversion_stage = 'Customer'
        ) / NULLIF(SUM(fcp.impressions), 0),
        4
    ) AS overall_conversion_pct
FROM fact_campaign_performance fcp
WHERE fcp.date_key <> 19000101;


-- ============================================================================
-- Q3: Which channel has the best CTR?
-- ============================================================================

WITH channel_traffic AS (
    SELECT
        dch.channel_name,
        SUM(fcp.impressions) AS total_impressions,
        SUM(fcp.clicks) AS total_clicks
    FROM fact_campaign_performance fcp
    JOIN dim_channel dch
        ON fcp.channel_key = dch.channel_key
    WHERE fcp.date_key <> 19000101
    GROUP BY dch.channel_name
)

SELECT
    channel_name,
    total_impressions,
    total_clicks,
    ROUND(
        100.0 * total_clicks / NULLIF(total_impressions, 0),
        2
    ) AS ctr_pct,
    RANK() OVER (
        ORDER BY
            100.0 * total_clicks / NULLIF(total_impressions, 0) DESC
    ) AS ctr_rank
FROM channel_traffic
ORDER BY ctr_rank;


-- ============================================================================
-- Q4: Which channel generates the most leads?
-- ============================================================================

SELECT
    dch.channel_name,
    SUM(fcp.leads) AS total_leads,
    RANK() OVER (
        ORDER BY SUM(fcp.leads) DESC
    ) AS lead_rank
FROM fact_campaign_performance fcp
JOIN dim_channel dch
    ON fcp.channel_key = dch.channel_key
WHERE fcp.date_key <> 19000101
GROUP BY dch.channel_name
ORDER BY lead_rank;


-- ============================================================================
-- Q5: Which channel converts leads most efficiently?
-- ============================================================================

WITH channel_traffic AS (
    SELECT
        dch.channel_name,
        SUM(fcp.leads) AS total_leads
    FROM fact_campaign_performance fcp
    JOIN dim_channel dch
        ON fcp.channel_key = dch.channel_key
    WHERE fcp.date_key <> 19000101
    GROUP BY dch.channel_name
),

channel_customers AS (
    SELECT
        dch.channel_name,
        COUNT(DISTINCT fc.customer_key) AS total_customers
    FROM fact_conversions fc
    JOIN dim_campaign dcamp
        ON fc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE fc.conversion_stage = 'Customer'
    GROUP BY dch.channel_name
)

SELECT
    ct.channel_name,
    ct.total_leads,
    COALESCE(cc.total_customers, 0) AS total_customers,
    ROUND(
        100.0 * COALESCE(cc.total_customers, 0)
        / NULLIF(ct.total_leads, 0),
        2
    ) AS customer_conversion_pct,
    RANK() OVER (
        ORDER BY
            COALESCE(cc.total_customers, 0)
            / NULLIF(ct.total_leads, 0) DESC
    ) AS conversion_rank
FROM channel_traffic ct
LEFT JOIN channel_customers cc
    ON ct.channel_name = cc.channel_name
ORDER BY conversion_rank;


-- ============================================================================
-- Q6: Where is the largest funnel drop-off?
-- ============================================================================

WITH channel_traffic AS (
    SELECT
        dch.channel_name,
        SUM(fcp.impressions) AS total_impressions,
        SUM(fcp.clicks) AS total_clicks,
        SUM(fcp.leads) AS total_leads
    FROM fact_campaign_performance fcp
    JOIN dim_channel dch
        ON fcp.channel_key = dch.channel_key
    WHERE fcp.date_key <> 19000101
    GROUP BY dch.channel_name
),

channel_customers AS (
    SELECT
        dch.channel_name,
        COUNT(DISTINCT fc.customer_key) AS total_customers
    FROM fact_conversions fc
    JOIN dim_campaign dcamp
        ON fc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE fc.conversion_stage = 'Customer'
    GROUP BY dch.channel_name
),

funnel_stages AS (
    SELECT
        channel_name,
        'Impressions' AS stage,
        total_impressions AS stage_volume,
        1 AS stage_order
    FROM channel_traffic

    UNION ALL

    SELECT
        channel_name,
        'Clicks',
        total_clicks,
        2
    FROM channel_traffic

    UNION ALL

    SELECT
        channel_name,
        'Leads',
        total_leads,
        3
    FROM channel_traffic

    UNION ALL

    SELECT
        ct.channel_name,
        'Customers',
        COALESCE(cc.total_customers, 0),
        4
    FROM channel_traffic ct
    LEFT JOIN channel_customers cc
        ON ct.channel_name = cc.channel_name
)

SELECT
    channel_name,
    stage,
    stage_volume,
    LAG(stage_volume) OVER (
        PARTITION BY channel_name
        ORDER BY stage_order
    ) AS previous_stage_volume,
    ROUND(
        100.0 * (
            LAG(stage_volume) OVER (
                PARTITION BY channel_name
                ORDER BY stage_order
            ) - stage_volume
        ) / NULLIF(
            LAG(stage_volume) OVER (
                PARTITION BY channel_name
                ORDER BY stage_order
            ),
            0
        ),
        2
    ) AS pct_dropped_from_previous_stage
FROM funnel_stages
ORDER BY channel_name, stage_order;


-- ============================================================================
-- Q7: Which campaign generates traffic but poor conversions?
-- ============================================================================

WITH campaign_traffic AS (
    SELECT
        dcamp.campaign_id,
        dcamp.campaign_name,
        SUM(fcp.impressions) AS total_impressions,
        SUM(fcp.clicks) AS total_clicks,
        SUM(fcp.leads) AS total_leads
    FROM fact_campaign_performance fcp
    JOIN dim_campaign dcamp
        ON fcp.campaign_key = dcamp.campaign_key
    WHERE fcp.date_key <> 19000101
    GROUP BY
        dcamp.campaign_id,
        dcamp.campaign_name
),

campaign_customers AS (
    SELECT
        dcamp.campaign_id,
        COUNT(DISTINCT fc.customer_key) AS total_customers
    FROM fact_conversions fc
    JOIN dim_campaign dcamp
        ON fc.campaign_key = dcamp.campaign_key
    WHERE fc.conversion_stage = 'Customer'
    GROUP BY dcamp.campaign_id
),

campaign_funnel AS (
    SELECT
        ct.campaign_id,
        ct.campaign_name,
        ct.total_impressions,
        COALESCE(cc.total_customers, 0) AS total_customers,
        100.0 * COALESCE(cc.total_customers, 0)
        / NULLIF(ct.total_impressions, 0) AS conversion_pct
    FROM campaign_traffic ct
    LEFT JOIN campaign_customers cc
        ON ct.campaign_id = cc.campaign_id
)

SELECT
    campaign_name,
    total_impressions,
    total_customers,
    ROUND(conversion_pct, 4) AS conversion_pct,
    ROUND(AVG(total_impressions) OVER (), 0) AS avg_impressions_all_campaigns,
    ROUND(AVG(conversion_pct) OVER (), 4) AS avg_conversion_pct_all_campaigns,
    CASE
        WHEN total_impressions > AVG(total_impressions) OVER ()
             AND conversion_pct < AVG(conversion_pct) OVER ()
            THEN 'HIGH TRAFFIC / POOR CONVERSION (Q7)'
        WHEN total_impressions < AVG(total_impressions) OVER ()
             AND conversion_pct > AVG(conversion_pct) OVER ()
            THEN 'LOW TRAFFIC / STRONG CONVERSION (Q8)'
        WHEN total_impressions >= AVG(total_impressions) OVER ()
             AND conversion_pct >= AVG(conversion_pct) OVER ()
            THEN 'HIGH TRAFFIC / STRONG CONVERSION'
        ELSE 'LOW TRAFFIC / WEAK CONVERSION'
    END AS quadrant
FROM campaign_funnel
ORDER BY conversion_pct DESC;


-- ============================================================================
-- Q8: Which campaigns have small traffic but exceptionally strong conversion?
-- ============================================================================

WITH campaign_traffic AS (
    SELECT
        dcamp.campaign_id,
        dcamp.campaign_name,
        SUM(fcp.impressions) AS total_impressions
    FROM fact_campaign_performance fcp
    JOIN dim_campaign dcamp
        ON fcp.campaign_key = dcamp.campaign_key
    WHERE fcp.date_key <> 19000101
    GROUP BY
        dcamp.campaign_id,
        dcamp.campaign_name
),

campaign_customers AS (
    SELECT
        dcamp.campaign_id,
        COUNT(DISTINCT fc.customer_key) AS total_customers
    FROM fact_conversions fc
    JOIN dim_campaign dcamp
        ON fc.campaign_key = dcamp.campaign_key
    WHERE fc.conversion_stage = 'Customer'
    GROUP BY dcamp.campaign_id
),

campaign_funnel AS (
    SELECT
        ct.campaign_id,
        ct.campaign_name,
        ct.total_impressions,
        COALESCE(cc.total_customers, 0) AS total_customers,
        100.0 * COALESCE(cc.total_customers, 0)
        / NULLIF(ct.total_impressions, 0) AS conversion_pct
    FROM campaign_traffic ct
    LEFT JOIN campaign_customers cc
        ON ct.campaign_id = cc.campaign_id
)

SELECT
    campaign_name,
    total_impressions,
    total_customers,
    ROUND(conversion_pct, 4) AS conversion_pct
FROM campaign_funnel
WHERE total_impressions < (
    SELECT AVG(total_impressions)
    FROM campaign_funnel
)
AND conversion_pct > (
    SELECT AVG(conversion_pct)
    FROM campaign_funnel
)
ORDER BY conversion_pct DESC;


-- ============================================================================
-- Q9: Which is the best converting channel?
-- ============================================================================

WITH channel_traffic AS (
    SELECT
        dch.channel_name,
        SUM(fcp.impressions) AS total_impressions
    FROM fact_campaign_performance fcp
    JOIN dim_channel dch
        ON fcp.channel_key = dch.channel_key
    WHERE fcp.date_key <> 19000101
    GROUP BY dch.channel_name
),

channel_customers AS (
    SELECT
        dch.channel_name,
        COUNT(DISTINCT fc.customer_key) AS total_customers
    FROM fact_conversions fc
    JOIN dim_campaign dcamp
        ON fc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE fc.conversion_stage = 'Customer'
    GROUP BY dch.channel_name
)

SELECT
    ct.channel_name,
    ct.total_impressions,
    COALESCE(cc.total_customers, 0) AS total_customers,
    ROUND(
        100.0 * COALESCE(cc.total_customers, 0)
        / NULLIF(ct.total_impressions, 0),
        4
    ) AS conversion_pct,
    RANK() OVER (
        ORDER BY
            COALESCE(cc.total_customers, 0)
            / NULLIF(ct.total_impressions, 0) DESC
    ) AS conversion_rank
FROM channel_traffic ct
LEFT JOIN channel_customers cc
    ON ct.channel_name = cc.channel_name
ORDER BY conversion_rank;


-- ============================================================================
-- Q10: Which is the best converting campaign?
-- ============================================================================

WITH campaign_traffic AS (
    SELECT
        dcamp.campaign_name,
        SUM(fcp.impressions) AS total_impressions
    FROM fact_campaign_performance fcp
    JOIN dim_campaign dcamp
        ON fcp.campaign_key = dcamp.campaign_key
    WHERE fcp.date_key <> 19000101
    GROUP BY dcamp.campaign_name
),

campaign_customers AS (
    SELECT
        dcamp.campaign_name,
        COUNT(DISTINCT fc.customer_key) AS total_customers
    FROM fact_conversions fc
    JOIN dim_campaign dcamp
        ON fc.campaign_key = dcamp.campaign_key
    WHERE fc.conversion_stage = 'Customer'
    GROUP BY dcamp.campaign_name
)

SELECT
    ct.campaign_name,
    ct.total_impressions,
    COALESCE(cc.total_customers, 0) AS total_customers,
    ROUND(
        100.0 * COALESCE(cc.total_customers, 0)
        / NULLIF(ct.total_impressions, 0),
        4
    ) AS conversion_pct,
    DENSE_RANK() OVER (
        ORDER BY
            100.0 * COALESCE(cc.total_customers, 0)
            / NULLIF(ct.total_impressions, 0) DESC
    ) AS conversion_rank
FROM campaign_traffic ct
LEFT JOIN campaign_customers cc
    ON ct.campaign_name = cc.campaign_name
WHERE ct.total_impressions > 1000
ORDER BY conversion_rank
LIMIT 10;