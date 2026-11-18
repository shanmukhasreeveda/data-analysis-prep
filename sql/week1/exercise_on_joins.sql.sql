-- Exercise_on_joins.sql

select * from customers;
select * from order_items;
select * from orders;
select * from products;

/*E1 · INNER JOIN with three tables
List every refunded order: order_id, order_date, customer full name, 
and the number of items in the order. Oldest first.
✔️ Check: 12 rows. The first is order 16 (Isha Brown, 2025-05-22, 1 item).*/

select  o.order_id, (c.first_name ||' '|| c.last_name) as customer_name, o.order_date,
count(oi.order_id) as number_of_items
from orders o
join customers c on c.customer_id = o.customer_id 
join order_items oi on oi.order_id = o.order_id 
where o.status = 'refunded'
group by o.order_id, customer_name
order by o.order_date ;

/*E2 · LEFT JOIN, filter in ON
For all 60 customers, show how many cancelled orders they have, with 0 if none. 
Sort by the cancelled count, highest first.
✔️ Check: 60 rows. Customers 2 and 43 have 3 cancelled orders each, 
and 15 customers have at least one.
Hint: where does status = 'cancelled' belong?*/

select c.customer_id,
coalesce(count(o.order_id),0) as total_cancelled_orders
from customers c
left join orders o on o.customer_id = c.customer_id and o.status ='cancelled'
group by c.customer_id 
order by total_cancelled_orders desc;

/*E3 · Anti-join
Which products have never been part of a refunded order?
✔️ Check: 4 products, one of them Matcha 50g.
Hint: NOT EXISTS with a join inside the subquery.*/

-- Approch - 1
select p.product_name
from products p
left join (select oi.product_id 
from order_items oi
join orders o on o.order_id = oi.order_id 
where o.status = 'refunded') sq on sq.product_id = p.product_id 
where sq.product_id is null;

-- Approach - 2

select p.product_name
from products p
where not exists(
select oi.product_id 
from order_items oi
join orders o on o.order_id = oi.order_id 
where o.status = 'refunded' and oi.product_id = p.product_id);

/*E4 · Two conditions in ON
For every customer in BC, show the number of completed orders in 2026, with 0 if none.
✔️ Check: 34 rows, of which 7 customers have 0.
Hint: one condition goes in ON and one in WHERE. Which is which, and why?*/

select c.customer_id , count(o.order_id) as completed_orders
from customers c
left join orders o on o.customer_id = c.customer_id 
and o.status = 'completed'
and o.order_date between '2026-01-01' and '2026-12-31'
where c.province = 'BC'
group by c.customer_id ;

/*E5 · Spot the bug 🐞
A colleague wrote this to answer E4 and got only 27 rows instead of 34. 
Explain why in one sentence, then fix it.
*/

SELECT c.customer_id, COUNT(o.order_id) AS orders_2026
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE c.province = 'BC'
  AND o.status = 'completed'
  AND o.order_date >= '2026-01-01'
GROUP BY c.customer_id;

/*Filtering on the right-hand table (o.status and o.order_date) 
 * inside the WHERE clause turns the LEFT JOIN into an INNER JOIN, 
 * dropping BC customers who have zero completed orders in 2026.*/

SELECT c.customer_id, COUNT(o.order_id) AS orders_2026
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
  AND o.status = 'completed'
  AND o.order_date >= '2026-01-01'
  WHERE c.province = 'BC'
GROUP BY c.customer_id;

/*E6 · Avoiding double counting
For completed orders, show for each channel: the number of orders, 
the number of order lines, and revenue. Highest revenue first.
✔️ Check: web: 142 orders, 252 lines, revenue 12,149.32.
Hint: one order has several lines, so think about which count needs DISTINCT.
*/

select distinct(o.channel),count(distinct o.order_id) as total_orders, 
count(oi.order_item_id) as total_lines,
sum(oi.quantity * p.unit_price *(1-oi.discount_pct)) as revenue
from order_items oi
left join orders o on o.order_id = oi.order_id
join products p on p.product_id = oi.product_id
where o.status = 'completed'
group by o.channel
order by revenue desc;

/*E7 · Self-join with dates (challenge ⭐)
How many customers placed two orders within 7 days of each other, 
meaning the second order came 1 to 7 days after the first? Any status counts.
✔️ Check: 23 customers.
Hint: join orders to itself on customer_id, with a date condition like: 
sql: b.order_date > a.order_date AND b.order_date <= a.order_date + 7
In PostgreSQL, date + 7 means 7 days later. Then count distinct customers.
*/

select count(distinct a.customer_id)
from orders a
join orders b on b.customer_id = a.customer_id 
where b.order_date > a.order_date and b.order_date <= a.order_date+7;