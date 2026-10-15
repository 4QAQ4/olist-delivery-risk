
-- ==================================================
-- Olist 电商订单分析项目
-- 03 订单分析
-- 功能：分析平台月度订单量
-- ==================================================

USE olist_project;


-- ==================================================
-- 1. 按下单月份统计订单数量
-- ==================================================

-- DATE_FORMAT() 从订单下单时间提取年月。
-- GROUP BY 将相同月份的订单分为一组。
-- COUNT(*) 统计每组的订单数量。
-- ORDER BY 按月份升序排列。

SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(*) AS order_count
FROM orders_full_typed
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY month
ORDER BY month ASC;


-- ==================================================
-- 2. 核对参与统计的订单总数
-- ==================================================

SELECT
    COUNT(*) AS total_orders
FROM orders_full_typed
WHERE order_purchase_timestamp IS NOT NULL;
