
-- ==================================================
-- Olist 电商订单分析项目
-- 02 数据验证
-- 功能：检查原始数据、关联质量和金额一致性
-- ==================================================

USE olist_project;


-- ==================================================
-- 1. 检查三张原始表的行数
-- ==================================================

SELECT COUNT(*) AS order_count
FROM orders;

SELECT COUNT(*) AS item_count
FROM order_items;

SELECT COUNT(*) AS customer_count
FROM customers;


-- ==================================================
-- 2. 查看原始表结构
-- ==================================================

DESCRIBE orders;
DESCRIBE order_items;
DESCRIBE customers;


-- ==================================================
-- 3. 验证商品明细聚合
-- ==================================================

-- 原始商品明细总行数：112650
-- 包含商品明细的不同订单数：98666

SELECT
    COUNT(*) AS original_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM order_items;

-- 聚合后，每笔有明细的订单应该只有一行。

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM order_items_agg;


-- ==================================================
-- 4. 检查没有商品明细的订单
-- ==================================================

-- 使用 LEFT JOIN 保留全部订单。
-- 如果右表的 order_id 为 NULL，
-- 说明这笔订单没有匹配到商品明细。

SELECT
    COUNT(*) AS unmatched_orders
FROM orders AS o
LEFT JOIN order_items_agg AS i
    ON o.order_id = i.order_id
WHERE i.order_id IS NULL;


-- 检查这些未匹配订单的状态分布。

SELECT
    o.order_status AS status,
    COUNT(*) AS order_count
FROM orders AS o
LEFT JOIN order_items_agg AS i
    ON o.order_id = i.order_id
WHERE i.order_id IS NULL
GROUP BY o.order_status
ORDER BY order_count DESC;


-- ==================================================
-- 5. 验证三表关联结果
-- ==================================================

-- 总行数和不同订单数应该都是 99441。

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM orders_full;


-- 检查没有商品明细的订单，预计为 775。

SELECT
    COUNT(*) AS unmatched_orders
FROM orders_full
WHERE items_count IS NULL;


-- 检查关联后客户信息是否缺失。

SELECT
    SUM(customer_city IS NULL) AS missing_city,
    SUM(customer_state IS NULL) AS missing_state
FROM orders_full;


-- ==================================================
-- 6. 金额核对
-- ==================================================

-- 原始商品明细的金额总和。

SELECT
    ROUND(SUM(price), 2) AS raw_product_amount,
    ROUND(SUM(freight_value), 2) AS raw_freight_amount
FROM order_items;


-- 三表关联后的金额总和。
-- 金额保留两位小数，以减少 DOUBLE 浮点误差的影响。

SELECT
    ROUND(SUM(product_amount), 2) AS merged_product_amount,
    ROUND(SUM(freight_amount), 2) AS merged_freight_amount
FROM orders_full;


-- ==================================================
-- 7. 检查日期转换结果
-- ==================================================

DESCRIBE orders_full_typed;

SELECT
    order_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_customer_date
FROM orders_full_typed
LIMIT 10;
