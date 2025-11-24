/*
==========================================================================================
Product Report
==========================================================================================
Purpose:
	- This report consolidates key product metrics and behaviors

Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segment products by revenue to identify High-Performers, Mid-range, or Low-performers.
	3. Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last order)
		- average order revenue
		- average monthly revenue
==========================================================================================
*/
/*
==========================================================================================
1) Base Query: Retrieves core columns from tables
==========================================================================================
*/
IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
	DROP VIEW
GO

CREATE VIEW gold.report_products AS
WITH base_query AS(
SELECT 
	s.order_number,
	order_date,
	s.customer_key,
	s.product_key,
	product_name,
	category,
	subcategory,
	cost,
	sales_amount,
	quantity
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
ON s.product_key = p.product_key
WHERE order_date IS NOT NULL) 

, product_aggregation AS(
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	COUNT(DISTINCT customer_key) total_customers,
	COUNT(DISTINCT order_number) total_orders,
	SUM(sales_amount) total_sales,
	COUNT(quantity) quantity_sold,
	MAX(order_date) last_order_date,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
FROM base_query
GROUP BY
	product_key,
	product_name,
	category,
	subcategory,
	cost
)

SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	total_customers,
	total_orders,
	total_sales,
	quantity_sold,
	last_order_date,
	DATEDIFF(month, last_order_date, getdate()) recency,
	CASE
		WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	lifespan,
	-- compute average order revenue
	CASE
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,
	-- monthly revenue
	CASE
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue
FROM product_aggregation
