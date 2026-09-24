-- ============================================================================
-- 01b_raw_data_validation.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- 1. ROW COUNTS
-- ============================================================================

SELECT 'raw_customers' AS table_name, COUNT(*) AS row_count FROM raw_customers
UNION ALL SELECT 'raw_campaigns', COUNT(*) FROM raw_campaigns
UNION ALL SELECT 'raw_campaign_performance', COUNT(*) FROM raw_campaign_performance
UNION ALL SELECT 'raw_conversions', COUNT(*) FROM raw_conversions
UNION ALL SELECT 'raw_transactions', COUNT(*) FROM raw_transactions
UNION ALL SELECT 'raw_activity', COUNT(*) FROM raw_activity;


-- ============================================================================
-- 2. MISSING / BLANK KEY FIELDS
-- ============================================================================

SELECT
    'raw_customers.customer_id' AS field,
    SUM(CASE WHEN customer_id IS NULL OR TRIM(customer_id) = '' THEN 1 ELSE 0 END) AS blank_count
FROM raw_customers

UNION ALL

SELECT
    'raw_transactions.transaction_id',
    SUM(CASE WHEN transaction_id IS NULL OR TRIM(transaction_id) = '' THEN 1 ELSE 0 END)
FROM raw_transactions

UNION ALL

SELECT
    'raw_transactions.customer_id',
    SUM(CASE WHEN customer_id IS NULL OR TRIM(customer_id) = '' THEN 1 ELSE 0 END)
FROM raw_transactions

UNION ALL

SELECT
    'raw_conversions.conversion_stage',
    SUM(CASE WHEN conversion_stage IS NULL OR TRIM(conversion_stage) = '' THEN 1 ELSE 0 END)
FROM raw_conversions

UNION ALL

SELECT
    'raw_activity.activity_type',
    SUM(CASE WHEN activity_type IS NULL OR TRIM(activity_type) = '' THEN 1 ELSE 0 END)
FROM raw_activity;


-- ============================================================================
-- 3. FULLY BLANK TRANSACTION ROWS
-- ============================================================================

SELECT COUNT(*) AS fully_blank_transaction_rows
FROM raw_transactions
WHERE (transaction_id IS NULL OR TRIM(transaction_id) = '')
  AND (customer_id IS NULL OR TRIM(customer_id) = '')
  AND (campaign_id IS NULL OR TRIM(campaign_id) = '')
  AND (transaction_date IS NULL OR TRIM(transaction_date) = '')
  AND (revenue IS NULL OR TRIM(revenue) = '');


-- ============================================================================
-- 4. DUPLICATE KEYS
-- ============================================================================

SELECT
    'raw_customers.customer_id' AS field,
    COUNT(*) - COUNT(DISTINCT TRIM(customer_id)) AS duplicate_row_count
FROM raw_customers
WHERE customer_id IS NOT NULL

UNION ALL

SELECT
    'raw_campaigns.campaign_id',
    COUNT(*) - COUNT(DISTINCT TRIM(campaign_id))
FROM raw_campaigns
WHERE campaign_id IS NOT NULL

UNION ALL

SELECT
    'raw_transactions.transaction_id',
    COUNT(*) - COUNT(DISTINCT TRIM(transaction_id))
FROM raw_transactions
WHERE transaction_id IS NOT NULL;


-- ============================================================================
-- 5. CATEGORY VARIANTS
-- ============================================================================

SELECT DISTINCT acquisition_channel, COUNT(*) AS occurrences
FROM raw_customers
GROUP BY acquisition_channel
ORDER BY acquisition_channel;

SELECT DISTINCT country, COUNT(*) AS occurrences
FROM raw_customers
GROUP BY country
ORDER BY country;

SELECT DISTINCT channel, COUNT(*) AS occurrences
FROM raw_campaigns
GROUP BY channel
ORDER BY channel;


-- ============================================================================
-- 6. DATE FORMAT DISTRIBUTION
-- ============================================================================

SELECT
    CASE
        WHEN signup_date IS NULL OR TRIM(signup_date) = '' THEN 'blank'
        WHEN signup_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 'YYYY-MM-DD'
        WHEN signup_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN 'DD-MM-YYYY'
        WHEN signup_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN 'MM/DD/YYYY'
        WHEN signup_date REGEXP '^[0-9]{2} [A-Za-z]{3} [0-9]{4}$' THEN 'DD Mon YYYY'
        ELSE 'UNRECOGNIZED'
    END AS date_format,
    COUNT(*) AS row_count
FROM raw_customers
GROUP BY date_format
ORDER BY row_count DESC;


-- ============================================================================
-- 7. CURRENCY FORMAT CHECK
-- ============================================================================

SELECT
    CASE
        WHEN spend REGEXP '[^0-9.-]' THEN 'has currency symbol or comma'
        ELSE 'plain number'
    END AS spend_format,
    COUNT(*) AS row_count
FROM raw_campaign_performance
GROUP BY spend_format;

SELECT
    CASE
        WHEN revenue REGEXP '[^0-9.-]' THEN 'has currency symbol or comma'
        ELSE 'plain number'
    END AS revenue_format,
    COUNT(*) AS row_count
FROM raw_transactions
GROUP BY revenue_format;


-- ============================================================================
-- 8. NEGATIVE VALUES
-- ============================================================================

SELECT COUNT(*) AS negative_spend_rows
FROM raw_campaign_performance
WHERE REGEXP_REPLACE(spend, '[^0-9.-]', '') NOT IN ('', '-', '.')
  AND CAST(REGEXP_REPLACE(spend, '[^0-9.-]', '') AS DECIMAL(14,2)) < 0;

SELECT COUNT(*) AS negative_revenue_rows
FROM raw_transactions
WHERE REGEXP_REPLACE(revenue, '[^0-9.-]', '') NOT IN ('', '-', '.')
  AND CAST(REGEXP_REPLACE(revenue, '[^0-9.-]', '') AS DECIMAL(14,2)) < 0;


-- ============================================================================
-- 9. CLICKS > IMPRESSIONS
-- ============================================================================

SELECT COUNT(*) AS clicks_exceed_impressions_rows
FROM raw_campaign_performance
WHERE CAST(NULLIF(TRIM(clicks), '') AS UNSIGNED)
      > CAST(CAST(NULLIF(TRIM(impressions), '') AS DECIMAL(12,2)) AS UNSIGNED);


-- ============================================================================
-- 10. ORPHAN FOREIGN KEYS
-- ============================================================================

SELECT COUNT(*) AS orphan_campaign_ids_in_performance
FROM raw_campaign_performance rcp
WHERE TRIM(rcp.campaign_id) NOT IN (
    SELECT DISTINCT TRIM(campaign_id)
    FROM raw_campaigns
    WHERE campaign_id IS NOT NULL
);

SELECT COUNT(*) AS orphan_customer_ids_in_transactions
FROM raw_transactions rt
WHERE TRIM(rt.customer_id) NOT IN (
    SELECT DISTINCT TRIM(customer_id)
    FROM raw_customers
    WHERE customer_id IS NOT NULL
);

SELECT COUNT(*) AS orphan_customer_ids_in_activity
FROM raw_activity ra
WHERE TRIM(ra.customer_id) NOT IN (
    SELECT DISTINCT TRIM(customer_id)
    FROM raw_customers
    WHERE customer_id IS NOT NULL
);