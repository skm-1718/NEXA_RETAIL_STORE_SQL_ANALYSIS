-- Q1: What is the total revenue for 2023, broken down by quarter?


SELECT
CASE
WHEN CAST(strftime('%m', order_date) AS INTEGER) BETWEEN 1 AND 3 THEN 'Q1'
WHEN CAST(strftime('%m', order_date) AS INTEGER) BETWEEN 4 AND 6 THEN 'Q2'
WHEN CAST(strftime('%m', order_date) AS INTEGER) BETWEEN 7 AND 9 THEN 'Q3'
ELSE 'Q4' END AS Quarter,
ROUND(SUM(total_amount),2) AS Total_Revenue
FROM orders
WHERE strftime('%Y',order_date)='2023'
GROUP BY Quarter
ORDER BY Quarter;


-- Q2: Which are the top 5 stores by total revenue? Are they all in the same city?


SELECT s.store_name,s.city,ROUND(SUM(o.total_amount),2) total_revenue
FROM orders o JOIN stores s ON o.store_id=s.store_id
GROUP BY s.store_id,s.store_name,s.city
ORDER BY total_revenue DESC
LIMIT 5;


-- Q3: Which product category has the highest revenue per transaction?


SELECT p.category,
ROUND(SUM(oi.line_total)*1.0/COUNT(DISTINCT oi.order_id),2) revenue_per_transaction
FROM order_items oi
JOIN products p ON oi.product_id=p.product_id
GROUP BY p.category
ORDER BY revenue_per_transaction DESC
LIMIT 1;


-- Q4: How many stores met their monthly target in at least 8 of 12 months?


WITH monthly_sales AS (
    SELECT
        mt.store_id,
        mt.month,
        mt.target_amount,
        COALESCE(SUM(o.total_amount), 0) AS actual_revenue
    FROM monthly_targets mt
    LEFT JOIN orders o
        ON mt.store_id = o.store_id
       AND strftime('%Y-%m', o.order_date) = mt.month
    GROUP BY mt.store_id, mt.month, mt.target_amount
),
store_target_summary AS (
    SELECT
        store_id,
        SUM(CASE WHEN actual_revenue >= target_amount THEN 1 ELSE 0 END) AS months_target_met
    FROM monthly_sales
    GROUP BY store_id
)
SELECT COUNT(*) AS stores_meeting_target_8_plus_months
FROM store_target_summary
WHERE months_target_met >= 8;


-- Q5: What is the month-over-month revenue growth rate? Which month had the sharpest drop?


WITH monthly_revenue AS (
SELECT
    strftime('%Y-%m',order_date) AS month,
    SUM(total_amount) AS revenue
FROM orders
GROUP BY month
)

SELECT
    month,
    revenue,
    ROUND(
    (revenue-LAG(revenue)
    OVER(ORDER BY month))
    *100.0/
    LAG(revenue)
    OVER(ORDER BY month),2
    ) AS growth_rate
FROM monthly_revenue;



-- Q6: Which city has the highest average basket size? Which has the lowest?


SELECT s.city,ROUND(AVG(o.total_amount),2) average_basket_size
FROM orders o JOIN stores s ON o.store_id=s.store_id
GROUP BY s.city
ORDER BY average_basket_size DESC;



-- Q7: Are Kirana stores or Supermarkets generating more revenue per store?



SELECT
    s.store_type,
    ROUND(
    SUM(o.total_amount)/
    COUNT(DISTINCT s.store_id),2
    ) AS revenue_per_store
FROM orders o
JOIN stores s
ON o.store_id=s.store_id
GROUP BY s.store_type;



-- Q8: Which 3 products have declining monthly sales volume?



WITH monthly_product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        strftime('%Y-%m', o.order_date) AS month,
        SUM(oi.quantity) AS total_units
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.product_name, strftime('%Y-%m', o.order_date)
),
sales_trend AS (
    SELECT
        product_id,
        product_name,
        month,
        total_units,
        LAG(total_units) OVER (PARTITION BY product_id ORDER BY month) AS prev_units
    FROM monthly_product_sales
),
decline_count AS (
    SELECT
        product_id,
        product_name,
        SUM(CASE WHEN prev_units IS NOT NULL AND total_units < prev_units THEN 1 ELSE 0 END) AS decline_months
    FROM sales_trend
    GROUP BY product_id, product_name
)
SELECT
    product_name,
    decline_months
FROM decline_count
ORDER BY decline_months DESC, product_name
LIMIT 3;




-- Q9: What percentage of total revenue comes from the top 10% of stores?



WITH store_revenue AS (
SELECT
store_id,
SUM(total_amount) AS revenue
FROM orders
GROUP BY store_id
)

SELECT
ROUND(
(
SELECT SUM(revenue)
FROM(
SELECT revenue
FROM store_revenue
ORDER BY revenue DESC
LIMIT 4
)
)*100.0/
(
SELECT SUM(revenue)
FROM store_revenue
),2
) AS percentage;




-- Q10: If NexaRetail discontinued its bottom 3 products by revenue, how much revenue would be lost as a percentage of total?



WITH product_revenue AS(
SELECT
product_id,
SUM(line_total) AS revenue
FROM order_items
GROUP BY product_id
)

SELECT
ROUND(
(
SELECT SUM(revenue)
FROM(
SELECT revenue
FROM product_revenue
ORDER BY revenue
LIMIT 3
)
)*100.0/
(
SELECT SUM(revenue)
FROM product_revenue
),2
) AS revenue_loss_percentage;