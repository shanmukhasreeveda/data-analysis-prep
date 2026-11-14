
-- 02_joins.sql

select * from customers;
select * from order_items;
select * from orders;
select * from products;

/*P1 (inner join). List all store-channel orders placed in
October 2026: order_id, order_date and the customer’s full name, oldest first.
Check: you should get 2 rows.*/
 
select o.order_id, o.order_date, (c.first_name || ' ' || c.last_name) as Customers_name
from orders o
join customers c on c.customer_id = o.customer_id 
where o.channel = 'store'
and o.order_date >= '2026-10-01' and o.order_date < '2026-11-01'
order by o.order_date;



/*P2 (LEFT JOIN + ON vs WHERE). For all 13 products, show total units sold in completed orders.
 Products with no sales should show 0. Sort from highest to lowest.
Check: the top product is Matcha 50g. Careful: there are two joins here, 
and the completed filter has to go in the right place.*/


select p.product_name, sum(oi.quantity) as total_units_sold
from order_items oi
left join products p on p.product_id = oi.product_id
join orders o on o.order_id = oi.order_id
where o.status = 'completed'
group by p.product_name, p.product_id
order by total_units_sold desc; -- The right numbers this time, but the logic is wrong

/*only products that sold at least once in a completed order can appear. 
 * A product with no sales disappears instead of showing 0.
 *  You get 13 rows now only because every product happens to have sold.*/


SELECT p.product_name,
       COALESCE(SUM(ci.quantity), 0) AS total_units_sold
FROM products p
LEFT JOIN (
    SELECT oi.product_id, oi.quantity
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
) ci ON ci.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_units_sold DESC;

--The subquery ci builds “completed items” first. The LEFT JOIN then keeps every product.
--COALESCE(x, 0) turns NULL into 0.




/*P3 (anti-join). List customers who have placed at least one order but 
 have never ordered through the app channel.
Check: 19 customers.*/

select c.customer_id, (c.first_name ||' '|| c.last_name) as customer_name
from customers c
left join orders o on o.customer_id = c.customer_id  and o.channel = 'app'
where c.customer_id in (select customer_id from orders)
and o.customer_id is null;


/*P4 (join + messy data + double counting). For each city, 
 * show the number of customers and the number of orders, with most orders first.
 *  The city values are messy ('VANCOUVER ' vs 'Vancouver'), so clean them first. 
 * Hint: INITCAP(TRIM(city)). Count every customer, including those with no orders.
Check: Calgary is first.*/

select INITCAP(Trim(c.city)) as city1, count(distinct c.customer_id) as total_customers, count(o.order_id) as total_orders
from customers c
left join orders o on o.customer_id = c.customer_id 
group by city1
order by total_orders desc, city1;

/*P5 (self-join, a COMP 430 throwback). Which pairs of products are most often 
 * bought in the same order? Show the top 5 pairs with their counts. This is a simple form of 
 * market-basket analysis, the frequent-pattern mining you did in COMP 430.
Hint: join order_items to itself on order_id.
Check: the top pair appears in 8 orders.*/ 

select  a.product_id as product_1 , b.product_id as product_2, count(a.order_id) as total_orders
from order_items a
join order_items b on b.order_id = a.order_id 
where a.product_id < b.product_id 
group by product_1, product_2
order by total_orders desc 
limit 5;   -- correct but show product names

-- Show product names, not ids. Join products twice:
sql
SELECT p1.product_name AS product_1,
       p2.product_name AS product_2,
       COUNT(*) AS orders_together
FROM order_items a
JOIN order_items b ON b.order_id = a.order_id AND a.product_id < b.product_id
JOIN products p1   ON p1.product_id = a.product_id
JOIN products p2   ON p2.product_id = b.product_id
GROUP BY p1.product_name, p2.product_name
ORDER BY orders_together DESC
LIMIT 5;
   
