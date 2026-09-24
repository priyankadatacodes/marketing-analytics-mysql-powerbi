-- ============================================================================
-- 13_advanced_analysis.sql
-- ============================================================================

-- BUSINESS QUESTIONS
-- Q1: What percentage of total spend comes from the top 5 campaigns?
-- Q2: Which campaigns have above-average spend but below-average revenue?
-- Q3: Which channels have above-average LTV and below-average CAC?
-- Q4: Which acquisition cohorts have declining retention (M1 -> M4)?
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- TRUE RUNNING TOTAL: CUMULATIVE SPEND OVER TIME
-- ============================================================================

WITH monthly_spend AS (
    SELECT
        dd.year_month AS month,
        SUM(fms.spend) AS month_spend
    FROM fact_marketing_spend fms
    JOIN dim_date dd
        ON fms.date_key = dd.date_key
    WHERE dd.date_key <> 19000101
    GROUP BY dd.year_month
)

SELECT
    month,
    ROUND(month_spend, 2) AS month_spend,
    ROUND(
        SUM(month_spend) OVER (
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS cumulative_spend_to_date
FROM monthly_spend
ORDER BY month;


-- ============================================================================
-- Q1: WHAT % OF TOTAL SPEND COMES FROM THE TOP 5 CAMPAIGNS?
-- ============================================================================

WITH campaign_spend AS (
    SELECT
        dcamp.campaign_name,
        SUM(fms.spend) AS total_spend,
        RANK() OVER (
            ORDER BY SUM(fms.spend) DESC
        ) AS spend_rank
    FROM fact_marketing_spend fms
    JOIN dim_campaign dcamp
        ON fms.campaign_key = dcamp.campaign_key
    GROUP BY dcamp.campaign_name
),

grand_total AS (
    SELECT
        SUM(total_spend) AS overall_spend
    FROM campaign_spend
)

SELECT
    cs.campaign_name,
    ROUND(cs.total_spend, 2) AS total_spend,
    cs.spend_rank,
    ROUND(
        100.0 * cs.total_spend / gt.overall_spend,
        2
    ) AS pct_of_total_spend,
    ROUND(
        100.0 * SUM(cs.total_spend) OVER (
            ORDER BY cs.spend_rank
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / gt.overall_spend,
        2
    ) AS cumulative_pct_of_total_spend
FROM campaign_spend cs,
     grand_total gt
WHERE cs.spend_rank <= 5
ORDER BY cs.spend_rank;


-- ============================================================================
-- ROAS QUARTILES USING NTILE()
-- ============================================================================

WITH campaign_spend AS (
    SELECT
        campaign_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
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

campaign_roas AS (
    SELECT
        dcamp.campaign_name,
        COALESCE(cr.total_revenue, 0) AS total_revenue,
        cs.total_spend
    FROM dim_campaign dcamp
    JOIN campaign_spend cs
        ON dcamp.campaign_key = cs.campaign_key
    LEFT JOIN campaign_revenue cr
        ON dcamp.campaign_key = cr.campaign_key
    WHERE cs.total_spend > 0
)

SELECT
    campaign_name,
    ROUND(total_spend, 2) AS total_spend,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_revenue / total_spend, 3) AS roas,
    NTILE(4) OVER (
        ORDER BY total_revenue / total_spend DESC
    ) AS roas_quartile
FROM campaign_roas
ORDER BY roas_quartile,
         total_revenue / total_spend DESC;


-- ============================================================================
-- REVENUE PERCENTILE USING PERCENT_RANK()
-- ============================================================================

WITH campaign_revenue_totals AS (
    SELECT
        dcamp.campaign_name,
        COALESCE(SUM(fcr.revenue), 0) AS total_revenue
    FROM dim_campaign dcamp
    LEFT JOIN fact_customer_revenue fcr
        ON dcamp.campaign_key = fcr.campaign_key
    GROUP BY dcamp.campaign_name
)

SELECT
    campaign_name,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(
        PERCENT_RANK() OVER (ORDER BY total_revenue),
        3
    ) AS revenue_percentile
FROM campaign_revenue_totals
ORDER BY total_revenue DESC
LIMIT 15;


-- ============================================================================
-- Q2: CAMPAIGNS WITH ABOVE-AVERAGE SPEND BUT BELOW-AVERAGE REVENUE
-- ============================================================================

WITH campaign_spend AS (
    SELECT
        campaign_key,
        SUM(spend) AS total_spend
    FROM fact_marketing_spend
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

campaign_metrics AS (
    SELECT
        dcamp.campaign_name,
        cs.total_spend,
        COALESCE(cr.total_revenue, 0) AS total_revenue
    FROM dim_campaign dcamp
    JOIN campaign_spend cs
        ON dcamp.campaign_key = cs.campaign_key
    LEFT JOIN campaign_revenue cr
        ON dcamp.campaign_key = cr.campaign_key
    WHERE cs.total_spend > 0
),

with_averages AS (
    SELECT
        campaign_name,
        total_spend,
        total_revenue,
        AVG(total_spend) OVER () AS avg_spend,
        AVG(total_revenue) OVER () AS avg_revenue
    FROM campaign_metrics
)

SELECT
    campaign_name,
    ROUND(total_spend, 2) AS total_spend,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(avg_spend, 2) AS avg_spend_all_campaigns,
    ROUND(avg_revenue, 2) AS avg_revenue_all_campaigns
FROM with_averages
WHERE total_spend > avg_spend
  AND total_revenue < avg_revenue
ORDER BY total_spend DESC;


-- ============================================================================
-- Q3: CHANNELS WITH ABOVE-AVERAGE LTV AND BELOW-AVERAGE CAC
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
    GROUP BY cs.channel_name,
             cs.total_spend
),

with_averages AS (
    SELECT
        channel_name,
        cac,
        avg_ltv,
        AVG(cac) OVER () AS overall_avg_cac,
        AVG(avg_ltv) OVER () AS overall_avg_ltv
    FROM channel_metrics
)

SELECT
    channel_name,
    ROUND(cac, 2) AS cac,
    ROUND(avg_ltv, 2) AS avg_ltv,
    ROUND(overall_avg_cac, 2) AS overall_avg_cac,
    ROUND(overall_avg_ltv, 2) AS overall_avg_ltv
FROM with_averages
WHERE cac < overall_avg_cac
  AND avg_ltv > overall_avg_ltv
ORDER BY avg_ltv DESC;


-- ============================================================================
-- Q4: WHICH ACQUISITION COHORTS HAVE DECLINING RETENTION (M1 -> M4)?
-- ============================================================================

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
          ) BETWEEN 1 AND 4
),

cohort_retention AS (
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
                    WHEN cmo.month_offset = 4
                    THEN cmo.customer_key
                END
            ) / COUNT(DISTINCT cc.customer_key),
            1
        ) AS m4_retention_pct
    FROM customer_cohort cc
    LEFT JOIN customer_month_offsets cmo
        ON cc.customer_key = cmo.customer_key
    GROUP BY cc.cohort_month
)

SELECT
    cohort_month,
    cohort_size,
    m1_retention_pct,
    m4_retention_pct,
    ROUND(
        m4_retention_pct - m1_retention_pct,
        1
    ) AS retention_change,
    CASE
        WHEN m4_retention_pct < m1_retention_pct THEN 'DECLINING'
        WHEN m4_retention_pct > m1_retention_pct THEN 'IMPROVING'
        ELSE 'STABLE'
    END AS trend
FROM cohort_retention
WHERE cohort_size >= 20
  AND cohort_month <= '2026-03'
ORDER BY cohort_month;