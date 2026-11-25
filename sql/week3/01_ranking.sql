
-- 01_ranking

/*R1 · Nth event. What's the order_id and date of customer 2's 3rd completed order?  - time : 5 mins
✔️ Order 6, 2026-08-20*/

-- check: Only orders with status = 'completed' are counted for customer 2, ordered chronologically by order_date with order_id ascending breaking any same-day ties.

with customer_orders as(
select order_id , order_date, 
row_number() over (partition by customer_id order by order_date, order_id) as order_seq
from orders 
where  customer_id = 2 and status = 'completed')
select order_id, order_date
from customer_orders
where order_seq = 3;

-- Result: customer 2's 3rd completed order is order_id : 6 , order_date: 2026-08-20.

/*R2 · Top products. Rank products by completed revenue with RANK(). Show the top 5.
✔️ #1 Burr Grinder 7,443.30 · #5 House Blend 1kg 1,699.32*/ -- time: 5 mins

-- Check: Only completed orders are included in net revenue (after discounts), ranked descending across all products with no ties affecting the top 5 cutoff.

with product_revenue as(
	select p.product_name, sum(oi.quantity * p.unit_price *(1- oi.discount_pct)) as revenue
	from products p
	join order_items oi on oi.product_id = p.product_id 
	join orders o on o.order_id = oi.order_id 
	where o.status = 'completed'
	group by p.product_name
)
select product_name, round(revenue ,2) as revenue,
rank() over (order by revenue desc) as ranked_product
from product_revenue
limit 5;

-- Result: Among all 13 products Burr Grinder has ranked top with revenue of $7,443.30 · and  House Blend 1kg  ranked 5th with revenue of $1,699.32

/*R3 · Dense rank. Using the city counts above, list the cities in the top 3 distinct paying-customer counts.
✔️ 4 cities (Calgary, Burnaby, Seattle, Surrey)*/  -- time : 5 mins

/* check: Paying customers are defined as unique customers with at least one completed order, 
 city names are normalized via TRIM and INITCAP before grouping, 
 and ties are preserved by filtering to the top 3 DENSE_RANK values.*/

WITH city_counts AS (
    SELECT INITCAP(TRIM(c.city)) AS city, COUNT(DISTINCT c.customer_id) AS paying
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.status = 'completed'
    GROUP BY 1
),
rank_calculator as (
SELECT city, paying,
       DENSE_RANK() OVER (ORDER BY paying DESC) AS dense_rnk
FROM city_counts
)
SELECT city, paying, dense_rnk
FROM rank_calculator
where dense_rnk <=3;

-- Result: there are 4 cities with distinct paying-customer they are Calgary, Burnaby, and a tie between Seattle and  Surrey

/*R4 · First-order channel. Through which channel did customers place their first completed order? Count the customers per channel.
✔️ web 29, app 13, store 12*/ -- time: 6 mins

-- check: Only completed orders are evaluated, each paying customer's first order is determined chronologically by order_date (with order_id ascending breaking any same-day ties), and customers without completed orders are excluded.

with order_rank as(
	select customer_id,  channel,
	row_number() over(partition by customer_id order by order_date , order_id) as order_rnk
	from orders
	where status = 'completed'
)
select channel, count(customer_id) as customers_count 
from order_rank
where order_rnk = 1
group by channel
order by customers_count desc;

-- result: channel web is in the top with 29 customers , app has 13 customers and store has 12 customers.

/*R5 . Find duplicates (data quality, STAT 331). Customers with the same first and last name may be duplicate accounts. Keep the lowest customer_id in each name group and flag the rest. How many are flagged?
✔️ 5*/ --time: 3 mins

--check: ll rows in the customers table are evaluated regardless of order history, first_name and last_name are normalized via LOWER(TRIM(...)) before grouping, and the lowest customer_id in each name group is kept while all higher IDs are flagged as duplicates.

with find_duplicates as(
	select customer_id, 
	row_number() over(partition by LOWER(TRIM(first_name)),LOWER(TRIM(last_name)) order by customer_id) as rn
	from customers
)
select count(*) 
from find_duplicates
where rn >1;

-- Result: There are 5 duplicate accounts

/*R6 · Top-N per group ⭐. For each province, the top 2 customers by completed revenue, with full names.
✔️ 8 rows. AB: Aisha Singh, Mei Gill. WA: Omar Lee, Priya Nguyen.*/ -- time: 8 mins 30 sec

-- check:  Only completed orders are included in net revenue (after discounts), provinces are normalized via UPPER(TRIM(...)), customers are grouped by customer_id to prevent same-name collisions, and ROW_NUMBER() selects the top 2 spenders per province (with customer_id ascending breaking any ties).

with total_revenue as(
	select concat(c.first_name||' '||c.last_name) as customer_name, c.province,
	sum(oi.quantity * p.unit_price *(1- oi.discount_pct)) as revenue,
 rank() over(partition by UPPER(TRIM(c.province)) 
	order by sum(oi.quantity * p.unit_price *(1- oi.discount_pct)) desc, c.customer_id) as rnk
	from order_items oi
	join orders o on o.order_id = oi.order_id  and o.status = 'completed'
	join products p on p.product_id = oi.product_id 
	join customers c on c.customer_id = o.customer_id 
	group by c.province , c.customer_id , customer_name
)
select province, customer_name, round(revenue, 2) as completed_revenue
from total_revenue
where rnk <= 2
order by province, rnk;

-- result: 8 rows, starting with AB: Aisha Singh 1,303.19, Mei Gill 1,096.56.

/* NOTE : for "top N" questions RANK is the safer choice, or keep ROW_NUMBER with an explicit tie-breaker i.e; 
 *  1. ROW_NUMBER without a tie-breaker
sql
ROW_NUMBER() OVER (PARTITION BY province ORDER BY revenue DESC)
Grace or Aarav gets rn = 2, unpredictably. Today it might be Grace and tomorrow Aarav. ❌
2. ROW_NUMBER with an explicit tie-breaker
sql
ROW_NUMBER() OVER (PARTITION BY province ORDER BY revenue DESC, customer_id ASC)
When revenue is tied, the lower customer_id wins, so Grace (26) always gets 2 and Aarav (41) always gets 3. The result is the same on every run. ✅
3. RANK, which keeps both
sql
RANK() OVER (PARTITION BY province ORDER BY revenue DESC)
 */

