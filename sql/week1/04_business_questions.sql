
-- 04_business_questions

select * from customers;
select * from order_items;
select * from orders;
select * from products;

/*B1 · Headline numbers. Total revenue, number of orders, and AOV.
✔️ 22,419.15 · 255 · 87.92*/

with order_totals as(
	select o.order_id , sum(oi.quantity * p.unit_price *(1 - oi.discount_pct)) as revenue
	from orders o 
	join order_items oi on oi.order_id = o.order_id
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed'
	group by o.order_id
)
select round(sum(revenue),2) as total_revenue, count(order_id) as total_orders , 
round(avg(revenue),2)
from order_totals;

-- Across 255 completed orders, the business generated $22,419.15 in total revenue with an average order value of $87.92.

/*B2 · Best month. Revenue by month for 2026. Which month was highest?
✔️ The top month had 2,669.47.*/

with order_totals as(
	select o.order_id , o.order_date, sum(oi.quantity * p.unit_price *(1 - oi.discount_pct)) as revenue
	from orders o 
	join order_items oi on oi.order_id = o.order_id
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed'
	and o.order_date between '2026-01-01' and '2026-12-31'
	group by o.order_id, o.order_date
)
select to_char(date_trunc('month',order_date),'yyyy-mm')as month, count(order_id) as total_orders,
round(sum(revenue),2) as total_revenue
from order_totals
group by date_trunc('month',order_date)
order by month desc;

-- Through October 2026, August has generated a highest monthly revenue of $2,669.47

/* B3 · Top customers. Top 5 customers by lifetime revenue, with full name.
✔️ #1 is Aisha Singh, 1,303.19.*/

with order_totals as(
	select c.customer_id, (c.first_name||' '|| c.last_name)as customer_name,
	o.order_id, sum(oi.quantity * p.unit_price *(1 - oi.discount_pct)) as revenue
	from orders o 
	join order_items oi on oi.order_id = o.order_id
	join products p on p.product_id = oi.product_id 
	join customers c on c.customer_id = o.customer_id
	where o.status = 'completed'
	group by c.customer_id, o.order_id
)
select customer_name, round(sum(revenue),2) as lifetime_revene
from order_totals
group by customer_id, customer_name
order by lifetime_revene desc
limit 5;

--Among the top 5 customers, Aisha Singh ranks first with a lifetime revenue of $1,303.19.

/*B4 · Repeat rate. Of customers with at least one completed order, what % have two or more?
✔️ 40 of 54 = 74.1%*/

with order_totals as(
	select customer_id , count(order_id) as completed_orders
	from orders
	where status = 'completed'
	group by customer_id
)
select count(*) as customers_with_atlease_one_order,
count(*) filter(where completed_orders >=2) as customers_with_two_or_more_order,
round(100.0 * count(*) filter(where completed_orders >=2)/ count(*),1)as percentage
from order_totals;

--method - 2

with order_totals as(													-- 1st CTE
	select customer_id , count(order_id) as completed_orders
	from orders
	where status = 'completed'
	group by customer_id
),
customer_orders as(														--2nd CTE
	select count(*) as customers_with_atlease_one_order,
	count(*) filter(where completed_orders >=2) as customers_with_two_or_more_order
	from order_totals
)
select  customers_with_atlease_one_order,
customers_with_two_or_more_order,
round(100.0 * customers_with_two_or_more_order/ customers_with_atlease_one_order,1)as percentage
from customer_orders;

-- Out of all 60 customers, 54 have ordered at least one completed order and 74.1% of customers has places the order twice or more

/*B5·App reach. How many distinct customers have completed at least one order through the app?
✔️ 34*/

with order_totals as(
	select customer_id , count(order_id) as completed_orders, channel
	from orders
	where status = 'completed'
	group by customer_id, channel
)
select count(distinct customer_id) as customers_with_atlease_one_order
from order_totals
where channel = 'app';

-- 34 distinct customers have completed at least one order through the app

/*B6 · Revenue mix. Each category’s share (%) of total revenue.
✔️ Equipment 62.0%, Coffee 19.6%, Tea 11.9%, Merch 6.5%
Hint: the total goes in the denominator, so think about a subquery or CTE for it.
*/
with category_totals as(
	select p.category,
	sum(oi.quantity * p.unit_price *(1 - oi.discount_pct)) as revenue
	from orders o 
	join order_items oi on oi.order_id = o.order_id
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed'
	group by p.category
),
grand_total as(
	select sum(revenue) as total_revenue
	from category_totals
)
select c.category, round(c.revenue,2),
round(100.0 * c.revenue / g.total_revenue,2) as pct
from category_totals c
cross join grand_total g
order by pct desc;

--  Out of total completed order revenue, Equipment generates 62.0%, followed by Coffee (19.6%), Tea (11.9%), and Merch (6.5%).

/*B7 · Cost of discounts. How many dollars were given away in discounts?
✔️ 1,081.40, against a pre-discount total of 23,500.55.*/

select round(sum(oi.quantity * p.unit_price * oi.discount_pct),2) as discounted_revenue,
round(sum(oi.quantity * p.unit_price),2) as pre_discount_revenue
from orders o
JOIN order_items oi ON oi.order_id = o.order_id
join products p on p.product_id = oi.product_id
where o.status = 'completed';

--1,081.40$ were given away in discounts, against a pre-discount total of 23,500.55$.

/*B8 · Customer segments. Label all 60 customers by lifetime revenue:
 *  No purchases (0), Low (under 200), Mid (200–499.99), High (500+). Count the customers in each.
✔️ Mid 20 · Low 17 · High 17 · No purchases 6
Hint: this combines a pre-aggregation, a LEFT JOIN, COALESCE and CASE.
*/

with customer_revenue as(
	select c.customer_id,coalesce(sum(oi.quantity * p.unit_price *(1 - oi.discount_pct)),0) as revenue
	from customers c
	left join orders o on o.customer_id = c.customer_id and o.status = 'completed'
	left join order_items oi on oi.order_id = o.order_id
	left join products p on p.product_id = oi.product_id
	group by c.customer_id 
) 
select 
	case
		when revenue = 0 then 'No Purchase'
		when revenue < 200 then 'Low'
		when revenue >= 200 and revenue < 500 then 'Mid'
		else 'High'
	end as spend,
	count(*) as customer_count
from customer_revenue 
group by spend
order by customer_count desc;

-- Customer spend distribution across all 60 customers: Mid(($200–$499.99)) - 20 · Low (under $200) - 17 · High High ($500+) - 17 · No purchases - 6

/*B9 · Time to first order. On average, how many days pass between signup and a customer’s 
 * first order (any status)?
✔️ 104.6 days
Hint: in PostgreSQL, subtracting one date from another gives a number of days.*/

with first_order as(
	select c.customer_id, c.signup_date,
		MIN(o.order_date) as first_order_date
	from customers c
	join orders o on o.customer_id = c.customer_id 
	group by c.customer_id 
)
select 
	round(avg(first_order_date - signup_date),1) as avg_days_to_first_order
from first_order;

-- On average, 104.6 days pass between customer signup and their first order (across all order statuses).

/*B10 · Best seller per category (challenge ⭐). For each category, which product sold the most units?
✔️ Tea: Matcha 50g (77) · Coffee: House Blend 1kg (73) · Equipment: Pour-Over Kit (66) · Merch: Tote Bag (46)
Hint: this is hard without window functions (Week 3). Try it with a CTE of units per product, then compare each product to the MAX for its category.
*/
	with product_units as(
		select p.category, p.product_name, sum(oi.quantity) as units_sold
		from products p 
		join order_items oi on oi.product_id = p.product_id 
		join orders o on o.order_id = oi.order_id 
		where o.status = 'completed'
		group by p.category, p.product_name
	),
	category_max as(
		select category, max(units_sold) as max_units
		from product_units
		group by category
	)
	select pu.category, pu.product_name,pu.units_sold
	from product_units pu
	join category_max cm on pu.category = cm.category 
	and pu.units_sold = cm.max_units
	order by pu.units_sold desc;

-- Top-selling product by units sold (completed orders) in each category: Tea – Matcha 50g (77), Coffee – House Blend 1kg (73), Equipment – Pour-Over Kit (66), and Merch – Tote Bag (46).
