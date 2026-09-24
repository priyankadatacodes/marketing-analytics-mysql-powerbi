-- ============================================================================
--  12_cohort_analysis.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- BUILD THE CUSTOMER -> MONTH_OFFSET ENGAGEMENT TABLE
-- ============================================================================

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
        dd.full_date AS event_date,
        NULL AS revenue
    FROM fact_customer_activity fca
    JOIN dim_date dd
        ON fca.date_key = dd.date_key
    WHERE dd.date_key <> 19000101

    UNION ALL

    SELECT
        fcr.customer_key,
        dd.full_date AS event_date,
        fcr.revenue
    FROM fact_customer_revenue fcr
    JOIN dim_date dd
        ON fcr.date_key = dd.date_key
    WHERE dd.date_key <> 19000101
),
customer_month_offsets AS (
    SELECT
        cc.customer_key,
        cc.cohort_month,
        cc.acquisition_channel,
        TIMESTAMPDIFF(
            MONTH,
            cc.signup_date,
            ee.event_date
        ) AS month_offset,
        ee.revenue
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


-- ============================================================================
-- Q1: WHICH COHORT HAS THE STRONGEST RETENTION?
-- Q3: ARE NEWER CUSTOMERS RETAINING BETTER?
-- Q4: HAS CUSTOMER QUALITY IMPROVED OVER TIME?
-- ============================================================================

SELECT
    cc.cohort_month,
    COUNT(DISTINCT cc.customer_key) AS cohort_size,

    COUNT(
        DISTINCT CASE
            WHEN cmo.month_offset = 0
                THEN cmo.customer_key
        END
    ) AS m0_active,

    COUNT(
        DISTINCT CASE
            WHEN cmo.month_offset = 1
                THEN cmo.customer_key
        END
    ) AS m1_active,

    COUNT(
        DISTINCT CASE
            WHEN cmo.month_offset = 2
                THEN cmo.customer_key
        END
    ) AS m2_active,

    COUNT(
        DISTINCT CASE
            WHEN cmo.month_offset = 3
                THEN cmo.customer_key
        END
    ) AS m3_active,

    COUNT(
        DISTINCT CASE
            WHEN cmo.month_offset = 4
                THEN cmo.customer_key
        END
    ) AS m4_active,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 1
                    THEN cmo.customer_key
            END
        )
        / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m1_retention_pct,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 2
                    THEN cmo.customer_key
            END
        )
        / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m2_retention_pct,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 3
                    THEN cmo.customer_key
            END
        )
        / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m3_retention_pct,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 4
                    THEN cmo.customer_key
            END
        )
        / COUNT(DISTINCT cc.customer_key),
        1
    ) AS m4_retention_pct

FROM customer_cohort cc
LEFT JOIN customer_month_offsets cmo
    ON cc.customer_key = cmo.customer_key
GROUP BY cc.cohort_month
ORDER BY cc.cohort_month;


-- ============================================================================
-- Q2: WHICH COHORT GENERATES THE MOST REVENUE?
-- ============================================================================

WITH customer_cohort AS (
    SELECT
        customer_key,
        DATE_FORMAT(signup_date, '%Y-%m') AS cohort_month
    FROM dim_customer
    WHERE signup_date IS NOT NULL
),
customer_month_revenue AS (
    SELECT
        cc.customer_key,
        cc.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            dc.signup_date,
            dd.full_date
        ) AS month_offset,
        fcr.revenue
    FROM fact_customer_revenue fcr
    JOIN dim_customer dc
        ON fcr.customer_key = dc.customer_key
    JOIN customer_cohort cc
        ON dc.customer_key = cc.customer_key
    JOIN dim_date dd
        ON fcr.date_key = dd.date_key
    WHERE dd.full_date >= dc.signup_date
      AND dd.date_key <> 19000101
      AND TIMESTAMPDIFF(
            MONTH,
            dc.signup_date,
            dd.full_date
          ) BETWEEN 0 AND 4
)
SELECT
    cc.cohort_month,
    COUNT(DISTINCT cc.customer_key) AS cohort_size,

    ROUND(
        SUM(
            CASE
                WHEN cmr.month_offset = 0
                    THEN cmr.revenue
                ELSE 0
            END
        ),
        2
    ) AS m0_revenue,

    ROUND(
        SUM(
            CASE
                WHEN cmr.month_offset = 1
                    THEN cmr.revenue
                ELSE 0
            END
        ),
        2
    ) AS m1_revenue,

    ROUND(
        SUM(
            CASE
                WHEN cmr.month_offset = 2
                    THEN cmr.revenue
                ELSE 0
            END
        ),
        2
    ) AS m2_revenue,

    ROUND(
        SUM(
            CASE
                WHEN cmr.month_offset = 3
                    THEN cmr.revenue
                ELSE 0
            END
        ),
        2
    ) AS m3_revenue,

    ROUND(
        SUM(
            CASE
                WHEN cmr.month_offset = 4
                    THEN cmr.revenue
                ELSE 0
            END
        ),
        2
    ) AS m4_revenue,

    ROUND(
        SUM(
            CASE
                WHEN cmr.month_offset BETWEEN 0 AND 4
                    THEN cmr.revenue
                ELSE 0
            END
        ),
        2
    ) AS total_m0_to_m4_revenue,

    RANK() OVER (
        ORDER BY
            SUM(
                CASE
                    WHEN cmr.month_offset BETWEEN 0 AND 4
                        THEN cmr.revenue
                    ELSE 0
                END
            ) DESC
    ) AS revenue_rank

FROM customer_cohort cc
LEFT JOIN customer_month_revenue cmr
    ON cc.customer_key = cmr.customer_key
GROUP BY cc.cohort_month
ORDER BY revenue_rank
LIMIT 15;


-- ============================================================================
-- Q5: WHICH ACQUISITION CHANNELS CREATE THE STRONGEST COHORTS?
-- ============================================================================

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
)
SELECT
    cc.acquisition_channel,
    COUNT(DISTINCT cc.customer_key) AS total_customers,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 1
                    THEN cmo.customer_key
            END
        )
        / COUNT(DISTINCT cc.customer_key),
        1
    ) AS avg_m1_retention_pct,

    ROUND(
        100.0 *
        COUNT(
            DISTINCT CASE
                WHEN cmo.month_offset = 4
                    THEN cmo.customer_key
            END
        )
        / COUNT(DISTINCT cc.customer_key),
        1
    ) AS avg_m4_retention_pct,

    RANK() OVER (
        ORDER BY
            COUNT(
                DISTINCT CASE
                    WHEN cmo.month_offset = 4
                        THEN cmo.customer_key
                END
            )
            / COUNT(DISTINCT cc.customer_key) DESC
    ) AS m4_retention_rank

FROM customer_cohort cc
LEFT JOIN customer_month_offsets cmo
    ON cc.customer_key = cmo.customer_key
GROUP BY cc.acquisition_channel
ORDER BY m4_retention_rank;


-- ============================================================================
-- DOES A CHANNEL THAT LOOKS GOOD AT M0 STAY GOOD OVER TIME?
-- ============================================================================

WITH customer_cohort AS (
    SELECT
        customer_key,
        acquisition_channel,
        signup_date
    FROM dim_customer
    WHERE signup_date IS NOT NULL
),
customer_month_revenue AS (
    SELECT
        cc.customer_key,
        cc.acquisition_channel,
        TIMESTAMPDIFF(
            MONTH,
            cc.signup_date,
            dd.full_date
        ) AS month_offset,
        fcr.revenue
    FROM fact_customer_revenue fcr
    JOIN customer_cohort cc
        ON fcr.customer_key = cc.customer_key
    JOIN dim_date dd
        ON fcr.date_key = dd.date_key
    WHERE dd.full_date >= cc.signup_date
      AND dd.date_key <> 19000101
      AND TIMESTAMPDIFF(
            MONTH,
            cc.signup_date,
            dd.full_date
          ) IN (0, 4)
),
channel_m0_m4 AS (
    SELECT
        acquisition_channel,
        SUM(
            CASE
                WHEN month_offset = 0
                    THEN revenue
                ELSE 0
            END
        ) AS m0_revenue,
        SUM(
            CASE
                WHEN month_offset = 4
                    THEN revenue
                ELSE 0
            END
        ) AS m4_revenue
    FROM customer_month_revenue
    GROUP BY acquisition_channel
)
SELECT
    acquisition_channel,
    ROUND(m0_revenue, 2) AS m0_revenue,
    RANK() OVER (
        ORDER BY m0_revenue DESC
    ) AS m0_rank,
    ROUND(m4_revenue, 2) AS m4_revenue,
    RANK() OVER (
        ORDER BY m4_revenue DESC
    ) AS m4_rank,
    CASE
        WHEN RANK() OVER (ORDER BY m0_revenue DESC)
           = RANK() OVER (ORDER BY m4_revenue DESC)
            THEN 'CONSISTENT -- early appeal matches long-term value'
        WHEN RANK() OVER (ORDER BY m0_revenue DESC)
           < RANK() OVER (ORDER BY m4_revenue DESC)
            THEN 'FADES -- looks better at M0 than it turns out to be'
        ELSE 'GROWS -- undersells itself at M0, stronger later'
    END AS pattern
FROM channel_m0_m4
ORDER BY m0_rank;