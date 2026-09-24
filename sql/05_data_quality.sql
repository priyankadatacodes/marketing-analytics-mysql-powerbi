-- ============================================================================
-- 05_data_quality.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- 1. ROW COUNTS
-- ============================================================================

SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count FROM dim_customer
UNION ALL SELECT 'dim_campaign', COUNT(*) FROM dim_campaign
UNION ALL SELECT 'dim_channel', COUNT(*) FROM dim_channel
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL SELECT 'fact_marketing_spend', COUNT(*) FROM fact_marketing_spend
UNION ALL SELECT 'fact_campaign_performance', COUNT(*) FROM fact_campaign_performance
UNION ALL SELECT 'fact_customer_revenue', COUNT(*) FROM fact_customer_revenue
UNION ALL SELECT 'fact_customer_activity', COUNT(*) FROM fact_customer_activity
UNION ALL SELECT 'fact_conversions', COUNT(*) FROM fact_conversions;


-- ============================================================================
-- 2. DUPLICATE PRIMARY KEYS
-- ============================================================================

SELECT customer_id, COUNT(*) AS occurrences
FROM dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1;


SELECT campaign_id, COUNT(*) AS occurrences
FROM dim_campaign
GROUP BY campaign_id
HAVING COUNT(*) > 1;


SELECT transaction_id, COUNT(*) AS occurrences
FROM fact_customer_revenue
GROUP BY transaction_id
HAVING COUNT(*) > 1;


-- ============================================================================
-- 3. NULL CAMPAIGN ATTRIBUTION
-- ============================================================================

SELECT
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN campaign_key IS NULL THEN 1 ELSE 0 END) AS no_campaign_attribution,
    ROUND(
        100.0 * SUM(CASE WHEN campaign_key IS NULL THEN 1 ELSE 0 END) / COUNT(*),
        1
    ) AS pct_no_attribution
FROM fact_customer_revenue;


-- ============================================================================
-- 4. ORPHAN RECORDS
-- ============================================================================

SELECT COUNT(*) AS orphan_spend_campaigns
FROM fact_marketing_spend f
LEFT JOIN dim_campaign d
    ON f.campaign_key = d.campaign_key
WHERE d.campaign_key IS NULL;


SELECT COUNT(*) AS orphan_revenue_customers
FROM fact_customer_revenue f
LEFT JOIN dim_customer d
    ON f.customer_key = d.customer_key
WHERE d.customer_key IS NULL;


SELECT COUNT(*) AS orphan_activity_customers
FROM fact_customer_activity f
LEFT JOIN dim_customer d
    ON f.customer_key = d.customer_key
WHERE d.customer_key IS NULL;


SELECT COUNT(*) AS orphan_conversion_records
FROM fact_conversions f
LEFT JOIN dim_customer dc
    ON f.customer_key = dc.customer_key
LEFT JOIN dim_campaign dcamp
    ON f.campaign_key = dcamp.campaign_key
WHERE dc.customer_key IS NULL
   OR dcamp.campaign_key IS NULL;


-- ============================================================================
-- 5. UNKNOWN DATES
-- ============================================================================

SELECT
    'fact_marketing_spend' AS fact_table,
    COUNT(*) AS unknown_date_rows
FROM fact_marketing_spend
WHERE date_key = 19000101

UNION ALL

SELECT
    'fact_campaign_performance',
    COUNT(*)
FROM fact_campaign_performance
WHERE date_key = 19000101

UNION ALL

SELECT
    'fact_customer_revenue',
    COUNT(*)
FROM fact_customer_revenue
WHERE date_key = 19000101

UNION ALL

SELECT
    'fact_customer_activity',
    COUNT(*)
FROM fact_customer_activity
WHERE date_key = 19000101

UNION ALL

SELECT
    'fact_conversions',
    COUNT(*)
FROM fact_conversions
WHERE date_key = 19000101;


-- ============================================================================
-- 6. NEGATIVE SPEND
-- ============================================================================

SELECT COUNT(*) AS negative_spend_rows
FROM fact_marketing_spend
WHERE spend < 0;


SELECT
    COUNT(*) AS total_spend_rows,
    SUM(CASE WHEN spend IS NULL THEN 1 ELSE 0 END) AS null_spend_rows
FROM fact_marketing_spend;


-- ============================================================================
-- 7. FUNNEL VALIDATION
-- ============================================================================

SELECT COUNT(*) AS clicks_exceed_impressions
FROM fact_campaign_performance
WHERE clicks > impressions;


SELECT COUNT(*) AS leads_exceed_clicks
FROM fact_campaign_performance
WHERE leads > clicks;


-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT
    'No duplicate customer_id' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    SELECT customer_id
    FROM dim_customer
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) x

UNION ALL

SELECT
    'No duplicate campaign_id',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT campaign_id
    FROM dim_campaign
    GROUP BY campaign_id
    HAVING COUNT(*) > 1
) x

UNION ALL

SELECT
    'No duplicate transaction_id',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT transaction_id
    FROM fact_customer_revenue
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
) x

UNION ALL

SELECT
    'No orphan fact_marketing_spend.campaign_key',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact_marketing_spend f
LEFT JOIN dim_campaign d
    ON f.campaign_key = d.campaign_key
WHERE d.campaign_key IS NULL

UNION ALL

SELECT
    'No negative spend',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact_marketing_spend
WHERE spend < 0

UNION ALL

SELECT
    'No clicks > impressions',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM fact_campaign_performance
WHERE clicks > impressions;