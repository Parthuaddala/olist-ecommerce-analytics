-- Olist E-Commerce Analytics | Database Setup
-- Update /YOUR/LOCAL/PATH/ before loading files; run on a fresh schema.


CREATE DATABASE IF NOT EXISTS olist_ecommerce;
USE olist_ecommerce;

SET GLOBAL local_infile = 1;


-- 01. Geolocation

CREATE TABLE geolocation (
    geolocation_zip_code_prefix CHAR(5) PRIMARY KEY,
    geolocation_lat DOUBLE NOT NULL,
    geolocation_lng DOUBLE NOT NULL,
    geolocation_city VARCHAR(100) NOT NULL,
    geolocation_state CHAR(2) NOT NULL,
    geolocation_observation_count INT NOT NULL
);

ALTER TABLE geolocation
    CONVERT TO CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/geolocation_summary.csv'
INTO TABLE geolocation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    geolocation_observation_count
);


-- 02. Category Translation

CREATE TABLE category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100) NOT NULL
);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/category_translation_clean.csv'
INTO TABLE category_translation
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    product_category_name,
    product_category_name_english
);


-- 03. Customers
-- customer_unique_id identifies shoppers across orders.

CREATE TABLE customers (
    customer_id CHAR(32) PRIMARY KEY,
    customer_unique_id CHAR(32) NOT NULL,
    customer_zip_code_prefix CHAR(5) NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state CHAR(2) NOT NULL
);

CREATE INDEX idx_customers_unique_id
    ON customers(customer_unique_id);

CREATE INDEX idx_customers_zip
    ON customers(customer_zip_code_prefix);

CREATE INDEX idx_customers_state
    ON customers(customer_state);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/customers_clean.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
);


-- 04. Products

CREATE TABLE products (
    product_id CHAR(32) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g DOUBLE,
    product_length_cm DOUBLE,
    product_height_cm DOUBLE,
    product_width_cm DOUBLE
);

CREATE INDEX idx_products_category
    ON products(product_category_name);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/products_clean.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    product_id,
    product_category_name,
    @product_name_length,
    @product_description_length,
    @product_photos_qty,
    @product_weight_g,
    @product_length_cm,
    @product_height_cm,
    @product_width_cm
)
SET
    product_name_length = NULLIF(TRIM(@product_name_length), ''),
    product_description_length = NULLIF(TRIM(@product_description_length), ''),
    product_photos_qty = NULLIF(TRIM(@product_photos_qty), ''),
    product_weight_g = NULLIF(TRIM(@product_weight_g), ''),
    product_length_cm = NULLIF(TRIM(@product_length_cm), ''),
    product_height_cm = NULLIF(TRIM(@product_height_cm), ''),
    product_width_cm =
        NULLIF(TRIM(TRAILING '\r' FROM @product_width_cm), '');


-- 05. Sellers

CREATE TABLE sellers (
    seller_id CHAR(32) PRIMARY KEY,
    seller_zip_code_prefix CHAR(5) NOT NULL,
    seller_city VARCHAR(100) NOT NULL,
    seller_state CHAR(2) NOT NULL
);

CREATE INDEX idx_sellers_zip
    ON sellers(seller_zip_code_prefix);

CREATE INDEX idx_sellers_state
    ON sellers(seller_state);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/sellers_clean.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
);


-- 06. Orders

CREATE TABLE orders (
    order_id CHAR(32) PRIMARY KEY,
    customer_id CHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME NOT NULL,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);

CREATE INDEX idx_orders_customer
    ON orders(customer_id);

CREATE INDEX idx_orders_status
    ON orders(order_status);

CREATE INDEX idx_orders_purchase_timestamp
    ON orders(order_purchase_timestamp);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/orders_clean.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    customer_id,
    order_status,
    @order_purchase_timestamp,
    @order_approved_at,
    @order_delivered_carrier_date,
    @order_delivered_customer_date,
    @order_estimated_delivery_date
)
SET
    order_purchase_timestamp =
        NULLIF(TRIM(@order_purchase_timestamp), ''),
    order_approved_at =
        NULLIF(TRIM(@order_approved_at), ''),
    order_delivered_carrier_date =
        NULLIF(TRIM(@order_delivered_carrier_date), ''),
    order_delivered_customer_date =
        NULLIF(TRIM(@order_delivered_customer_date), ''),
    order_estimated_delivery_date =
        NULLIF(TRIM(TRAILING '\r' FROM @order_estimated_delivery_date), '');


-- 07. Order Items

CREATE TABLE order_items (
    order_id CHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    product_id CHAR(32) NOT NULL,
    seller_id CHAR(32) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    freight_value DECIMAL(10,2) NOT NULL,

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id),

    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES sellers(seller_id)
);

CREATE INDEX idx_order_items_product
    ON order_items(product_id);

CREATE INDEX idx_order_items_seller
    ON order_items(seller_id);

CREATE INDEX idx_order_items_shipping_limit
    ON order_items(shipping_limit_date);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/order_items_clean.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    @shipping_limit_date,
    @price,
    @freight_value
)
SET
    shipping_limit_date =
        NULLIF(TRIM(@shipping_limit_date), ''),
    price =
        NULLIF(TRIM(@price), ''),
    freight_value =
        NULLIF(TRIM(TRAILING '\r' FROM @freight_value), '');


-- 08. Payments

CREATE TABLE payments (
    order_id CHAR(32) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10,2) NOT NULL,

    PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);

CREATE INDEX idx_payments_type
    ON payments(payment_type);

CREATE INDEX idx_payments_value
    ON payments(payment_value);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/payments_clean.csv'
INTO TABLE payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    @payment_value
)
SET
    payment_value =
        NULLIF(TRIM(TRAILING '\r' FROM @payment_value), '');


-- 09. Reviews

CREATE TABLE reviews (
    review_id CHAR(32) NOT NULL,
    order_id CHAR(32) NOT NULL,
    review_score INT NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NULL,

    PRIMARY KEY (review_id, order_id),

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);

CREATE INDEX idx_reviews_order
    ON reviews(order_id);

CREATE INDEX idx_reviews_score
    ON reviews(review_score);

CREATE INDEX idx_reviews_creation_date
    ON reviews(review_creation_date);

LOAD DATA LOCAL INFILE
'/YOUR/LOCAL/PATH/olist-ecommerce-analytics/data/cleaned/reviews_mysql.tsv'
INTO TABLE reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY '\t'
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    review_id,
    order_id,
    review_score,
    @review_comment_title,
    @review_comment_message,
    @review_creation_date,
    @review_answer_timestamp
)
SET
    review_comment_title =
        NULLIF(TRIM(@review_comment_title), ''),
    review_comment_message =
        NULLIF(TRIM(@review_comment_message), ''),
    review_creation_date =
        NULLIF(TRIM(@review_creation_date), ''),
    review_answer_timestamp =
        NULLIF(TRIM(TRAILING '\r' FROM @review_answer_timestamp), '');


-- 10. Load Check
-- Detailed checks are in 02_data_validation.sql.

SELECT 'geolocation' AS table_name, COUNT(*) AS row_count FROM geolocation
UNION ALL
SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews;
