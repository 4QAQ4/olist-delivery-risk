
-- ==================================================
-- Olist 电商订单分析项目
-- 01 数据准备
-- 功能：创建订单级视图，并生成配送延迟标签
-- ==================================================

-- 1. 创建并选择数据库
CREATE DATABASE IF NOT EXISTS olist_project
DEFAULT CHARACTER SET utf8mb4;

USE olist_project;

-- 注意：
-- 以下代码依赖已经通过 Workbench 导入的三张原始表：
-- orders、order_items、customers


-- ==================================================
-- 2. 商品明细聚合
-- ==================================================

-- order_items 中一笔订单可能对应多条商品明细。
-- 因此先按 order_id 聚合，保证每笔订单只有一行。

CREATE OR REPLACE VIEW order_items_agg AS
SELECT
    order_id,
    COUNT(*) AS items_count,
    SUM(price) AS product_amount,
    SUM(freight_value) AS freight_amount,
    SUM(price) + SUM(freight_value) AS total_amount
FROM order_items
GROUP BY order_id;


-- ==================================================
-- 3. 三表关联
-- ==================================================

-- 以 orders 为主表，使用 LEFT JOIN 保留全部订单。
-- 商品聚合表按照 order_id 关联。
-- 客户表按照 customer_id 关联。
-- 最终得到 16 个字段。

CREATE OR REPLACE VIEW orders_full AS
SELECT
    -- 订单信息（8列）
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- 商品聚合信息（4列）
    oia.items_count,
    oia.product_amount,
    oia.freight_amount,
    oia.total_amount,

    -- 客户信息（4列）
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state

FROM orders AS o
LEFT JOIN order_items_agg AS oia
    ON o.order_id = oia.order_id
LEFT JOIN customers AS c
    ON o.customer_id = c.customer_id;


-- ==================================================
-- 4. 日期类型转换
-- ==================================================

-- 原始 CSV 导入后，部分日期字段为 TEXT 类型。
-- NULLIF(字段, '') 将空字符串转换为 NULL。
-- STR_TO_DATE() 将文本转换为日期时间类型。
-- 保留原字段名称，方便与 Pandas 结果对比。

CREATE OR REPLACE VIEW orders_full_typed AS
SELECT
    order_id,
    customer_id,
    order_status,

    STR_TO_DATE(
        NULLIF(order_purchase_timestamp, ''),
        '%Y-%m-%d %H:%i:%s'
    ) AS order_purchase_timestamp,

    STR_TO_DATE(
        NULLIF(order_approved_at, ''),
        '%Y-%m-%d %H:%i:%s'
    ) AS order_approved_at,

    STR_TO_DATE(
        NULLIF(order_delivered_carrier_date, ''),
        '%Y-%m-%d %H:%i:%s'
    ) AS order_delivered_carrier_date,

    STR_TO_DATE(
        NULLIF(order_delivered_customer_date, ''),
        '%Y-%m-%d %H:%i:%s'
    ) AS order_delivered_customer_date,

    STR_TO_DATE(
        NULLIF(order_estimated_delivery_date, ''),
        '%Y-%m-%d %H:%i:%s'
    ) AS order_estimated_delivery_date,

    items_count,
    product_amount,
    freight_amount,
    total_amount,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state

FROM orders_full;


-- ==================================================
-- 5. 创建延迟订单视图
-- ==================================================

-- 第一版延迟分析只考虑：
-- 1. 已送达的订单
-- 2. 具有有效获批时间
-- 3. 实际送达时间不缺失
-- 4. 预计送达时间不缺失
--
-- 使用 DATE() 仅比较年月日，忽略时分秒。
-- 实际送达日期晚于预计日期，is_delayed = 1。
-- 否则 is_delayed = 0。

CREATE OR REPLACE VIEW delay_orders AS
SELECT
    *,
    CASE
        WHEN DATE(order_delivered_customer_date)
             > DATE(order_estimated_delivery_date)
        THEN 1
        ELSE 0
    END AS is_delayed

FROM orders_full_typed
WHERE order_status = 'delivered'
    AND order_approved_at IS NOT NULL
    AND order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL;
