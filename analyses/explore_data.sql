SELECT customer_segment, count(*) as count
FROM marts.dim_customers
GROUP BY customer_segment;