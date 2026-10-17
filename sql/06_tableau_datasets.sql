-- ============================================================================
-- OLIST E-COMMERCE ANALYTICS PROJECT
-- File: 06_tableau_datasets.sql
-- Purpose: Produce the final Tableau-ready datasets used by the four dashboards
-- MySQL 8+
--
-- Reporting period for dashboard-facing analyses:
--     2017-01-01 through 2018-08-31
--
-- Notes:
--   * Each section contains only the final query used for a Tableau data source.
--   * Development checks and intermediate experiments are intentionally excluded.
--   * Run 01_database_setup.sql through 05_advanced_sql_analysis.sql first.
--   * Dataset 8 expects vw_rfm_customers to be created in 05_advanced_sql_analysis.sql.
-- ============================================================================

USE olist_ecommerce;


-- ============================================================================
-- TABLEAU DATASET 1: SELLER RISK MATRIX
-- Suggested export: seller_risk_matrix.csv
-- Purpose: Compare seller delivery risk, review performance, and sales volume
-- Source Views: vw_order_item_details + vw_order_delivery_performance
--               + vw_order_review_summary
-- Grain: One row per seller
-- Population: Sellers with at least 30 delivered orders
-- Risk thresholds: 5.49% late-delivery rate and 4.19 average review score
-- ============================================================================

WITH seller_orders AS (
    SELECT
        seller_id,
        seller_city,
        seller_state,
        order_id,
        COUNT(*) AS items_sold,
        ROUND(SUM(price), 2) AS product_value
    FROM vw_order_item_details
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp < '2018-09-01'
    GROUP BY
        seller_id,
        seller_city,
        seller_state,
        order_id
),

seller_order_metrics AS (
    SELECT
        so.seller_id,
        so.seller_city,
        so.seller_state,
        so.order_id,
        so.items_sold,
        so.product_value,
        d.delivery_status,
        d.delivery_variance_days,
        r.avg_review_score
    FROM seller_orders AS so
    INNER JOIN vw_order_delivery_performance AS d
        ON so.order_id = d.order_id
    LEFT JOIN vw_order_review_summary AS r
        ON so.order_id = r.order_id
    WHERE d.order_delivered_customer_date IS NOT NULL
),

seller_performance AS (
    SELECT
        seller_id,
        seller_city,
        seller_state,
        COUNT(*) AS delivered_orders,
        SUM(items_sold) AS items_sold,
        ROUND(SUM(product_value), 2) AS product_value,
        SUM(
            CASE
                WHEN delivery_status = 'Late' THEN 1
                ELSE 0
            END
        ) AS late_orders,
        ROUND(
            SUM(
                CASE
                    WHEN delivery_status = 'Late' THEN 1
                    ELSE 0
                END
            ) * 100.0 / COUNT(*),
            2
        ) AS late_delivery_rate_pct,
        ROUND(AVG(avg_review_score), 2) AS avg_review_score
    FROM seller_order_metrics
    GROUP BY
        seller_id,
        seller_city,
        seller_state
)

SELECT
    seller_id,
    seller_city,
    seller_state,
    delivered_orders,
    items_sold,
    product_value,
    late_orders,
    late_delivery_rate_pct,
    avg_review_score,
    CASE
        WHEN late_delivery_rate_pct < 5.49
             AND avg_review_score >= 4.19
            THEN 'Strong Performers'
        WHEN late_delivery_rate_pct >= 5.49
             AND avg_review_score >= 4.19
            THEN 'Delivery Risk'
        WHEN late_delivery_rate_pct < 5.49
             AND avg_review_score < 4.19
            THEN 'Satisfaction Risk'
        ELSE 'High Risk'
    END AS risk_segment
FROM seller_performance
WHERE delivered_orders >= 30
ORDER BY late_delivery_rate_pct DESC;


-- ============================================================================
-- TABLEAU DATASET 2: DELIVERY REVIEW ANALYSIS
-- Suggested export: delivery_review_analysis.csv
-- Purpose: Analyze the relationship between delivery timeliness and reviews
-- Source Views: vw_order_delivery_performance + vw_order_review_summary
-- Grain: One row per reviewed delivered order
-- ============================================================================

SELECT
    d.order_id,
    d.customer_id,
    d.order_purchase_timestamp,
    d.delivery_days,
    d.estimated_delivery_days,
    d.delivery_variance_days,
    d.delivery_status,
    CASE
        WHEN d.delivery_variance_days > 0
            THEN d.delivery_variance_days
        ELSE 0
    END AS days_late,
    r.avg_review_score,
    r.review_count
FROM vw_order_delivery_performance AS d
INNER JOIN vw_order_review_summary AS r
    ON d.order_id = r.order_id
WHERE d.order_status = 'delivered'
  AND d.order_delivered_customer_date IS NOT NULL
  AND r.has_review = 1
  AND d.order_purchase_timestamp >= '2017-01-01'
  AND d.order_purchase_timestamp < '2018-09-01'
ORDER BY d.delivery_variance_days DESC;


-- ============================================================================
-- TABLEAU DATASET 3: CATEGORY REVIEW ANALYSIS
-- Suggested export: category_review_analysis.csv
-- Purpose: Compare product-category demand, product value, and review performance
-- Source Views: vw_order_item_details + vw_order_review_summary
-- Grain: One row per product category
-- Note: Reviews are recorded at order level. For multi-category orders, the
--       order review is associated once with each category present in that order.
-- ============================================================================

WITH order_categories AS (
    SELECT
        order_id,
        product_category_name_english AS product_category,
        COUNT(*) AS items_in_category,
        ROUND(SUM(price), 2) AS category_product_value
    FROM vw_order_item_details
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp < '2018-09-01'
    GROUP BY
        order_id,
        product_category_name_english
),

category_review_orders AS (
    SELECT
        oc.order_id,
        oc.product_category,
        oc.items_in_category,
        oc.category_product_value,
        r.avg_review_score
    FROM order_categories AS oc
    INNER JOIN vw_order_review_summary AS r
        ON oc.order_id = r.order_id
    WHERE r.has_review = 1
)

SELECT
    product_category,
    COUNT(DISTINCT order_id) AS reviewed_orders,
    SUM(items_in_category) AS items_sold,
    ROUND(SUM(category_product_value), 2) AS product_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score
FROM category_review_orders
GROUP BY product_category
HAVING COUNT(DISTINCT order_id) >= 30
ORDER BY reviewed_orders DESC;


-- ============================================================================
-- TABLEAU DATASET 4: DISPATCH VS CARRIER DELAY
-- Suggested export: dispatch_carrier_analysis.csv
-- Purpose: Separate fulfillment time into dispatch/processing and carrier transit
-- Source View: vw_order_delivery_performance
-- Grain: One row per delivered order
-- ============================================================================

SELECT
    order_id,
    customer_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    carrier_handoff_days AS dispatch_days,
    TIMESTAMPDIFF(
        DAY,
        order_delivered_carrier_date,
        order_delivered_customer_date
    ) AS carrier_delivery_days,
    delivery_days,
    delivery_variance_days,
    delivery_status
FROM vw_order_delivery_performance
WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND carrier_handoff_days >= 0
  AND TIMESTAMPDIFF(
        DAY,
        order_delivered_carrier_date,
        order_delivered_customer_date
      ) >= 0
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
ORDER BY order_purchase_timestamp;


-- ============================================================================
-- TABLEAU DATASET 5: OVERVIEW ORDER-LEVEL DATA
-- Suggested export: Overview_orders.csv
-- Purpose: Support overview KPIs, monthly trends, and state performance
-- Source View/Table: vw_order_financials + customers
-- Grain: One row per delivered order
-- ============================================================================

SELECT
    f.order_id,
    f.customer_id,
    f.order_purchase_timestamp,
    CAST(
        DATE_FORMAT(f.order_purchase_timestamp, '%Y-%m-01') AS DATE
    ) AS order_month,
    c.customer_state,
    f.item_count,
    f.distinct_product_count,
    f.product_value,
    f.freight_value,
    f.item_total_value,
    f.payment_total
FROM vw_order_financials AS f
INNER JOIN customers AS c
    ON f.customer_id = c.customer_id
WHERE f.order_status = 'delivered'
  AND f.order_purchase_timestamp >= '2017-01-01'
  AND f.order_purchase_timestamp < '2018-09-01'
ORDER BY f.order_purchase_timestamp;


-- ============================================================================
-- TABLEAU DATASET 6: PAYMENT METHOD MIX
-- Suggested export: payment_method_mix.csv
-- Purpose: Compare payment methods used for delivered orders
-- Source Tables: payments + orders
-- Grain: One row per payment type
-- ============================================================================

SELECT
    p.payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT p.order_id) AS orders_using_payment_type,
    ROUND(SUM(p.payment_value), 2) AS total_payment_value,
    ROUND(AVG(p.payment_value), 2) AS avg_payment_value,
    ROUND(AVG(p.payment_installments), 2) AS avg_installments
FROM payments AS p
INNER JOIN orders AS o
    ON p.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY p.payment_type
ORDER BY total_payment_value DESC;


-- ============================================================================
-- TABLEAU DATASET 7: DELIVERY PERFORMANCE BY STATE
-- Suggested export: delivery_state_performance.csv
-- Purpose: Support state late-rate analysis and late-severity filtering
-- Source View/Table: vw_order_delivery_performance + customers
-- Grain: One row per delivered order with usable delivery dates
-- ============================================================================

SELECT
    d.order_id,
    d.customer_id,
    c.customer_state,
    d.order_purchase_timestamp,
    CAST(
        DATE_FORMAT(d.order_purchase_timestamp, '%Y-%m-01') AS DATE
    ) AS order_month,
    d.delivery_days,
    d.estimated_delivery_days,
    d.delivery_variance_days,
    d.delivery_status,
    CASE
        WHEN d.delivery_status = 'Late' THEN 1
        ELSE 0
    END AS late_flag,
    CASE
        WHEN d.delivery_variance_days > 0
            THEN d.delivery_variance_days
        ELSE 0
    END AS days_late
FROM vw_order_delivery_performance AS d
INNER JOIN customers AS c
    ON d.customer_id = c.customer_id
WHERE d.order_status = 'delivered'
  AND d.order_delivered_customer_date IS NOT NULL
  AND d.delivery_status IN ('Early/On Time', 'Late')
  AND d.order_purchase_timestamp >= '2017-01-01'
  AND d.order_purchase_timestamp < '2018-09-01'
ORDER BY d.order_purchase_timestamp;


-- ============================================================================
-- TABLEAU DATASET 8: RFM CUSTOMERS
-- Suggested export: rfm_customers.csv
-- Purpose: Support RFM segments, repeat purchase rate, and spend concentration
-- Source View: vw_rfm_customers
-- Grain: One row per customer_unique_id
-- Note: vw_rfm_customers is created in 05_advanced_sql_analysis.sql.
-- ============================================================================

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,
    rfm_segment
FROM vw_rfm_customers
ORDER BY
    r_score DESC,
    f_score DESC,
    m_score DESC,
    customer_unique_id;


-- ============================================================================
-- TABLEAU DATASET 9: CUSTOMER COHORT RETENTION
-- Suggested export: cohort_retention.csv
-- Purpose: Support the monthly customer-retention heatmap
-- Source Tables: orders + customers
-- Grain: One row per cohort_month + months_since_cohort
-- Cohorts displayed: January 2017 through August 2018
-- Note: Full delivered-order history before 2018-09-01 is used to identify each
--       customer's true first purchase. Valid inactive months are filled with zero;
--       months that had not yet elapsed remain absent from the output.
-- ============================================================================

WITH RECURSIVE month_numbers AS (
    SELECT 0 AS months_since_cohort

    UNION ALL

    SELECT months_since_cohort + 1
    FROM month_numbers
    WHERE months_since_cohort < 19
),

customer_orders AS (
    SELECT
        c.customer_unique_id,
        CAST(
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS DATE
        ) AS order_month
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp < '2018-09-01'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_orders
    GROUP BY customer_unique_id
),

cohort_activity AS (
    SELECT
        co.customer_unique_id,
        co.order_month,
        cc.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            cc.cohort_month,
            co.order_month
        ) AS months_since_cohort
    FROM customer_orders AS co
    INNER JOIN customer_cohorts AS cc
        ON co.customer_unique_id = cc.customer_unique_id
    WHERE cc.cohort_month >= '2017-01-01'
),

cohort_counts AS (
    SELECT
        cohort_month,
        months_since_cohort,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM cohort_activity
    GROUP BY
        cohort_month,
        months_since_cohort
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM cohort_activity
    WHERE months_since_cohort = 0
    GROUP BY cohort_month
),

cohort_grid AS (
    SELECT
        cs.cohort_month,
        mn.months_since_cohort,
        cs.cohort_size
    FROM cohort_sizes AS cs
    CROSS JOIN month_numbers AS mn
    WHERE mn.months_since_cohort <= TIMESTAMPDIFF(
        MONTH,
        cs.cohort_month,
        '2018-08-01'
    )
)

SELECT
    cg.cohort_month,
    cg.months_since_cohort,
    COALESCE(cc.active_customers, 0) AS active_customers,
    cg.cohort_size,
    ROUND(
        COALESCE(cc.active_customers, 0) * 100.0 / cg.cohort_size,
        2
    ) AS retention_rate_pct
FROM cohort_grid AS cg
LEFT JOIN cohort_counts AS cc
    ON cg.cohort_month = cc.cohort_month
   AND cg.months_since_cohort = cc.months_since_cohort
ORDER BY
    cg.cohort_month,
    cg.months_since_cohort;
