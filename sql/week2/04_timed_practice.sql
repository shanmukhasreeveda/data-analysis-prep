
-- 04_timed_practice

/*M1 · Refund rate.
"Which product has the highest refund rate?"
Define the refund rate as order lines in refunded orders ÷ all order lines for that product.*/

/*Check: Confirmed all order statuses are included in the denominator, 
 * there are no ties at the top.
 */

select p.product_name,count(oi.order_item_id) filter (where o.status = 'refunded') as refunded_count,
count(*) as total_rate,
Round(100.0 * count(oi.order_item_id) filter (where o.status = 'refunded') / nullif(count(*),0), 1) as refund_rate_pct
from products p
join order_items oi on oi.product_id = p.product_id 
join orders o on o.order_id = oi.order_id 
group by p.product_name
order by refund_rate_pct desc
limit 3;

-- Result: Ethiopian Yirgacheffe 250g has highest refund rate of 13.2%

/*M2 · Discount avoiders.
"How many paying customers have never received a discount on a completed order?"
*/

/*check: restrict the pool strictly to customers with at least one 'completed' order
• Zero discounts across all completed items: Every line item on every 'completed' order for that customer must have discount_pct = 0 (or NULL).
• Ignore non-completed orders: Discounts on 'cancelled' or 'pending' orders do not disqualify a customer.*/

with discount_avoiders as (
select distinct o.customer_id 
from orders o
join order_items oi on oi.order_id = o.order_id 
where o.status = 'completed' 
group by o.customer_id 
having  MAX(COALESCE(discount_pct, 0)) = 0)
select count(*) as discount_avoiders_count
from discount_avoiders;

-- result: there are 7 customers who have never received a discount on a completed order

/*M3 · Customer lifespan.
"For customers with at least 2 completed orders,
 what's the average number of days between their first and last completed order?"*/

/*Check: Restrict both the order count (>= 2) and the first/last order dates strictly to rows where status = 'completed'. 
 *Non-completed orders (pending, cancelled, refunded) must be excluded before finding MIN and MAX dates.*/


with order_totals as(
	select customer_id, count(order_id) as order_count, Min(order_date) as first_order, Max(order_date) as last_order
	from orders o 
	where status = 'completed'
	group by customer_id
)
select count( * ),
AVG(last_order - first_order) as average_count_of_days
from order_totals
where order_count >= 2 ;

-- Result: Out of 40 customers with at least 2 completed orders the average number of days between their first and last completed order is 275.8 days

/*M4 · Monthly active customers.
"In 2026, which month had the most active customers?"
Define "active" as having at least one completed order that month.*/

/*Check: If a customer places more that 1 completed orders in any month of 2026, they only count once */

with order_totals as(
	select customer_id, count(order_id) as order_count , TO_CHAR(order_date , 'yyyy-mm') as month 
	from orders 
	where status = 'completed' and 
	order_date >= '2026-01-01' and order_date <= '2026-10-31'
	group by customer_id , month
)
select month, count(*) as active_customers
from order_totals
group by month
order by active_customers  desc;

-- Till October 2026, August has observed most active customers with a count of 19. 

/* M5 · Revenue concentration.
"What percentage of total revenue comes from the top 10 customers?"
This shows how much the business depends on a few customers.*/

/*Check: Restrict revenue strictly to orders with status = 'completed' and  
 * Check whether the 10th and 11th customers are tied in revenue before limiting strictly to 10 rows.*/

with order_totals as(
	select o.customer_id , sum(oi.quantity * p.unit_price *(1- oi.discount_pct)) as revenue
	from orders o
	join order_items oi on oi.order_id = o.order_id 
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed'
	group by o.customer_id
),
first_ten_revenues as(
	select customer_id, revenue 
	from order_totals
	order by revenue desc
	limit 10
)
select round(100.0 * (select sum(revenue) from first_ten_revenues)/nullif((select sum(revenue) from order_totals),0), 2) as pct_total_revenue;
	
-- Result: 42.6% of total revenue comes from the top 10 customers.

/*M6 · Big-basket AOV.
"Among completed orders with at least 2 products, which channel has the highest average order value?"*/

/*Check: Compute each qualifying order's total net revenue (SUM(quantity * unit_price * (1 - discount_pct))) first, and then average those order totals per channel (AVG(order_revenue)).*/

with total_net_revenue as(
	select o.order_id ,  o.channel , sum(oi.quantity * p.unit_price *(1- oi.discount_pct)) as revenue
	from orders o
	join order_items oi on oi.order_id = o.order_id 
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed'
	group by o.order_id
	having count(distinct oi.product_id) >= 2
)
select channel, count (*) as qualifying_orders , round(avg(revenue),2) as avg_order_value
from total_net_revenue
group by channel 
order by avg_order_value desc;

-- Result: App has the highest average order value of 120.38$

/*M7 · Web-only BC customers.
"How many BC customers have only ever ordered through the web?"
Think carefully: what about customers who never ordered at all?
*/
/*Check- Include only BC customers (trimmed/uppercased) with 
 * at least one order across any status—excluding zero-order customers—whose entire order history 
 * used the 'web' channel exclusively.
 * */

WITH web_only_bc AS (
	SELECT c.customer_id
	FROM customers c
	JOIN orders o ON o.customer_id = c.customer_id
	WHERE UPPER(TRIM(c.province)) = 'BC'
	GROUP BY c.customer_id
	HAVING COUNT(*) FILTER (WHERE o.channel <> 'web') = 0
)
SELECT COUNT(*) AS web_only_bc_customers
FROM web_only_bc;

-- Result: There are 4 BC customers have only ever ordered through the web

/*M8 · Value per customer by province.
"Which province has the highest revenue per paying customer?"
Show revenue, paying customers, and revenue per customer for every province.*/

/*Check - Include all provinces from customers, counting only completed orders 
 * for net revenue and unique paying customers (having >= 1 completed order)
 */

with total_net_revenue as(
	select UPPER(TRIM(c.province)) as province , coalesce(sum(oi.quantity * p.unit_price *(1- oi.discount_pct)),0) as revenue,
	count(distinct o.customer_id) as paying_customers
	from customers c
	left join orders o on o.customer_id = c.customer_id  and o.status = 'completed'
	left join order_items oi on oi.order_id = o.order_id 
	left join products p on p.product_id = oi.product_id 
	where o.status = 'completed'
	group by UPPER(TRIM(c.province))
)
select province, round(revenue,2) as total_revenue, paying_customers,
	round(revenue /NULLIF(paying_customers, 0),2) AS revenue_per_customer
from total_net_revenue
order by revenue_per_customer desc;

-- Result: AB: 5,428.06 ÷ 11 = 493.46. BC has the most revenue but is 2nd per customer (438.04).
