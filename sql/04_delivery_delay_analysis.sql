
-- ==================================================
-- Olist 电商订单分析项目
-- 04 配送延迟分析
-- 功能：计算整体、地区、月份延迟率
-- ==================================================

USE olist_project;


-- ==================================================
-- 1. 整体配送延迟率
-- ==================================================

-- delay_orders 视图已经完成有效样本筛选。
-- is_delayed = 1 表示延迟，0 表示未延迟。
-- 因此 AVG(is_delayed) 就是延迟比例。

SELECT
    COUNT(*) AS total_orders,
    SUM(is_delayed) AS delayed_orders,
    ROUND(AVG(is_delayed) * 100, 2) AS delay_rate_pct
FROM delay_orders;


-- ==================================================
-- 2. 各州配送延迟率
-- ==================================================

-- GROUP BY customer_state 按客户所在州分组。
-- HAVING COUNT(*) > 1000 只保留有效订单数
-- 超过 1000 的州，减少小样本影响。

SELECT
    customer_state,
    COUNT(*) AS total_orders,
    SUM(is_delayed) AS delayed_orders,
    ROUND(AVG(is_delayed) * 100, 2) AS delay_rate_pct
FROM delay_orders
GROUP BY customer_state
HAVING COUNT(*) > 1000
ORDER BY delay_rate_pct DESC;


-- ==================================================
-- 3. 各月配送延迟率
-- ==================================================

-- 按订单下单月份分组。
-- 与月度订单量分析的时间口径保持一致。
-- 注意：这里统计的是有有效延迟标签的订单，
-- 并不是每个月的全部下单订单。

SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    SUM(is_delayed) AS delayed_orders,
    ROUND(AVG(is_delayed) * 100, 2) AS delay_rate_pct
FROM delay_orders
GROUP BY month
ORDER BY month ASC;


-- ==================================================
-- 4. 筛选有效订单数超过 1000 的月份
-- ==================================================

-- HAVING 是在 GROUP BY 分组完成后筛选分组。
-- 这里不改变整体延迟率，只提供重点月份的比较。

SELECT
    DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    SUM(is_delayed) AS delayed_orders,
    ROUND(AVG(is_delayed) * 100, 2) AS delay_rate_pct
FROM delay_orders
GROUP BY month
HAVING COUNT(*) > 1000
ORDER BY month ASC;
