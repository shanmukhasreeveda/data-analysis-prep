
 -- 01_subqueries_dates

select * from customers;
select * from order_items;
select * from orders;
select * from products;

/*W1 · Scalar subquery. What percentage of completed orders are above the average order value?
✔️ 84 of 255 = 32.9%*/

with order_totals as(
	select o.order_id, sum(oi. quantity * p.unit_price *(1- oi.discount_pct)) as revenue
	from orders o
	join order_items oi on oi.order_id = o.order_id
	join products p on p.product_id = oi.product_id
	where o.status = 'completed'
	group by o.order_id
)
select 
	round(100.0 * count(*) filter(where revenue > (select AVG(revenue) from order_totals)) / count(*),1) as above_avg_pct
from order_totals;

-- Result: 32.9 (32.9% of completed orders—84 out of 255—exceed the overall average order value).


/*W2 · HAVING with COUNT DISTINCT. How many customers have bought from all 4 categories?
✔️ 20*/

select count(*) as customers_bought_all_4
from (
	select o.customer_id
	from orders o
	join order_items oi on oi.order_id = o.order_id
	join products p on oi.product_id = p.product_id
	where o.status = 'completed'
	group by o.customer_id 
	having count(distinct p.category) = 4
	) as sub;

-- Result: 20 (20 customers have completed purchases across all 4 distinct product categories).

/*W3 · Day of week. Which day of the week brings in the most revenue? 
 * Show all 7 days in calendar order, with day names.
✔️ Tuesday, 4,681.42*/

select EXTRACT(DOW from o.order_date) as dow,
TO_CHAR(o.order_date, 'Dy') as day_name,
round(sum(oi. quantity * p.unit_price *(1- oi.discount_pct)),2) as revenue
from orders o
join order_items oi on oi.order_id = o.order_id
join products p on oi.product_id = p.product_id
where o.status = 'completed'
group by dow,day_name
order by dow;

-- Result: 7 rows ordered Sun (0) to Sat (6), peaking on Tuesday (dow 2, 'Tue') with $4,681.42 in revenue.

/*W4 · Recency. How many customers’ last completed order was more than 180 days 
 * before 2026-10-31? These are your “at-risk” customers.
✔️ 12*/

with customers_at_risk as(
	select customer_id
	from orders 
	where status = 'completed'
	group by customer_id 
	having date '2026-10-31' - Max(order_date) > 180
)
select count(*) as at_risk_customers
from customers_at_risk;

-- Result: 12 (12 customers have gone more than 180 days without a completed order prior to 2026-10-31).

/*W5 · Fast starters. Among customers who have ordered (any status), 
 * what % placed their first order within 30 days of signing up?
✔️ 20 of 54 = 37.0% */

with fast_starters as(
	select customer_id, Min(order_date) as first_order_date
	from orders 
	group by customer_id 
)
select round(100.0 * count(*) filter(where first_order_date - c.signup_date <= 30)/count(*),1) as fast_starters_pct
from fast_starters fs
join customers c on c.customer_id = fs.customer_id;

-- Result: 37.0 (37.0% of ordering customers—20 out of 54—placed their first order within 30 days of signup).

/*W6 · Gap filling ⭐. Units sold per month for French Press, 
 * January to October 2026, showing every month, including those with 0.
✔️ 10 rows, of which 2 months show 0.*/


with months as(
	select generate_series(DATE '2026-01-01', DATE '2026-10-01', INTERVAL '1 month')::date as month
),
sales as(
	select DATE_TRUNC('month',o.order_date)::date as month, sum(oi.quantity) as units
	from orders o
	join order_items oi on oi.order_id = o.order_id
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed' and p.product_name = 'French Press'
	group by month
)
select m.month, coalesce(s.units,0) as units
from months m
left join sales s on s.month = m.month
order by m.month;

-- Result: 10 monthly rows (Jan–Oct 2026) showing French Press units sold, with 0 filled in for the 2 months with no completed sales.
