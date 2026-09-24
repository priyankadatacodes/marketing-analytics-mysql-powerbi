-- ============================================================================
--  09_campaign_analysis.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- Q1: WHICH CHANNEL GENERATES THE MOST REVENUE?
-- ============================================================================

SELECT
    dch.channel_name,
    COUNT(fcr.transaction_id) AS total_transactions,
    ROUND(SUM(fcr.revenue), 2) AS total_revenue,
    ROUND(AVG(fcr.revenue), 2) AS avg_revenue_per_transaction,
    RANK() OVER (ORDER BY SUM(fcr.revenue) DESC) AS revenue_rank
FROM fact_customer_revenue fcr
JOIN dim_campaign dcamp ON fcr.campaign_key = dcamp.campaign_key
JOIN dim_channel dch ON dcamp.channel_key = dch.channel_key
GROUP BY dch.channel_name
ORDER BY revenue_rank;


SELECT
    ROUND(SUM(revenue), 2) AS unattributed_revenue,
    COUNT(*) AS unattributed_transactions
FROM fact_customer_revenue
WHERE campaign_key IS NULL;


-- ============================================================================
-- Q2: WHICH CAMPAIGN GENERATES THE MOST REVENUE?
-- ============================================================================

SELECT
    dcamp.campaign_name,
    dch.channel_name,
    COUNT(fcr.transaction_id) AS total_transactions,
    ROUND(SUM(fcr.revenue), 2) AS total_revenue,
    DENSE_RANK() OVER (ORDER BY SUM(fcr.revenue) DESC) AS revenue_rank
FROM fact_customer_revenue fcr
JOIN dim_campaign dcamp ON fcr.campaign_key = dcamp.campaign_key
JOIN dim_channel dch ON dcamp.channel_key = dch.channel_key
GROUP BY dcamp.campaign_name, dch.channel_name
ORDER BY revenue_rank
LIMIT 15;


-- ============================================================================
-- Q3: DOES THE HIGHEST-ACQUISITION CHANNEL ALSO GENERATE THE MOST REVENUE?
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
    JOIN dim_date dd ON fc.date_key = dd.date_key
    WHERE fc.conversion_stage = 'Customer'
      AND dd.date_key <> 19000101
),
channel_acquisition AS (
    SELECT
        dch.channel_name,
        COUNT(*) AS customers_acquired,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS acquisition_rank
    FROM first_customer_conversion fcc
    JOIN dim_campaign dcamp ON fcc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch ON dcamp.channel_key = dch.channel_key
    WHERE fcc.rn = 1
    GROUP BY dch.channel_name
),
channel_revenue AS (
    SELECT
        dch.channel_name,
        SUM(fcr.revenue) AS total_revenue,
        RANK() OVER (ORDER BY SUM(fcr.revenue) DESC) AS revenue_rank
    FROM fact_customer_revenue fcr
    JOIN dim_campaign dcamp ON fcr.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch ON dcamp.channel_key = dch.channel_key
    GROUP BY dch.channel_name
)
SELECT
    ca.channel_name,
    ca.customers_acquired,
    ca.acquisition_rank,
    ROUND(cr.total_revenue, 2) AS total_revenue,
    cr.revenue_rank,
    CASE
        WHEN ca.acquisition_rank = cr.revenue_rank
            THEN 'SAME RANK'
        ELSE 'DIFFERENT RANK'
    END AS comparison
FROM channel_acquisition ca
JOIN channel_revenue cr
    ON ca.channel_name = cr.channel_name
ORDER BY ca.acquisition_rank;


-- ============================================================================
-- Q4: WHICH CAMPAIGNS ACQUIRE FEWER CUSTOMERS BUT GENERATE MORE REVENUE?
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
    JOIN dim_date dd ON fc.date_key = dd.date_key
    WHERE fc.conversion_stage = 'Customer'
      AND dd.date_key <> 19000101
),
campaign_acquisition AS (
    SELECT
        campaign_key,
        COUNT(*) AS customers_acquired
    FROM first_customer_conversion
    WHERE rn = 1
    GROUP BY campaign_key
),
campaign_revenue AS (
    SELECT
        campaign_key,
        SUM(revenue) AS total_revenue
    FROM fact_customer_revenue
    WHERE campaign_key IS NOT NULL
    GROUP BY campaign_key
),
campaign_summary AS (
    SELECT
        dcamp.campaign_name,
        COALESCE(ca.customers_acquired, 0) AS customers_acquired,
        ROUND(COALESCE(cr.total_revenue, 0), 2) AS total_revenue,
        ROUND(
            AVG(COALESCE(ca.customers_acquired, 0)) OVER (),
            1
        ) AS avg_customers_all_campaigns,
        ROUND(
            AVG(COALESCE(cr.total_revenue, 0)) OVER (),
            2
        ) AS avg_revenue_all_campaigns,
        CASE
            WHEN COALESCE(ca.customers_acquired, 0)
                    < AVG(COALESCE(ca.customers_acquired, 0)) OVER ()
             AND COALESCE(cr.total_revenue, 0)
                    > AVG(COALESCE(cr.total_revenue, 0)) OVER ()
                THEN 'FEW CUSTOMERS / HIGH REVENUE -- efficient, high-value (Q26)'
            ELSE 'other'
        END AS flag
    FROM dim_campaign dcamp
    LEFT JOIN campaign_acquisition ca
        ON dcamp.campaign_key = ca.campaign_key
    LEFT JOIN campaign_revenue cr
        ON dcamp.campaign_key = cr.campaign_key
)
SELECT *
FROM campaign_summary
WHERE flag = 'FEW CUSTOMERS / HIGH REVENUE -- efficient, high-value (Q26)'
ORDER BY total_revenue DESC;


-- ============================================================================
-- Q5: WHICH CHANNEL HAS HIGHEST ROAS?
-- Q6: WHICH CAMPAIGN HAS HIGHEST ROAS?
-- ============================================================================

WITH channel_revenue AS (
    SELECT
        dch.channel_name,
        SUM(fcr.revenue) AS total_revenue
    FROM fact_customer_revenue fcr
    JOIN dim_campaign dcamp ON fcr.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch ON dcamp.channel_key = dch.channel_key
    GROUP BY dch.channel_name
),
channel_spend AS (
    SELECT
        dch.channel_name,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_channel dch ON fms.channel_key = dch.channel_key
    GROUP BY dch.channel_name
)
SELECT
    cs.channel_name,
    ROUND(cr.total_revenue, 2) AS total_revenue,
    ROUND(cs.total_spend, 2) AS total_spend,
    ROUND(
        cr.total_revenue / NULLIF(cs.total_spend, 0),
        3
    ) AS roas,
    RANK() OVER (
        ORDER BY cr.total_revenue / NULLIF(cs.total_spend, 0) DESC
    ) AS roas_rank
FROM channel_spend cs
JOIN channel_revenue cr
    ON cs.channel_name = cr.channel_name
ORDER BY roas_rank;


WITH campaign_revenue AS (
    SELECT
        campaign_key,
        SUM(revenue) AS total_revenue
    FROM fact_customer_revenue
    WHERE campaign_key IS NOT NULL
    GROUP BY campaign_key
),
campaign_spend AS (
    SELECT
        campaign_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
    GROUP BY campaign_key
)
SELECT
    dcamp.campaign_name,
    ROUND(COALESCE(cr.total_revenue, 0), 2) AS total_revenue,
    ROUND(COALESCE(csp.total_spend, 0), 2) AS total_spend,
    ROUND(
        COALESCE(cr.total_revenue, 0) / NULLIF(csp.total_spend, 0),
        3
    ) AS roas
FROM dim_campaign dcamp
LEFT JOIN campaign_revenue cr
    ON dcamp.campaign_key = cr.campaign_key
LEFT JOIN campaign_spend csp
    ON dcamp.campaign_key = csp.campaign_key
WHERE csp.total_spend > 0
ORDER BY roas DESC
LIMIT 15;


-- ============================================================================
-- Q7: WHICH CAMPAIGNS HAVE HIGH SPEND BUT WEAK ROAS?
-- ============================================================================

WITH campaign_revenue AS (
    SELECT
        campaign_key,
        SUM(revenue) AS total_revenue
    FROM fact_customer_revenue
    WHERE campaign_key IS NOT NULL
    GROUP BY campaign_key
),
campaign_spend AS (
    SELECT
        campaign_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
    GROUP BY campaign_key
),
campaign_roas AS (
    SELECT
        dcamp.campaign_name,
        COALESCE(csp.total_spend, 0) AS total_spend,
        COALESCE(cr.total_revenue, 0)
            / NULLIF(csp.total_spend, 0) AS roas
    FROM dim_campaign dcamp
    LEFT JOIN campaign_revenue cr
        ON dcamp.campaign_key = cr.campaign_key
    LEFT JOIN campaign_spend csp
        ON dcamp.campaign_key = csp.campaign_key
    WHERE csp.total_spend > 0
),
campaign_roas_with_avg AS (
    SELECT
        campaign_name,
        total_spend,
        roas,
        AVG(total_spend) OVER () AS avg_spend_all_campaigns,
        AVG(roas) OVER () AS avg_roas_all_campaigns
    FROM campaign_roas
)
SELECT
    campaign_name,
    ROUND(total_spend, 2) AS total_spend,
    ROUND(roas, 3) AS roas,
    ROUND(avg_spend_all_campaigns, 2) AS avg_spend_all_campaigns,
    ROUND(avg_roas_all_campaigns, 3) AS avg_roas_all_campaigns
FROM campaign_roas_with_avg
WHERE total_spend > avg_spend_all_campaigns
  AND roas < avg_roas_all_campaigns
ORDER BY total_spend DESC;


-- ============================================================================
-- Q8: HOW IS ROAS CHANGING OVER TIME?
-- ============================================================================

WITH monthly_revenue AS (
    SELECT
        dd.year_month AS month,
        SUM(fcr.revenue) AS total_revenue
    FROM fact_customer_revenue fcr
    JOIN dim_date dd ON fcr.date_key = dd.date_key
    WHERE dd.date_key <> 19000101
    GROUP BY dd.year_month
),
monthly_spend AS (
    SELECT
        dd.year_month AS month,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_date dd ON fms.date_key = dd.date_key
    WHERE dd.date_key <> 19000101
    GROUP BY dd.year_month
)
SELECT
    ms.month,
    ROUND(mr.total_revenue, 2) AS total_revenue,
    ROUND(ms.total_spend, 2) AS total_spend,
    ROUND(
        mr.total_revenue / NULLIF(ms.total_spend, 0),
        3
    ) AS roas,
    ROUND(
        AVG(
            mr.total_revenue / NULLIF(ms.total_spend, 0)
        ) OVER (
            ORDER BY ms.month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        3
    ) AS roas_3month_moving_avg
FROM monthly_spend ms
JOIN monthly_revenue mr
    ON ms.month = mr.month
ORDER BY ms.month;


-- ============================================================================
-- Q9: WHICH CHANNEL PRODUCES HIGHEST ROI?
-- ============================================================================

WITH channel_revenue AS (
    SELECT
        dch.channel_name,
        SUM(fcr.revenue) AS total_revenue
    FROM fact_customer_revenue fcr
    JOIN dim_campaign dcamp ON fcr.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch ON dcamp.channel_key = dch.channel_key
    GROUP BY dch.channel_name
),
channel_spend AS (
    SELECT
        dch.channel_name,
        SUM(fms.spend) AS total_spend
    FROM fact_marketing_spend fms
    JOIN dim_channel dch ON fms.channel_key = dch.channel_key
    GROUP BY dch.channel_name
)
SELECT
    cs.channel_name,
    ROUND(cr.total_revenue, 2) AS total_revenue,
    ROUND(cs.total_spend, 2) AS total_spend,
    ROUND(
        (cr.total_revenue - cs.total_spend)
        / NULLIF(cs.total_spend, 0),
        3
    ) AS roi,
    RANK() OVER (
        ORDER BY
            (cr.total_revenue - cs.total_spend)
            / NULLIF(cs.total_spend, 0) DESC
    ) AS roi_rank
FROM channel_spend cs
JOIN channel_revenue cr
    ON cs.channel_name = cr.channel_name
ORDER BY roi_rank;


-- ============================================================================
-- Q10: WHICH CAMPAIGNS HAVE POOR ROI?
-- ============================================================================

WITH campaign_revenue AS (
    SELECT
        campaign_key,
        SUM(revenue) AS total_revenue
    FROM fact_customer_revenue
    WHERE campaign_key IS NOT NULL
    GROUP BY campaign_key
),
campaign_spend AS (
    SELECT
        campaign_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
    GROUP BY campaign_key
)
SELECT
    dcamp.campaign_name,
    ROUND(COALESCE(cr.total_revenue, 0), 2) AS total_revenue,
    ROUND(csp.total_spend, 2) AS total_spend,
    ROUND(
        (COALESCE(cr.total_revenue, 0) - csp.total_spend)
        / NULLIF(csp.total_spend, 0),
        3
    ) AS roi
FROM dim_campaign dcamp
LEFT JOIN campaign_revenue cr
    ON dcamp.campaign_key = cr.campaign_key
JOIN campaign_spend csp
    ON dcamp.campaign_key = csp.campaign_key
ORDER BY roi ASC
LIMIT 10;


-- ============================================================================
-- Q11: ARE HIGH-ROAS CAMPAIGNS ALSO HIGH-ROI CAMPAIGNS?
-- ============================================================================

WITH campaign_revenue AS (
    SELECT
        campaign_key,
        SUM(revenue) AS total_revenue
    FROM fact_customer_revenue
    WHERE campaign_key IS NOT NULL
    GROUP BY campaign_key
),
campaign_spend AS (
    SELECT
        campaign_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
    GROUP BY campaign_key
),
campaign_metrics AS (
    SELECT
        dcamp.campaign_name,
        COALESCE(cr.total_revenue, 0)
            / NULLIF(csp.total_spend, 0) AS roas,
        (COALESCE(cr.total_revenue, 0) - csp.total_spend)
            / NULLIF(csp.total_spend, 0) AS roi
    FROM dim_campaign dcamp
    LEFT JOIN campaign_revenue cr
        ON dcamp.campaign_key = cr.campaign_key
    JOIN campaign_spend csp
        ON dcamp.campaign_key = csp.campaign_key
)
SELECT
    campaign_name,
    ROUND(roas, 3) AS roas,
    ROUND(roi, 3) AS roi,
    RANK() OVER (ORDER BY roas DESC) AS roas_rank,
    RANK() OVER (ORDER BY roi DESC) AS roi_rank,
    CASE
        WHEN RANK() OVER (ORDER BY roas DESC)
           = RANK() OVER (ORDER BY roi DESC)
            THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS rank_consistency_check
FROM campaign_metrics
ORDER BY roas_rank
LIMIT 15;