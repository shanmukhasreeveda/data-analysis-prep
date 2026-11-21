 
 -- 03_Interview_practice

select * from customers;
select * from order_items;
select * from orders;
select * from products;

/*I1. “Which 3 cities have the most unique paying customers?”*/

/*
 Check: • "Paying" customers: What makes a customer "paying"? Usually, this means they have at least one order with status = 'completed' .
• Dirty city names: Remember from earlier exercises (like S1) that the city column in customers has inconsistent spacing and capitalization (e.g., ' surrey ', 'SURREY', 'Surrey'). 
• "Unique" customers: A customer who placed 5 completed orders should only be counted once for their city.
*/ 

select count(distinct c.customer_id) as customer_count, initcap(trim(c.city)) as cleaned_city
from customers c 
join orders o on o.customer_id = c.customer_id
where o.status = 'completed'
group by cleaned_city
order by customer_count desc
FETCH FIRST 3 ROWS WITH TIES;

-- Result: calgary  - 11, Burnaby -10, Surrey - 7, Seattle - 7

/*I2. “What percentage of orders contain more than one product?”*/

/*
Check: • Order status: Does "orders" include all orders (completed, pending, cancelled), or only completed orders? Let's assume all orders. 
• "More than one product": This means more than 1 distinct product_id in order_items (e.g., Coffee + Tea), not quantity > 1 of the same product (e.g., 2 bags of the same Coffee).
• Empty orders: Do any rows in orders have zero rows in order_items?
*/

	with product_counts as(
	select o.order_id, count(distinct oi.product_id) as distinct_products
	from orders o
	left join order_items oi on oi.order_id = o.order_id 
	group by o.order_id
)
select 
count(*) filter (where distinct_products > 1) as multi_product_orders, count(*) as total_orders,
round(100.0 * count(*) filter (where distinct_products > 1) / nullif(count(*),0),1) as pct_multi_product_orders
from product_counts;

-- Result: In 287 orders 181 orders contain more than one product which is about 63.1%

/*I3. "For each product category, what's the average discount rate on discounted items in completed orders?"*/

/*Check: Does "average discount rate on discounted items" mean the simple average across each qualifying line item
 * (AVG(discount_pct)), or weighted by quantity (SUM(discount_pct * quantity) / SUM(quantity))? Start with the standard line-item average (AVG), 
 * as that is the most direct interpretation*/

	select p.category, round(avg(oi.discount_pct) * 100.0,1) as avg_discount_pct
	from orders o
	join order_items oi on oi.order_id = o.order_id 
	join products p on p.product_id = oi.product_id 
	where o.status = 'completed' and oi.discount_pct > 0
	group by p.category
	order by avg_discount_pct desc;

-- Result: Tea - 12.4%, Coffee - 12.3%, Equipment - 12.2% , Merch - 11.9 %

/*I4. "How many customers placed orders on two consecutive days?"*/
	
	/*Check:  Does "orders" include all order statuses (completed, pending, cancelled), or only completed orders? 
	 * let us consider with all orders since the prompt does not specify a status filter
	 * "Two consecutive days": This means a customer placed at least one order on day X and another order on day X + 1 (a date difference of exactly 1 calendar day). 
	 * Two orders on the same day (difference = 0) do not count, and orders 2+ days apart (difference >= 2) do not count.*/
	
	select count(distinct a.customer_id)
	from orders a
	join orders b on b.customer_id = a.customer_id 
	where b.order_date - a.order_date =1;
	
	
	-- Result: 6 customers has placed orders on two consecutive days
	
/*I5. "Compare category revenue year over year. Make sure the comparison is fair."
(Think about what "fair" means, given the data ends on 2026-10-31.)*/

	/*Check: Because the 2026 data cuts off on 2026-10-31 (10 months of data), comparing all 12 months of 2025 against 10 months of 2026 would unfairly make 2026 look artificially lower. 
	 * A fair comparison restricts both years to January 1 through October 31 (Jan 1 – Oct 31, 2025 vs. Jan 1 – Oct 31, 2026).*/
	
	
	with category_yoy as (
		select p.category, 
		sum(oi.quantity * p.unit_price * (1 - oi.discount_pct)) filter(where o.order_date >= '2025-01-01' and o.order_date <= '2025-10-31') as rev_2025,
		sum(oi.quantity * p.unit_price * (1 - oi.discount_pct)) filter(where o.order_date >= '2026-01-01' and o.order_date <= '2026-10-31') as rev_2026
		from orders o
		join order_items oi on oi.order_id = o.order_id 
		join products p on p.product_id = oi.product_id 
		where o.status = 'completed'
		group by p.category 
	)
	select category, round(rev_2025,2) as rev_2025, round(rev_2026,2) as rev_2026,
	round(rev_2026 - rev_2025) as dollar_change,
	round(100.0 * (rev_2026 - rev_2025)/NULLIF(rev_2025,0),1) as pct_change
	from category_yoy
	order by rev_2026 desc;
-- Result: -- Fair YoY comparison (Jan 1 – Oct 31, 2025 vs. Jan 1 – Oct 31, 2026, completed orders only): Tea grew the fastest, increasing from $403.10 to $2,025.40 (+402.5%).
