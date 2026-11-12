
--create database practice;

   SELECT 'customers' AS tbl, COUNT(*) FROM customers
   UNION ALL SELECT 'products', COUNT(*) FROM products
   UNION ALL SELECT 'orders', COUNT(*) FROM orders
   UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;