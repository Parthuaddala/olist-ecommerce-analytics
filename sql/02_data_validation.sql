-- Olist E-Commerce Analytics | Data Validation


USE olist_ecommerce;


-- 01. Table Row Counts

SELECT 'geolocation' AS table_name, COUNT(*) AS row_count
FROM geolocation

UNION ALL
SELECT 'category_translation', COUNT(*)
FROM category_translation

UNION ALL
SELECT 'customers', COUNT(*)
FROM customers

UNION ALL
SELECT 'products', COUNT(*)
FROM products

UNION ALL
SELECT 'sellers', COUNT(*)
FROM sellers

UNION ALL
SELECT 'orders', COUNT(*)
FROM orders

UNION ALL
SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL
SELECT 'payments', COUNT(*)
FROM payments

UNION ALL
SELECT 'reviews', COUNT(*)
FROM reviews;


-- 02. Expected Row Counts

WITH actual_counts AS (
    SELECT 'geolocation' AS table_name, COUNT(*) AS actual_rows
    FROM geolocation

    UNION ALL
    SELECT 'category_translation', COUNT(*)
    FROM category_translation

    UNION ALL
    SELECT 'customers', COUNT(*)
    FROM customers

    UNION ALL
    SELECT 'products', COUNT(*)
    FROM products

    UNION ALL
    SELECT 'sellers', COUNT(*)
    FROM sellers

    UNION ALL
    SELECT 'orders', COUNT(*)
    FROM orders

    UNION ALL
    SELECT 'order_items', COUNT(*)
    FROM order_items

    UNION ALL
    SELECT 'payments', COUNT(*)
    FROM payments

    UNION ALL
    SELECT 'reviews', COUNT(*)
    FROM reviews
),

expected_counts AS (
    SELECT 'geolocation' AS table_name, 19015 AS expected_rows
    UNION ALL SELECT 'category_translation', 73
    UNION ALL SELECT 'customers', 99441
    UNION ALL SELECT 'products', 32951
    UNION ALL SELECT 'sellers', 3095
    UNION ALL SELECT 'orders', 99441
    UNION ALL SELECT 'order_items', 112650
    UNION ALL SELECT 'payments', 103886
    UNION ALL SELECT 'reviews', 99224
)

SELECT
    a.table_name,
    a.actual_rows,
    e.expected_rows,
    a.actual_rows - e.expected_rows AS row_difference,
    CASE
        WHEN a.actual_rows = e.expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status
FROM actual_counts AS a
JOIN expected_counts AS e
    ON a.table_name = e.table_name
ORDER BY a.table_name;


-- 03. Primary Key Uniqueness

SELECT
    'geolocation' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_key_values,
    COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix) AS duplicate_count
FROM geolocation

UNION ALL
SELECT
    'category_translation',
    COUNT(*),
    COUNT(DISTINCT product_category_name),
    COUNT(*) - COUNT(DISTINCT product_category_name)
FROM category_translation

UNION ALL
SELECT
    'customers',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    COUNT(*) - COUNT(DISTINCT customer_id)
FROM customers

UNION ALL
SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id)
FROM products

UNION ALL
SELECT
    'sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id),
    COUNT(*) - COUNT(DISTINCT seller_id)
FROM sellers

UNION ALL
SELECT
    'orders',
    COUNT(*),
    COUNT(DISTINCT order_id),
    COUNT(*) - COUNT(DISTINCT order_id)
FROM orders;


-- 04. Composite Key Uniqueness

SELECT
    'order_items' AS table_name,
    COUNT(*) AS duplicate_key_groups
FROM (
    SELECT
        order_id,
        order_item_id
    FROM order_items
    GROUP BY
        order_id,
        order_item_id
    HAVING COUNT(*) > 1
) AS order_item_duplicates

UNION ALL
SELECT
    'payments',
    COUNT(*)
FROM (
    SELECT
        order_id,
        payment_sequential
    FROM payments
    GROUP BY
        order_id,
        payment_sequential
    HAVING COUNT(*) > 1
) AS payment_duplicates

UNION ALL
SELECT
    'reviews',
    COUNT(*)
FROM (
    SELECT
        review_id,
        order_id
    FROM reviews
    GROUP BY
        review_id,
        order_id
    HAVING COUNT(*) > 1
) AS review_duplicates;


-- 05. Foreign Key Relationships

SELECT
    'orders.customer_id -> customers.customer_id' AS relationship_name,
    COUNT(*) AS unmatched_rows
FROM orders AS o
LEFT JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL
SELECT
    'order_items.order_id -> orders.order_id',
    COUNT(*)
FROM order_items AS oi
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT
    'order_items.product_id -> products.product_id',
    COUNT(*)
FROM order_items AS oi
LEFT JOIN products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL
SELECT
    'order_items.seller_id -> sellers.seller_id',
    COUNT(*)
FROM order_items AS oi
LEFT JOIN sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL

UNION ALL
SELECT
    'payments.order_id -> orders.order_id',
    COUNT(*)
FROM payments AS p
LEFT JOIN orders AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL
SELECT
    'reviews.order_id -> orders.order_id',
    COUNT(*)
FROM reviews AS r
LEFT JOIN orders AS o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 06. Missing Child Records
-- Missing item, payment, or review records may be legitimate.

SELECT
    'orders_without_items' AS validation_check,
    COUNT(*) AS row_count
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL

UNION ALL
SELECT
    'orders_without_payments',
    COUNT(*)
FROM orders AS o
LEFT JOIN payments AS p
    ON o.order_id = p.order_id
WHERE p.order_id IS NULL

UNION ALL
SELECT
    'orders_without_reviews',
    COUNT(*)
FROM orders AS o
LEFT JOIN reviews AS r
    ON o.order_id = r.order_id
WHERE r.order_id IS NULL;


-- 07. Missing Values

SELECT
    'products' AS table_name,
    SUM(product_category_name IS NULL) AS missing_category,
    SUM(product_name_length IS NULL) AS missing_name_length,
    SUM(product_description_length IS NULL) AS missing_description_length,
    SUM(product_photos_qty IS NULL) AS missing_photo_qty,
    SUM(product_weight_g IS NULL) AS missing_weight,
    SUM(product_length_cm IS NULL) AS missing_length,
    SUM(product_height_cm IS NULL) AS missing_height,
    SUM(product_width_cm IS NULL) AS missing_width
FROM products;

SELECT
    'orders' AS table_name,
    SUM(order_approved_at IS NULL) AS missing_approved_at,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery
FROM orders;

SELECT
    'reviews' AS table_name,
    SUM(review_comment_title IS NULL) AS missing_titles,
    SUM(review_comment_message IS NULL) AS missing_messages,
    SUM(review_answer_timestamp IS NULL) AS missing_answer_timestamps
FROM reviews;


-- 08. Numeric Range Checks

SELECT
    SUM(price <= 0) AS invalid_prices,
    SUM(freight_value < 0) AS negative_freight
FROM order_items;

SELECT
    SUM(payment_value < 0) AS negative_payments,
    SUM(payment_installments < 0) AS negative_installments
FROM payments;

SELECT
    COUNT(*) AS invalid_review_scores
FROM reviews
WHERE review_score NOT BETWEEN 1 AND 5;

SELECT
    SUM(product_weight_g < 0) AS negative_weights,
    SUM(product_length_cm <= 0) AS invalid_lengths,
    SUM(product_height_cm <= 0) AS invalid_heights,
    SUM(product_width_cm <= 0) AS invalid_widths
FROM products;


-- 09. Date Sequence Checks

SELECT
    SUM(order_approved_at < order_purchase_timestamp)
        AS approved_before_purchase,
    SUM(order_delivered_carrier_date < order_purchase_timestamp)
        AS carrier_before_purchase,
    SUM(order_delivered_customer_date < order_purchase_timestamp)
        AS delivered_before_purchase,
    SUM(order_delivered_customer_date < order_delivered_carrier_date)
        AS customer_delivery_before_carrier
FROM orders;


-- 10. Missing Delivery Dates

SELECT
    COUNT(*) AS delivered_orders_missing_actual_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;


-- 11. Category Translation Coverage
-- The unknown category may have no English translation.

SELECT DISTINCT
    p.product_category_name
FROM products AS p
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name
WHERE ct.product_category_name IS NULL
ORDER BY p.product_category_name;

SELECT
    COUNT(*) AS products_without_translation
FROM products AS p
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name
WHERE ct.product_category_name IS NULL;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS unique_portuguese_categories,
    COUNT(DISTINCT product_category_name_english) AS unique_english_categories
FROM category_translation;


-- 12. Customer Geolocation Coverage

SELECT
    COUNT(*) AS customers_without_geolocation
FROM customers AS c
LEFT JOIN geolocation AS g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;


-- 13. Seller Geolocation Coverage

SELECT
    COUNT(*) AS sellers_without_geolocation
FROM sellers AS s
LEFT JOIN geolocation AS g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;


-- 14. Coordinate Outliers
-- Outliers are reported, not removed.

SELECT
    COUNT(*) AS geographic_outliers
FROM geolocation
WHERE geolocation_lat NOT BETWEEN -35 AND 6
   OR geolocation_lng NOT BETWEEN -75 AND -30;

SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    geolocation_observation_count
FROM geolocation
WHERE geolocation_lat NOT BETWEEN -35 AND 6
   OR geolocation_lng NOT BETWEEN -75 AND -30
ORDER BY geolocation_zip_code_prefix;


-- 15. Index Audit

SELECT
    table_name,
    index_name,
    column_name,
    non_unique,
    seq_in_index
FROM information_schema.statistics
WHERE table_schema = 'olist_ecommerce'
ORDER BY
    table_name,
    index_name,
    seq_in_index;


-- 16. Foreign Key Audit

SELECT
    table_name,
    constraint_name,
    column_name,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'olist_ecommerce'
  AND referenced_table_name IS NOT NULL
ORDER BY
    table_name,
    constraint_name;


-- 17. Constraint Audit

SELECT
    table_name,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'olist_ecommerce'
ORDER BY
    table_name,
    constraint_type,
    constraint_name;
