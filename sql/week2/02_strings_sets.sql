
 -- 02_strings_sets

select * from customers;
select * from order_items;
select * from orders;
select * from products;


/*Quick self-test: which pattern finds every 
 * product starts with “e” in its name, in upper or lower case? Try it.*/

select product_name 
from products 
where product_name ilike 'e%'; --- gives 3 names as outputs as ilike is insensitive to case of leters.

select product_name 
from products 
where product_name like 'e%'; -- gives no result as there are products stating with E but not with e


/*S1 · Display label. For customers 7 and 30, build a label in the format Last, First (City), using the cleaned city.
✔️ Gill, Chloe (Surrey) · Gill, Noah (Burnaby)*/

select 
concat(last_name,', ' , first_name,' (',INITCAP(TRIM(city)),')') as display_label
from customers
where customer_id = '7' or customer_id = '30';

-- Result: Formatted display labels for customers 7 and 30 (using trimmed, title-cased city names): Gill, Chloe (Surrey) and Gill, Noah (Burnaby).

/*S2 · Price per 100g (regex + maths) ⭐. For Coffee and Tea products, extract the size,
 *  convert it to grams (1kg = 1000g), and calculate the price per 100g, most expensive first.
✔️ Top: Matcha 50g at 42.00. Bottom: House Blend 1kg at 2.50.
Hint: get the number and the unit separately, then use CASE for the kg conversion.
*/

with product_sizes as(
	select product_name, unit_price,
	substring(product_name from '(\d+)\s?(?:g|kg)')::numeric as product_size,
	substring(product_name from '\d+\s?(g|kg)') as size_unit
	from products
	where category in ('Coffee' , 'Tea')
),
grams_convertion as(
	select product_name, unit_price,
	case
		when size_unit ilike ('kg') then  product_size * 1000 
		else product_size 
	end as grams
	from product_sizes
)
select product_name, round(unit_price * 100 / grams,2) as price
from grams_convertion
order by price desc;

-- Result: Price per 100g for Coffee and Tea products (converted to grams, sorted most expensive first): Matcha 50g is the highest at $42.00 per 100g, while House Blend 1kg is the lowest at $2.50 per 100g.

/*S3 · Data-quality check. How many customers have a city value that isn’t already clean, meaning it differs from its trimmed, initial-capitals version?
✔️ 5*/

select count(*) 
from customers 
where city <> Trim(city) or city <> initcap(city);

--Result: 5 customers have a city value that isn’t already clean

/*S4 · UNION vs UNION ALL. Using completed orders only, 
 * how many customers ordered through the app or the store? 
 * Write it with UNION, then with UNION ALL, and explain in a comment why the numbers differ.
✔️ UNION 47, UNION ALL 113 rows*/

WITH combined_customers AS (
	SELECT customer_id FROM orders WHERE status = 'completed' AND channel = 'app'
	UNION
	SELECT customer_id FROM orders WHERE status = 'completed' AND channel = 'store'
)
SELECT COUNT(*) AS union_count
FROM combined_customers;


WITH combined_customers AS (
	SELECT customer_id FROM orders WHERE status = 'completed' AND channel = 'app'
	union all
	SELECT customer_id FROM orders WHERE status = 'completed' AND channel = 'store'
)
SELECT COUNT(*) AS union_all_count
FROM combined_customers;

-- Result: UNION returns 47 rows (distinct customers who completed at least one order via app or store, deduplicating repeat orders within the same channel and customers who used both channels).
-- Result:  UNION ALL returns 113 rows (every completed order across both channels combined, keeping all duplicate customer_ids).

/*S5 · INTERSECT. How many customers have completed orders in all three channels?
✔️ 22*/ 

WITH combined_customers AS (
	SELECT customer_id FROM orders WHERE status = 'completed' AND channel = 'app'
	INTERSECT
	SELECT customer_id FROM orders WHERE status = 'completed' AND channel = 'store'
	intersect
	SELECT customer_id FROM orders WHERE status = 'completed' AND channel = 'web'
)
SELECT COUNT(*) AS count_of_all_three_channel
FROM combined_customers;

-- Result: 22 distinct customers have completed at least one order across all three channels (app, store, and web).

/* S6 · EXCEPT: churned customers. Which customers had a completed order in 2025 but none in 2026? 
 * Show their full names, A–Z.
✔️ 8 customers. The first is Aarav Nguyen.*/

WITH churned AS (
    SELECT customer_id
    FROM orders
    WHERE status = 'completed'
      AND order_date >= '2025-01-01' AND order_date < '2026-01-01'
    EXCEPT
    SELECT customer_id
    FROM orders
    WHERE status = 'completed'
      AND order_date >= '2026-01-01' AND order_date < '2027-01-01'
)
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name AS full_name
FROM churned ch
JOIN customers c ON c.customer_id = ch.customer_id
ORDER BY full_name, c.customer_id;

--Result:  There are 8 customers who had a completed order in 2025 but none in 2026.