
-- 01_warmup

select * from customers;
select * from order_items;
select * from orders;
select * from products;

-- 1. How many orders have each status? -- CORRECT ANSWER

/*select distinct(status),count(order_id)
from orders
group by(status);*/

--DISTINCT isn’t needed. GROUP BY already gives one row per status

SELECT status, COUNT(*) AS order_count
FROM orders
GROUP BY status
ORDER BY order_count DESC;

-- 2. Which customers have never placed an order? Show first and last name. -- CORRECT ANSWER

select first_name, last_name
from customers 
where customer_id not in(select customer_id 
from orders);

-- Use NOT EXISTS or LEFT JOIN + IS NULL (the "anti-join")
/* If the subquery returns even one NULL, NOT IN returns no rows at all. 
orders.customer_id allows NULL (remember the ◇ in the diagram),
so one bad row would silently break this query.*/


--3. Revenue by category for completed orders only, highest first. Revenue = quantity × unit_price × (1 − discount_pct).

select (oi.quantity * p.unit_price * (1 - oi.discount_pct)) as Revenue 
from products p
join order_items oi  on oi.product_id = p.product_id 
order by Revenue desc;

/*Your query returns 509 rows, one per order item, with no category and no total. 
 * To get revenue by category, for completed orders only:
Join orders, because status lives there.
Add up the revenue with SUM().
Group by category.*/

SELECT p.category,
       ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct)), 2) AS revenue
FROM order_items oi
JOIN orders   o ON o.order_id   = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'completed'
GROUP BY p.category
ORDER BY revenue DESC;

/*
Expected: Equipment 13,906.02, Coffee 4,396.72, Tea 2,665.07, Merch 1,451.35.
Habit to build: before writing, ask “one row per what?” Here it’s one row per category, 
so you need GROUP BY category, and everything else in the SELECT has to be an aggregate.

*/

--4. For each customer: their first and most recent completed order dates, 
--and how many completed orders they have. - CORRECT ANSWER

select c.customer_id , c.first_name, c.last_name, 
	Min(o.order_date) as first_order_date, 
	Max(o.order_date) as last_order_date,
	count(o.status) as completed_orders
from customers c
join orders o on o.customer_id = c.customer_id 
where o.status = 'completed' 
group by c.customer_id 
order by c.customer_id ;

--5. Total completed revenue per month, with the change from the previous month. - SKIP

WITH monthly AS (
  SELECT DATE_TRUNC('month', o.order_date)::date AS month,
         SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct)) AS revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  JOIN products p     ON p.product_id = oi.product_id
  WHERE o.status = 'completed'
  GROUP BY 1
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS change_vs_prev
FROM monthly
ORDER BY month;

  