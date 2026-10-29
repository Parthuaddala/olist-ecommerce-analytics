-- Olist E-Commerce Analytics | Tableau Exports
-- Period: Jan 2017 - Aug 2018 | MySQL 8+
-- Run SQL scripts 01-05 before exporting.
-- Report year 0 = All Years; 2017 and 2018 use purchase year unless noted.

USE olist_ecommerce;


-- 01. Overview - Orders | Overview_orders.csv
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


-- 02. Overview - Payment Methods | payment_method_mix_by_year.csv
-- Orders may use more than one payment method; method counts are not additive.
SELECT
    YEAR(o.order_purchase_timestamp) AS purchase_year,
    p.payment_type,

    COUNT(*) AS payment_records,

    COUNT(DISTINCT p.order_id)
        AS orders_using_payment_type,

    ROUND(SUM(p.payment_value), 2)
        AS total_payment_value,

    ROUND(AVG(p.payment_value), 2)
        AS avg_payment_value,

    ROUND(AVG(p.payment_installments), 2)
        AS avg_installments

FROM payments AS p

INNER JOIN orders AS o
    ON p.order_id = o.order_id

WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'

GROUP BY
    YEAR(o.order_purchase_timestamp),
    p.payment_type

ORDER BY
    purchase_year,
    total_payment_value DESC;


-- 03. Delivery - State Performance | delivery_state_performance.csv
-- Includes delivered orders with usable delivery dates.
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


-- 04. Delivery - Review Analysis | delivery_review_analysis.csv
-- Includes delivered orders with reviews and delivery dates.
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


-- 05. Delivery - Dispatch & Transit | dispatch_carrier_analysis.csv
-- Dispatch: approval to carrier. Transit: carrier to customer.
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


-- 06. Sellers - Risk Performance | seller_risk_matrix_by_year.csv
-- Seller eligibility: at least 30 delivered orders per reporting period.
WITH seller_orders AS (
    SELECT
        seller_id,
        seller_city,
        seller_state,
        order_id,
        order_purchase_timestamp,
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
        order_id,
        order_purchase_timestamp
),

seller_order_metrics AS (
    SELECT
        so.seller_id,
        so.seller_city,
        so.seller_state,
        so.order_id,
        so.order_purchase_timestamp,
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

reporting_periods AS (
    SELECT 0 AS report_year
    UNION ALL
    SELECT 2017
    UNION ALL
    SELECT 2018
),

periodized_seller_orders AS (
    SELECT
        p.report_year,
        m.*
    FROM seller_order_metrics AS m
    INNER JOIN reporting_periods AS p
        ON p.report_year = 0
        OR YEAR(m.order_purchase_timestamp) = p.report_year
),

seller_performance AS (
    SELECT
        report_year,
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
    FROM periodized_seller_orders
    GROUP BY
        report_year,
        seller_id,
        seller_city,
        seller_state
)

SELECT
    report_year,
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
ORDER BY
    report_year,
    late_delivery_rate_pct DESC,
    seller_id;


-- 07. Products - Category Performance | category_review_analysis_by_year.csv
-- Only reviewed delivered orders; order reviews may be shared across categories.
WITH order_categories AS (
    SELECT
        order_id,
        YEAR(order_purchase_timestamp) AS purchase_year,
        product_category_name_english AS product_category,
        COUNT(*) AS items_in_category,
        ROUND(SUM(price), 2) AS category_product_value
    FROM vw_order_item_details
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp < '2018-09-01'
    GROUP BY
        order_id,
        YEAR(order_purchase_timestamp),
        product_category_name_english
),

category_review_orders AS (
    SELECT
        oc.order_id,
        oc.purchase_year,
        oc.product_category,
        oc.items_in_category,
        oc.category_product_value,
        r.avg_review_score
    FROM order_categories AS oc
    INNER JOIN vw_order_review_summary AS r
        ON oc.order_id = r.order_id
    WHERE r.has_review = 1
),

reporting_periods AS (
    SELECT 0 AS report_year
    UNION ALL
    SELECT 2017
    UNION ALL
    SELECT 2018
),

periodized_categories AS (
    SELECT
        p.report_year,
        c.order_id,
        c.product_category,
        c.items_in_category,
        c.category_product_value,
        c.avg_review_score
    FROM category_review_orders AS c
    INNER JOIN reporting_periods AS p
        ON p.report_year = 0
        OR p.report_year = c.purchase_year
)

SELECT
    report_year,
    product_category,
    COUNT(DISTINCT order_id) AS reviewed_orders,
    SUM(items_in_category) AS items_sold,
    ROUND(SUM(category_product_value), 2) AS product_value,
    ROUND(AVG(avg_review_score), 2) AS avg_review_score
FROM periodized_categories
GROUP BY
    report_year,
    product_category
HAVING COUNT(DISTINCT order_id) >= 30
ORDER BY
    report_year,
    product_value DESC,
    product_category;


-- 08. Customers - RFM Snapshots | rfm_customers_by_year.csv
-- 2017 snapshot: 2018-01-01; 2018/All Years: 2018-09-01.
WITH reporting_periods AS (
    SELECT
        0 AS report_year,
        CAST('2018-09-01' AS DATE) AS snapshot_date
    UNION ALL
    SELECT
        2017,
        CAST('2018-01-01' AS DATE)
    UNION ALL
    SELECT
        2018,
        CAST('2018-09-01' AS DATE)
),

customer_orders AS (
    SELECT
        p.report_year,
        p.snapshot_date,
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        ofi.payment_total
    FROM reporting_periods AS p
  INNER JOIN orders AS o
    ON o.order_status = 'delivered'
   AND o.order_purchase_timestamp < p.snapshot_date
   AND o.order_delivered_customer_date IS NOT NULL
   AND o.order_delivered_customer_date < p.snapshot_date
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    LEFT JOIN vw_order_financials AS ofi
        ON o.order_id = ofi.order_id
),

customer_metrics AS (
    SELECT
        report_year,
        snapshot_date,
        customer_unique_id,
        COUNT(DISTINCT order_id) AS frequency,
        ROUND(SUM(payment_total), 2) AS monetary_value,
        MIN(order_purchase_timestamp) AS first_purchase_date,
        MAX(order_purchase_timestamp) AS last_purchase_date,
        DATEDIFF(
            snapshot_date,
            DATE(MAX(order_purchase_timestamp))
        ) AS recency_days
    FROM customer_orders
    GROUP BY
        report_year,
        snapshot_date,
        customer_unique_id
),

rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (
            PARTITION BY report_year
            ORDER BY recency_days DESC, customer_unique_id
        ) AS r_score,

        CASE
            WHEN frequency = 1 THEN 1
            WHEN frequency = 2 THEN 2
            WHEN frequency = 3 THEN 3
            WHEN frequency BETWEEN 4 AND 5 THEN 4
            ELSE 5
        END AS f_score,

        NTILE(5) OVER (
            PARTITION BY report_year
            ORDER BY monetary_value, customer_unique_id
        ) AS m_score
    FROM customer_metrics
),

rfm_segmented AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4
             AND f_score >= 4
             AND m_score >= 4
                THEN 'Champions'

            WHEN r_score >= 3
             AND f_score >= 2
             AND m_score >= 3
                THEN 'Loyal Customers'

            WHEN r_score >= 4
             AND f_score = 1
             AND m_score >= 3
                THEN 'Potential Loyalists'

            WHEN r_score = 5
             AND f_score = 1
             AND m_score <= 2
                THEN 'Recent Customers'

            WHEN r_score <= 2
             AND f_score >= 2
                THEN 'At Risk'

            WHEN r_score <= 2
             AND f_score = 1
                THEN 'Hibernating'

            ELSE 'Others'
        END AS rfm_segment
    FROM rfm_scores
)

SELECT
    report_year,
    snapshot_date,
    customer_unique_id,
    frequency,
    monetary_value,
    first_purchase_date,
    last_purchase_date,
    recency_days,
    r_score,
    f_score,
    m_score,
    rfm_segment,
    CASE
        WHEN frequency > 1 THEN 1
        ELSE 0
    END AS repeat_customer_flag
FROM rfm_segmented
ORDER BY
    report_year,
    customer_unique_id;


-- 09. Customers - Cohort Retention | cohort_retention_by_year.csv
-- Unobserved months are excluded; observed inactive months are zero.
WITH RECURSIVE month_numbers AS (
    SELECT
        0 AS months_since_cohort

    UNION ALL

    SELECT
        months_since_cohort + 1
    FROM month_numbers
    WHERE months_since_cohort < 19
),

customer_orders AS (
    SELECT
        c.customer_unique_id,
        CAST(
            DATE_FORMAT(
                o.order_purchase_timestamp,
                '%Y-%m-01'
            ) AS DATE
        ) AS order_month
    FROM orders AS o
    INNER JOIN customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp < '2018-09-01'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_customer_date < '2018-09-01'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_orders
    GROUP BY
        customer_unique_id
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
    GROUP BY
        cohort_month
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
    COALESCE(
        cc.active_customers,
        0
    ) AS active_customers,
    cg.cohort_size,
    ROUND(
        COALESCE(cc.active_customers, 0) * 100.0
        / cg.cohort_size,
        2
    ) AS retention_rate_pct
FROM cohort_grid AS cg
LEFT JOIN cohort_counts AS cc
    ON cg.cohort_month = cc.cohort_month
   AND cg.months_since_cohort = cc.months_since_cohort
ORDER BY
    cg.cohort_month,
    cg.months_since_cohort;
