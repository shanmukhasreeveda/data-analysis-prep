
-- 02_lag_lead


/*L1 · Biggest drop. In 2026, which month had the biggest % drop in completed revenue compared with the month before?*/

/* Check: Will be using LAG to get the previous month revenue */ -- time : 10:30 mins

with total_revenue as(
	select  to_char(o.order_date,'YYYY-MM') as month,
	sum(oi.quantity * p.unit_price * (1 - oi.discount_pct)) as revenue
	from orders o
	join order_items oi on oi.order_id = o.order_id
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed' 
	group by month
),
lag_revenue as(
	select month, revenue, lag(revenue) over ( order by month) as prev_revenue
	from total_revenue
)
select month, round(revenue,1),
	round(prev_revenue,1), round(100.0 * (revenue - prev_revenue) / nullif(prev_revenue,0),1) as pct_change
from lag_revenue 
where month like '2026%'
order by pct_change nulls last;

-- Result: October 2026, −31.8%


/*L2 · Purchase gap. On average, how many days pass between a customer's consecutive completed orders?*/ -- time: 4 mins

/* Check : will be considering all the channels and average,of days pass between a customer's consecutive completed orders */

with days_count as(
	select 
	order_date - lag(order_date) over (partition by customer_id order by order_date, order_id) as days_since_prev
	from orders
	where status = 'completed'
	group by  order_date, order_id
)
select ROUND(AVG(days_since_prev),1) as avg_days_since_prev
from days_count;

-- result: On average, 54.9 days pass between a customer's consecutive completed orders

/*L3 · Long gaps. How many customers have at least one gap of more than 180 days between consecutive completed orders?*/  -- time: 3 mins

-- check : will be considering all the channels and  days between a customer's consecutive completed orders.

with days_count as(
	select customer_id,
	order_date - lag(order_date) over (partition by customer_id order by order_date, order_id) as days_since_prev
	from orders 
	where status = 'completed'
	group by customer_id,order_date, order_id
)
select count(distinct customer_id) as customers_count
from days_count
where days_since_prev > 180;

-- result: there are 8 customers who have at least one gap of more than 180 days between consecutive completed orders


/*L4 · Second-order speed. Of customers with 2 or more completed orders, what % placed their 2nd order within 60 days of their 1st?*/

/* CHECK: Will be using LAG to get the difference between the days and calculate the % of customers with 
 * 2 or more completed orders that falls between 60 days of their 1st and row_number() will be use to get the Second-order speed
 */

-- time : 15 mins


with customer_count as(
	select  customer_id, 
	row_number() over (partition by customer_id order by order_date, order_id) as order_rnk,
		order_date - lag(order_date) over (partition by customer_id order by order_date, order_id) as date_diff
	from orders 
	where status = 'completed'
)
select count(*) filter (where date_diff <= 60) as within_60_customers ,
count(*) as total_repeat_customers,
	round(100.0 * count(*) filter (where date_diff <= 60)/ nullif(count(*),0),2) as pct
	from customer_count
	where order_rnk = 2;

-- Result: there are 18 customers with 2 or more completed orders out of 40 total_repeat_customers i.e; 45% of total_repeat_customers.

/*L5 · Channel switching. Looking at every order (any status) and the same customer's previous order,
 *  what % of the time did the customer use a different channel?*/ -- time: 15 mins

-- check : All orders across every status are included, chronological sequence is ordered by order_date ASC with order_id ASC breaking same-day ties, and each customer's first order (where prev_channel IS NULL) is excluded from the denominator.
with order_transition as(
	select  customer_id, channel, 
	lag(channel) over (partition by customer_id order by order_date, order_id) as prev_channel
	from orders 
)
select count(*) filter(where channel<> prev_channel) as switched_orders,
count(*) as total_subsequent_orders,
	round(100.0 * count(*) filter(where channel<> prev_channel)/ nullif(count(*),0),1) as pct_channel_switched
	from order_transition
where prev_channel is not null;

-- result: 141 switched_orders in the total_subsequent_orders of 233 i.e; 60.5%

/*L6 · Came back within 30 days? (LEAD) ⭐
For each completed order, did the same customer place another completed order within 30 days? Give the % of orders where they did.
Fairness twist: orders placed after 2026-10-01 haven't had a full 30 days to be followed up yet, because the data ends on 10-31. Leave them out of the base, but still let them count as the "next order" for earlier orders.*/ -- time : 10 mins

-- check: Only completed orders are evaluated at the order grain (ordered by order_date ASC, order_id ASC), orders after 2026-10-01 are excluded from the base denominator for a fair 30-day window while still counting as valid next orders, and <= 30 days includes same-day repeat orders.

with CTE as(
	select customer_id, order_date,
	lead(order_date) over (partition by customer_id order by order_date , order_id) - order_date as date_diff
	from orders 
	where status = 'completed'
)
select count(*) filter(where date_diff <= 30) as followed_up_orders,
count(*) as eligible_orders,
round(100.0 * count(*) filter(where date_diff <= 30)/ nullif(count(*),0),1)as pct
from CTE
where order_date <= '2026-10-01';

-- result: 90 of 235 = 38.3%
