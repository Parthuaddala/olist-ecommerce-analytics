-- ============================================================================
-- OLIST E-COMMERCE ANALYTICS PROJECT
-- File: 02_data_validation.sql
-- Purpose: Validate row counts, keys, relationships, ranges, dates, coverage,
--          indexes, and constraints after loading the cleaned datasets
-- ============================================================================

USE olist_ecommerce;


-- ============================================================================
-- SECTION 1A: TABLE ROW COUNTS
-- Purpose: Confirm that every cleaned dataset loaded completely
-- ============================================================================

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


-- ============================================================================
-- SECTION 1B: ACTUAL VS EXPECTED ROW COUNTS
-- Purpose: Automatically flag row-count mismatches
-- ============================================================================

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


-- ============================================================================
-- SECTION 2A: SINGLE-COLUMN PRIMARY KEY UNIQUENESS
-- Purpose: Confirm that single-column primary keys contain no duplicates
-- ============================================================================

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


-- ============================================================================
-- SECTION 2B: COMPOSITE KEY UNIQUENESS
-- Purpose: Confirm that multi-column primary keys contain no duplicates
-- ============================================================================

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


-- ============================================================================
-- SECTION 3A: FOREIGN-KEY RELATIONSHIP VALIDATION
-- Purpose: Confirm that child-table IDs match parent-table IDs
-- ============================================================================

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


-- ============================================================================
-- SECTION 3B: PARENT RECORDS WITHOUT CHILD RECORDS
-- Purpose: Document optional relationship gaps
-- Known findings: 775 orders without items, 1 without payment, 768 without reviews
-- ============================================================================

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


-- ============================================================================
-- SECTION 4A: MISSING VALUE CHECKS
-- Purpose: Profile important nullable columns
-- ============================================================================

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


-- ============================================================================
-- SECTION 4B: VALID RANGE CHECKS
-- Purpose: Detect impossible or invalid numeric values
-- ============================================================================

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


-- ============================================================================
-- SECTION 4C: DATE-SEQUENCE CHECKS
-- Purpose: Detect logically inconsistent event dates
-- ============================================================================

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


-- ============================================================================
-- SECTION 4D: DELIVERED ORDERS WITH MISSING ACTUAL DELIVERY DATE
-- Purpose: Identify delivered-status records that cannot be used in timeliness rates
-- ============================================================================

SELECT
    COUNT(*) AS delivered_orders_missing_actual_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;


-- ============================================================================
-- SECTION 5A: CATEGORY TRANSLATION COVERAGE
-- Purpose: Identify categories without an English translation
-- Note: The 'unknown' product category is expected to have no translation row.
-- ============================================================================

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


-- ============================================================================
-- SECTION 5B: CUSTOMER GEOLOCATION COVERAGE
-- Purpose: Count customers whose ZIP prefix has no map coordinate
-- ============================================================================

SELECT
    COUNT(*) AS customers_without_geolocation
FROM customers AS c
LEFT JOIN geolocation AS g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;


-- ============================================================================
-- SECTION 5C: SELLER GEOLOCATION COVERAGE
-- Purpose: Count sellers whose ZIP prefix has no map coordinate
-- ============================================================================

SELECT
    COUNT(*) AS sellers_without_geolocation
FROM sellers AS s
LEFT JOIN geolocation AS g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;


-- ============================================================================
-- SECTION 5D: GEOGRAPHIC COORDINATE RANGE CHECK
-- Purpose: Identify coordinates outside approximate Brazil bounds
-- Note: A small number of outliers are retained rather than deleted.
-- ============================================================================

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


-- ============================================================================
-- SECTION 6A: INDEX AUDIT
-- Purpose: Confirm that primary-key and analytical indexes exist
-- ============================================================================

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


-- ============================================================================
-- SECTION 6B: FOREIGN-KEY CONSTRAINT AUDIT
-- Purpose: Confirm that database relationships are enforced
-- ============================================================================

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


-- ============================================================================
-- SECTION 6C: OVERALL CONSTRAINT AUDIT
-- Purpose: Review primary-key, unique, and foreign-key constraints
-- ============================================================================

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
