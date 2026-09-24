-- ============================================================================
-- 15_stored_procedures.sql
-- ============================================================================

USE marketing_analytics;


-- ============================================================================
-- PROCEDURE 1: sp_refresh_materialized_tables
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_refresh_materialized_tables;

DELIMITER //

CREATE PROCEDURE sp_refresh_materialized_tables()
BEGIN

    TRUNCATE TABLE tbl_customer_first_touch;

    INSERT INTO tbl_customer_first_touch
    WITH ranked_conversions AS (
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
        rc.customer_key,
        rc.conversion_date,
        dcamp.campaign_key,
        dcamp.campaign_name,
        dch.channel_key,
        dch.channel_name
    FROM ranked_conversions rc
    JOIN dim_campaign dcamp
        ON rc.campaign_key = dcamp.campaign_key
    JOIN dim_channel dch
        ON dcamp.channel_key = dch.channel_key
    WHERE rc.rn = 1;


    TRUNCATE TABLE tbl_customer_ltv;

    INSERT INTO tbl_customer_ltv
    SELECT
        dc.customer_key,
        dc.customer_id,
        dc.acquisition_channel,
        COUNT(fcr.transaction_id),
        COALESCE(SUM(fcr.revenue), 0)
    FROM dim_customer dc
    LEFT JOIN fact_customer_revenue fcr
        ON dc.customer_key = fcr.customer_key
    GROUP BY
        dc.customer_key,
        dc.customer_id,
        dc.acquisition_channel;


    TRUNCATE TABLE tbl_customer_retention;

    INSERT INTO tbl_customer_retention
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
          AND dd.date_key <> 19000101

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
          AND dd.date_key <> 19000101
    )
    SELECT
        dc.customer_key,
        dc.acquisition_channel,
        MAX(
            CASE
                WHEN pse.event_date > dc.signup_date + INTERVAL 30 DAY
                THEN 1
                ELSE 0
            END
        )
    FROM dim_customer dc
    LEFT JOIN post_signup_engagement pse
        ON dc.customer_key = pse.customer_key
    GROUP BY
        dc.customer_key,
        dc.acquisition_channel;

    SELECT
        (SELECT COUNT(*) FROM tbl_customer_first_touch)
            AS tbl_customer_first_touch_rows,
        (SELECT COUNT(*) FROM tbl_customer_ltv)
            AS tbl_customer_ltv_rows,
        (SELECT COUNT(*) FROM tbl_customer_retention)
            AS tbl_customer_retention_rows;

END //

DELIMITER ;

CALL sp_refresh_materialized_tables();


-- ============================================================================
-- PROCEDURE 2: sp_get_channel_performance
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_get_channel_performance;

DELIMITER //

CREATE PROCEDURE sp_get_channel_performance(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN

    IF p_start_date > p_end_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'p_start_date must be on or before p_end_date';
    END IF;

    SELECT
        dch.channel_name,
        ROUND(SUM(fms.spend), 2) AS total_spend,
        ROUND(
            COALESCE(rev.total_revenue, 0),
            2
        ) AS total_revenue,
        ROUND(
            COALESCE(rev.total_revenue, 0) /
            NULLIF(SUM(fms.spend), 0),
            3
        ) AS roas,
        ROUND(
            (
                COALESCE(rev.total_revenue, 0) -
                SUM(fms.spend)
            ) / NULLIF(SUM(fms.spend), 0),
            3
        ) AS roi
    FROM fact_marketing_spend fms
    JOIN dim_channel dch
        ON fms.channel_key = dch.channel_key
    JOIN dim_date dd
        ON fms.date_key = dd.date_key
    LEFT JOIN (
        SELECT
            dcamp.channel_key,
            SUM(fcr.revenue) AS total_revenue
        FROM fact_customer_revenue fcr
        JOIN dim_campaign dcamp
            ON fcr.campaign_key = dcamp.campaign_key
        JOIN dim_date dd2
            ON fcr.date_key = dd2.date_key
        WHERE dd2.full_date BETWEEN p_start_date AND p_end_date
        GROUP BY dcamp.channel_key
    ) rev
        ON dch.channel_key = rev.channel_key
    WHERE dd.full_date BETWEEN p_start_date AND p_end_date
    GROUP BY
        dch.channel_name,
        rev.total_revenue
    ORDER BY total_spend DESC;

END //

DELIMITER ;

CALL sp_get_channel_performance(
    '2025-01-01',
    '2025-06-30'
);


-- ============================================================================
-- PROCEDURE 3: sp_get_campaign_performance
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_get_campaign_performance;

DELIMITER //

CREATE PROCEDURE sp_get_campaign_performance(
    IN p_channel_name VARCHAR(50)
)
BEGIN

    SELECT *
    FROM vw_campaign_performance
    WHERE p_channel_name IS NULL
       OR channel_name = p_channel_name
    ORDER BY total_spend DESC;

END //

DELIMITER ;

CALL sp_get_campaign_performance('Social');

CALL sp_get_campaign_performance(NULL);


-- ============================================================================
-- PROCEDURE 4: sp_get_customer_economics
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_get_customer_economics;

DELIMITER //

CREATE PROCEDURE sp_get_customer_economics(
    IN p_channel_name VARCHAR(50)
)
BEGIN

    SELECT *
    FROM vw_customer_economics
    WHERE p_channel_name IS NULL
       OR acquisition_channel = p_channel_name
    ORDER BY customer_ltv DESC;

END //

DELIMITER ;

CALL sp_get_customer_economics('Referral');