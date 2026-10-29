-- Olist E-Commerce Analytics | Reusable MySQL views
USE olist_ecommerce;


-- 01. Order Item Details | One row per order item
CREATE OR REPLACE VIEW vw_order_item_details AS

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS item_total_value,

    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.customer_zip_code_prefix,

    p.product_category_name,

    COALESCE(
        ct.product_category_name_english,
        'Unknown'
    ) AS product_category_name_english,

    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    s.seller_city,
    s.seller_state,
    s.seller_zip_code_prefix

FROM order_items AS oi

INNER JOIN orders AS o
    ON oi.order_id = o.order_id

INNER JOIN customers AS c
    ON o.customer_id = c.customer_id

INNER JOIN products AS p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name

INNER JOIN sellers AS s
    ON oi.seller_id = s.seller_id;


-- 02. Order Financials | One row per order
-- Summarizes items and payments separately to avoid double counting.
CREATE OR REPLACE VIEW vw_order_financials AS

WITH item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(DISTINCT product_id) AS distinct_product_count,
        SUM(price) AS product_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS item_total_value
    FROM order_items
    GROUP BY order_id
),

payment_summary AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        SUM(payment_value) AS payment_total
    FROM payments
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,

    COALESCE(i.item_count, 0) AS item_count,
    COALESCE(i.distinct_product_count, 0) AS distinct_product_count,
    COALESCE(i.product_value, 0) AS product_value,
    COALESCE(i.freight_value, 0) AS freight_value,
    COALESCE(i.item_total_value, 0) AS item_total_value,

    COALESCE(p.payment_record_count, 0) AS payment_record_count,
    COALESCE(p.payment_total, 0) AS payment_total

FROM orders AS o

LEFT JOIN item_summary AS i
    ON o.order_id = i.order_id

LEFT JOIN payment_summary AS p
    ON o.order_id = p.order_id;


-- 03. Delivery Performance | One row per order
-- Delivery duration uses full days; lateness uses calendar dates.
CREATE OR REPLACE VIEW vw_order_delivery_performance AS

SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    TIMESTAMPDIFF(
        HOUR,
        o.order_purchase_timestamp,
        o.order_approved_at
    ) AS approval_hours,

    TIMESTAMPDIFF(
        DAY,
        o.order_approved_at,
        o.order_delivered_carrier_date
    ) AS carrier_handoff_days,

    TIMESTAMPDIFF(
        DAY,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date
    ) AS delivery_days,

    TIMESTAMPDIFF(
        DAY,
        o.order_purchase_timestamp,
        o.order_estimated_delivery_date
    ) AS estimated_delivery_days,

    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    ) AS delivery_variance_days,

    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN 'Not Delivered'
        WHEN DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) <= 0
            THEN 'Early/On Time'
        ELSE 'Late'
    END AS delivery_status

FROM orders AS o;


-- 04. Review Summary | One row per order
CREATE OR REPLACE VIEW vw_order_review_summary AS

WITH review_summary AS (
    SELECT
        order_id,
        COUNT(*) AS review_count,
        AVG(review_score) AS avg_review_score,
        MIN(review_score) AS min_review_score,
        MAX(review_score) AS max_review_score,
        MIN(review_creation_date) AS first_review_date,
        MAX(review_creation_date) AS last_review_date,
        MIN(review_answer_timestamp) AS first_review_answer_timestamp,
        MAX(review_answer_timestamp) AS last_review_answer_timestamp
    FROM reviews
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,

    COALESCE(rs.review_count, 0) AS review_count,
    rs.avg_review_score,
    rs.min_review_score,
    rs.max_review_score,
    rs.first_review_date,
    rs.last_review_date,
    rs.first_review_answer_timestamp,
    rs.last_review_answer_timestamp,

    CASE
        WHEN rs.review_count IS NULL THEN 0
        ELSE 1
    END AS has_review,

    CASE
        WHEN rs.review_count > 1 THEN 1
        ELSE 0
    END AS has_multiple_reviews

FROM orders AS o

LEFT JOIN review_summary AS rs
    ON o.order_id = rs.order_id;


-- 05. Customer Lifetime Summary | One row per customer
-- Delivered purchases through August 2018.
CREATE OR REPLACE VIEW vw_customer_lifetime_summary AS

WITH customer_orders AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ofi.payment_total
    FROM orders AS o
    JOIN customers AS c
        ON o.customer_id = c.customer_id
    LEFT JOIN vw_order_financials AS ofi
        ON o.order_id = ofi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp < '2018-09-01'
)

SELECT
    customer_unique_id,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_total), 2) AS total_spend,
    ROUND(AVG(payment_total), 2) AS avg_order_value,
    MIN(order_purchase_timestamp) AS first_purchase_date,
    MAX(order_purchase_timestamp) AS last_purchase_date,

    DATEDIFF(
        '2018-09-01',
        DATE(MAX(order_purchase_timestamp))
    ) AS recency_days,

    DATEDIFF(
        DATE(MAX(order_purchase_timestamp)),
        DATE(MIN(order_purchase_timestamp))
    ) AS customer_tenure_days,

    CASE
        WHEN COUNT(DISTINCT order_id) > 1 THEN 1
        ELSE 0
    END AS repeat_customer_flag

FROM customer_orders

GROUP BY customer_unique_id;


-- 06. Seller Lifetime Summary | One row per seller
-- Uses all delivered orders; not limited to the reporting period.
CREATE OR REPLACE VIEW vw_seller_lifetime_summary AS

WITH seller_metrics AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(*) AS total_items_sold,
        COUNT(DISTINCT product_id) AS distinct_products_sold,
        ROUND(SUM(price), 2) AS total_product_revenue,
        ROUND(SUM(freight_value), 2) AS total_freight_value,
        ROUND(SUM(item_total_value), 2) AS total_item_value,
        ROUND(AVG(price), 2) AS avg_item_price,
        MIN(order_purchase_timestamp) AS first_sale_date,
        MAX(order_purchase_timestamp) AS last_sale_date
    FROM vw_order_item_details
    WHERE order_status = 'delivered'
    GROUP BY seller_id
)

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    s.seller_zip_code_prefix,

    COALESCE(sm.total_orders, 0) AS total_orders,
    COALESCE(sm.total_items_sold, 0) AS total_items_sold,
    COALESCE(sm.distinct_products_sold, 0) AS distinct_products_sold,
    COALESCE(sm.total_product_revenue, 0) AS total_product_revenue,
    COALESCE(sm.total_freight_value, 0) AS total_freight_value,
    COALESCE(sm.total_item_value, 0) AS total_item_value,

    sm.avg_item_price,
    sm.first_sale_date,
    sm.last_sale_date,

    DATEDIFF(
        DATE(sm.last_sale_date),
        DATE(sm.first_sale_date)
    ) AS seller_active_days

FROM sellers AS s

LEFT JOIN seller_metrics AS sm
    ON s.seller_id = sm.seller_id;







USE olist_ecommerce;

-- 07. First Delivery & 90-Day Repeat | One row per customer
-- Requires 90-day follow-up; results show association, not causation.
CREATE OR REPLACE VIEW
vw_first_delivery_repeat_90d AS

WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,

        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY
                o.order_purchase_timestamp,
                o.order_id
        ) AS order_rank

    FROM orders AS o

    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp < '2018-09-01'
),

first_orders AS (
    SELECT
        customer_unique_id,
        order_id AS first_order_id,
        order_purchase_timestamp AS first_purchase_date,
        order_delivered_customer_date AS first_delivery_date,

        DATE_FORMAT(
            order_purchase_timestamp,
            '%Y-%m'
        ) AS first_purchase_month,

        CASE
            WHEN DATEDIFF(
                order_delivered_customer_date,
                order_estimated_delivery_date
            ) > 0 THEN 'Late'
            ELSE 'On Time / Early'
        END AS first_delivery_status

    FROM ranked_orders

    WHERE order_rank = 1
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date >=
          order_purchase_timestamp
      AND order_delivered_customer_date <=
          DATE_SUB('2018-09-01', INTERVAL 90 DAY)
)

SELECT
    f.customer_unique_id,
    f.first_order_id,
    f.first_purchase_date,
    f.first_delivery_date,
    f.first_purchase_month,
    f.first_delivery_status,

    CASE
        WHEN EXISTS (
            SELECT 1
            FROM orders AS o2

            INNER JOIN customers AS c2
                ON o2.customer_id = c2.customer_id

            WHERE c2.customer_unique_id =
                  f.customer_unique_id
              AND o2.order_id <> f.first_order_id
              AND o2.order_status = 'delivered'
              AND o2.order_purchase_timestamp >
                  f.first_delivery_date
              AND o2.order_purchase_timestamp <=
                  DATE_ADD(
                      f.first_delivery_date,
                      INTERVAL 90 DAY
                  )
              AND o2.order_purchase_timestamp <
                  '2018-09-01'
        )
        THEN 1
        ELSE 0
    END AS repeated_within_90_days

FROM first_orders AS f;
