/*
==========================================================================================
Customer Report
==========================================================================================
Purpose:
	- This report consolidates key customer metrics and behaviors

Highlights:
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups
	3. Aggregates customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend
==========================================================================================
*/

/* 
------------------------------------------------------------------------------------------
1) Base Query: Retrieves core columns FROM tables
------------------------------------------------------------------------------------------ */
IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS
  
WITH base_query AS(
SELECT 
	s.order_number,
	s.product_key,
	s.order_date,
	s.sales_amount,
	s.quantity,
	c.customer_key,
	c.customer_number,
	concat(c.first_name, ' ', c.last_name) AS customer_name,
	datediff(year, c.birthdate, getdate()) AS age
FROM gold.fact_sales s
LEFT JOIN gold.dim_customers c
ON c.customer_key = s.customer_key
WHERE order_date IS NOT NULL)

-- aggregation and customer details
, customer_aggregation AS(
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	sum(sales_amount) AS total_sales,
	sum(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_products,
	max(order_date) AS last_order_date,
	datediff(month, min(order_date), max(order_date)) AS lifespan
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	customer_name,
	age
)

-- final result

SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE
		WHEN age < 20 THEN 'under 20'
		WHEN age between 20 and 29 THEN '20-29'
		WHEN age between 30 and 39 THEN '30-39'
		WHEN age between 40 and 49 THEN '40-49'
		ELSE '50 and above'
	END as age_group,
	CASE
		WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END customer_category,
	last_order_date,
	datediff(month, last_order_date, getdate()) recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	lifespan,
	-- compute average order value
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_value,
	-- compute average monthly spend
	CASE
		WHEN lifespan = 0 THEN total_sales
		ELSe total_sales / lifespan
	END AS avg_monthly_spend
FROM customer_aggregation
