-- ============================================================================
-- OLIST E-COMMERCE ANALYTICS PROJECT
-- File: 04_business_analysis.sql
-- Purpose: Answer core business questions using the reusable analytical views
-- Metric note: product_value represents merchandise value from item price, while
-- payment_value/payment_total represents customer payment value at order level.
-- ============================================================================

USE olist_ecommerce;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 1: OVERALL ORDER AND FINANCIAL KPIs
-- Purpose: Establish a high-level baseline across all order statuses
-- Source View: vw_order_financials
-- Grain of Source: One row per order
-- -------------------------------------------------------------------------

SELECT
    COUNT(*) AS total_orders,
    ROUND(SUM(product_value), 2) AS total_product_value,
    ROUND(SUM(freight_value), 2) AS total_freight_value,
    ROUND(SUM(item_total_value), 2) AS total_item_value,
    ROUND(SUM(payment_total), 2) AS total_payment_value,
    ROUND(AVG(payment_total), 2) AS avg_order_value,
    ROUND(AVG(item_count), 2) AS avg_items_per_order
FROM vw_order_financials;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 2: ORDER STATUS BREAKDOWN
-- Purpose: Understand the distribution of orders across fulfillment statuses
-- Source View: vw_order_financials
-- Grain of Output: One row per order status
-- -------------------------------------------------------------------------

SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_orders
FROM vw_order_financials
GROUP BY order_status
ORDER BY order_count DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 3: DELIVERED ORDER KPIs
-- Purpose: Measure completed sales performance using delivered orders only
-- Source View: vw_order_financials
-- Grain of Source: One row per order
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(SUM(product_value), 2) AS delivered_product_value,
    ROUND(SUM(freight_value), 2) AS delivered_freight_value,
    ROUND(SUM(item_total_value), 2) AS delivered_item_value,
    ROUND(SUM(payment_total), 2) AS delivered_payment_value,
    ROUND(AVG(payment_total), 2) AS avg_delivered_order_value,
    ROUND(AVG(item_count), 2) AS avg_items_per_delivered_order
FROM vw_order_financials
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01';


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 4: MONTHLY ORDER AND SALES TRENDS
-- Purpose: Track completed order volume and sales value over time
-- Source View: vw_order_financials
-- Grain of Output: One row per month
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(product_value), 2) AS product_value,
    ROUND(SUM(payment_total), 2) AS payment_value,
    ROUND(AVG(payment_total), 2) AS avg_order_value
FROM vw_order_financials
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY order_month;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 5: PRODUCT CATEGORY PERFORMANCE
-- Purpose: Compare delivered product categories by demand and sales value
-- Source View: vw_order_item_details
-- Grain of Output: One row per product category
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    product_category_name_english AS product_category,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT product_id) AS distinct_products_sold,
    ROUND(SUM(price), 2) AS product_value,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(AVG(price), 2) AS avg_item_price
FROM vw_order_item_details
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY product_category_name_english
ORDER BY product_value DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 6: CATEGORY SALES SHARE
-- Purpose: Measure each product category's contribution to delivered product value
-- Source View: vw_order_item_details
-- Grain of Output: One row per product category
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

WITH category_sales AS (
    SELECT
        product_category_name_english AS product_category,
        ROUND(SUM(price), 2) AS product_value
    FROM vw_order_item_details
    WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
    GROUP BY product_category_name_english
)

SELECT
    product_category,
    product_value,
    ROUND(
        product_value * 100.0 / SUM(product_value) OVER (),
        2
    ) AS product_value_share_pct
FROM category_sales
ORDER BY product_value DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 7: TOP SELLERS BY PRODUCT VALUE
-- Purpose: Identify the highest-value sellers based on delivered merchandise sales
-- Source View: vw_order_item_details
-- Grain of Output: One row per seller
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    seller_id,
    seller_city,
    seller_state,
    COUNT(DISTINCT order_id) AS delivered_orders,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT product_id) AS distinct_products_sold,
    ROUND(SUM(price), 2) AS product_value,
    ROUND(AVG(price), 2) AS avg_item_price
FROM vw_order_item_details
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY
    seller_id,
    seller_city,
    seller_state
ORDER BY product_value DESC
LIMIT 20;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 8: CUSTOMER STATE PERFORMANCE
-- Purpose: Compare delivered order activity and product value by customer state
-- Source View: vw_order_item_details
-- Grain of Output: One row per customer state
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    customer_state,
    COUNT(DISTINCT order_id) AS delivered_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(price), 2) AS product_value,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(AVG(price), 2) AS avg_item_price
FROM vw_order_item_details
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
GROUP BY customer_state
ORDER BY product_value DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 9: CUSTOMER STATE SALES SHARE
-- Purpose: Measure each customer state's contribution to delivered product value
-- Source View: vw_order_item_details
-- Grain of Output: One row per customer state
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

WITH state_sales AS (
    SELECT
        customer_state,
        ROUND(SUM(price), 2) AS product_value
    FROM vw_order_item_details
    WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
    GROUP BY customer_state
)

SELECT
    customer_state,
    product_value,
    ROUND(
        product_value * 100.0 / SUM(product_value) OVER (),
        2
    ) AS product_value_share_pct
FROM state_sales
ORDER BY product_value DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 10: DELIVERY PERFORMANCE SUMMARY
-- Purpose: Measure overall delivery speed and on-time performance
-- Source View: vw_order_delivery_performance
-- Grain of Source: One row per order
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(estimated_delivery_days), 2) AS avg_estimated_delivery_days,
    ROUND(AVG(delivery_variance_days), 2) AS avg_delivery_variance_days,

    SUM(
        CASE
            WHEN delivery_status = 'Early/On Time' THEN 1
            ELSE 0
        END
    ) AS early_or_on_time_orders,

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
    ) AS late_delivery_rate_pct

FROM vw_order_delivery_performance

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01';


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 11: DELIVERY PERFORMANCE BY CUSTOMER STATE
-- Purpose: Compare delivery speed and late-delivery rates across customer states
-- Source Views: vw_order_delivery_performance + customers
-- Grain of Output: One row per customer state
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(v.delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(v.delivery_variance_days), 2) AS avg_delivery_variance_days,

    SUM(
        CASE
            WHEN v.delivery_status = 'Late' THEN 1
            ELSE 0
        END
    ) AS late_orders,

    ROUND(
        SUM(
            CASE
                WHEN v.delivery_status = 'Late' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_rate_pct

FROM vw_order_delivery_performance AS v

JOIN customers AS c
    ON v.customer_id = c.customer_id

WHERE v.order_status = 'delivered'
  AND v.order_delivered_customer_date IS NOT NULL
  AND v.order_purchase_timestamp >= '2017-01-01'
  AND v.order_purchase_timestamp < '2018-09-01'

GROUP BY c.customer_state

ORDER BY late_delivery_rate_pct DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 12: REVIEW SCORE SUMMARY
-- Purpose: Understand overall customer review patterns for reviewed orders
-- Source View: vw_order_review_summary
-- Grain of Source: One row per order
-- -------------------------------------------------------------------------

SELECT
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score,

    SUM(
        CASE
            WHEN avg_review_score >= 4 THEN 1
            ELSE 0
        END
    ) AS positive_review_orders,

    SUM(
        CASE
            WHEN avg_review_score <= 2 THEN 1
            ELSE 0
        END
    ) AS low_review_orders,

    ROUND(
        SUM(
            CASE
                WHEN avg_review_score >= 4 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS positive_review_rate_pct

FROM vw_order_review_summary

WHERE has_review = 1;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 13: REVIEW SCORE BY DELIVERY PERFORMANCE
-- Purpose: Compare customer review scores for on-time versus late deliveries
-- Source Views: vw_order_review_summary + vw_order_delivery_performance
-- Grain of Output: One row per delivery status
-- Note: Excludes delivered-status orders with missing actual delivery dates.
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    d.delivery_status,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(r.avg_review_score), 2) AS avg_review_score,

    ROUND(
        SUM(
            CASE
                WHEN r.avg_review_score >= 4 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS positive_review_rate_pct,

    ROUND(
        SUM(
            CASE
                WHEN r.avg_review_score <= 2 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS low_review_rate_pct

FROM vw_order_review_summary AS r

JOIN vw_order_delivery_performance AS d
    ON r.order_id = d.order_id

WHERE r.has_review = 1
  AND d.order_status = 'delivered'
  AND d.order_delivered_customer_date IS NOT NULL
  AND d.order_purchase_timestamp >= '2017-01-01'
  AND d.order_purchase_timestamp < '2018-09-01'

GROUP BY d.delivery_status

ORDER BY avg_review_score DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 14: REPEAT CUSTOMER SUMMARY
-- Purpose: Compare one-time and repeat customers at the customer level
-- Source View: vw_customer_lifetime_summary
-- Grain of Output: One row per repeat-customer flag
-- -------------------------------------------------------------------------

SELECT
    repeat_customer_flag,
    COUNT(*) AS customer_count,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(total_spend), 2) AS avg_customer_spend,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value

FROM vw_customer_lifetime_summary

GROUP BY repeat_customer_flag

ORDER BY repeat_customer_flag;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 15: CUSTOMER RECENCY AND FREQUENCY SUMMARY
-- Purpose: Understand how recently customers purchased and how often they returned
-- Source View: vw_customer_lifetime_summary
-- Grain of Output: One row per recency band
-- -------------------------------------------------------------------------

SELECT
    CASE
        WHEN recency_days <= 30 THEN '0-30 Days'
        WHEN recency_days <= 60 THEN '31-60 Days'
        WHEN recency_days <= 90 THEN '61-90 Days'
        WHEN recency_days <= 180 THEN '91-180 Days'
        ELSE '181+ Days'
    END AS recency_band,

    COUNT(*) AS customer_count,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(total_spend), 2) AS avg_customer_spend

FROM vw_customer_lifetime_summary

GROUP BY
    CASE
        WHEN recency_days <= 30 THEN '0-30 Days'
        WHEN recency_days <= 60 THEN '31-60 Days'
        WHEN recency_days <= 90 THEN '61-90 Days'
        WHEN recency_days <= 180 THEN '91-180 Days'
        ELSE '181+ Days'
    END

ORDER BY MIN(recency_days);


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 16: PAYMENT METHOD MIX
-- Purpose: Understand how customers pay for delivered orders
-- Source Tables: payments + orders
-- Grain of Output: One row per payment type
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    p.payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT p.order_id) AS orders_using_payment_type,
    ROUND(SUM(p.payment_value), 2) AS total_payment_value,
    ROUND(AVG(p.payment_value), 2) AS avg_payment_value,
    ROUND(AVG(p.payment_installments), 2) AS avg_installments

FROM payments AS p

JOIN orders AS o
    ON p.order_id = o.order_id

WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'

GROUP BY p.payment_type

ORDER BY total_payment_value DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 17: FREIGHT BURDEN BY CUSTOMER STATE
-- Purpose: Compare shipping cost relative to merchandise value across states
-- Source View: vw_order_item_details
-- Grain of Output: One row per customer state
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    customer_state,
    ROUND(SUM(price), 2) AS product_value,
    ROUND(SUM(freight_value), 2) AS freight_value,

    ROUND(
        SUM(freight_value) * 100.0
        / NULLIF(SUM(price), 0),
        2
    ) AS freight_to_product_pct

FROM vw_order_item_details

WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'

GROUP BY customer_state

ORDER BY freight_to_product_pct DESC;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 18: LATE DELIVERY SEVERITY
-- Purpose: Measure how many days late delayed orders are
-- Source View: vw_order_delivery_performance
-- Grain of Source: One row per order
-- Analysis Period: January 2017 through August 2018
-- -------------------------------------------------------------------------

SELECT
    COUNT(*) AS late_orders,
    ROUND(AVG(delivery_variance_days), 2) AS avg_days_late,
    MIN(delivery_variance_days) AS minimum_days_late,
    MAX(delivery_variance_days) AS maximum_days_late

FROM vw_order_delivery_performance

WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-09-01'
  AND delivery_status = 'Late'
  AND order_delivered_customer_date IS NOT NULL;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 19: REVIEW SCORE DISTRIBUTION
-- Purpose: Show how individual review records are distributed across scores
-- Source Table: reviews
-- Grain of Output: One row per review score
-- -------------------------------------------------------------------------

SELECT
    review_score,
    COUNT(*) AS review_count,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS review_share_pct

FROM reviews

GROUP BY review_score

ORDER BY review_score;


-- -------------------------------------------------------------------------
-- BUSINESS ANALYSIS 20: CUSTOMER SPEND BAND DISTRIBUTION
-- Purpose: Segment customers into payment-value bands
-- Source View: vw_customer_lifetime_summary
-- Grain of Output: One row per spend band
-- -------------------------------------------------------------------------

SELECT
    CASE
        WHEN total_spend < 100 THEN 'Under 100'
        WHEN total_spend < 200 THEN '100-199.99'
        WHEN total_spend < 500 THEN '200-499.99'
        WHEN total_spend < 1000 THEN '500-999.99'
        ELSE '1000+'
    END AS spend_band,

    COUNT(*) AS customer_count,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(SUM(total_spend), 2) AS total_customer_spend,
    ROUND(AVG(total_spend), 2) AS avg_customer_spend

FROM vw_customer_lifetime_summary

GROUP BY
    CASE
        WHEN total_spend < 100 THEN 'Under 100'
        WHEN total_spend < 200 THEN '100-199.99'
        WHEN total_spend < 500 THEN '200-499.99'
        WHEN total_spend < 1000 THEN '500-999.99'
        ELSE '1000+'
    END

ORDER BY MIN(total_spend);
