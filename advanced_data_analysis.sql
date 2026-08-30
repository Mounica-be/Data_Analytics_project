/*
===========================================
Advanced data Analytics
===========================================
*/

-- ---------------------------------------
-- Change over time Analysis ( Trends)
-- ---------------------------------------
/*
Purpose: 
	Analyse how a measure evolves over time.
	Helps track trends and identify seasonality in your data.
*/

-- Analyse sales performance over time.
-- by year
SELECT
	YEAR(order_date) AS order_year,
	SUM(sales_amount) AS sales,
	COUNT( DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM dbo.fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year

-- by month
SELECT
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS sales,
	COUNT( DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM dbo.fact_sales
WHERE MONTH(order_date) IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY order_month

SELECT
	DATETRUNC(month,order_date) AS order_time,
	SUM(sales_amount) AS sales,
	COUNT( DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM dbo.fact_sales
WHERE DATETRUNC(month, order_date) IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY order_time


SELECT
	YEAR(order_date) AS order_year,
	MONTH(order_date) AS order_month,
	SUM(sales_amount) AS sales,
	COUNT( DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY order_year, order_month

SELECT
	FORMAT(order_date, 'yyyy-MMM') AS order_year,-- outputs string
	SUM(sales_amount) AS sales,
	COUNT( DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM')

-- -------------------------------
-- Cumulative analysis
-- -------------------------------

/*
Aggregate the data progressively over time.
Helps to uderstand whether business is growing or declining
*/

-- calculate the total sales per month
-- and the running total of sales over time.
SELECT 
	order_date,
	total_sales,
	--window function
	SUM(total_sales) OVER ( ORDER BY order_date) AS running_total,
	avg_price,
	AVG(avg_price) OVER ( ORDER BY order_date) AS moving_avg_price
FROM (
	SELECT
		DATETRUNC(month,order_date) AS order_date,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS avg_price
	FROM dbo.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(month,order_date)
) t
-- running total per year.
SELECT 
	order_date,
	total_sales,
	--window function
	SUM(total_sales) OVER ( PARTITION BY YEAR(order_date) ORDER BY order_date) AS running_total
FROM (
	SELECT
		DATETRUNC(month,order_date) AS order_date,
		SUM(sales_amount) AS total_sales
	FROM dbo.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(month,order_date)
) t

SELECT 
	order_date,
	total_sales,
	--window function
	SUM(total_sales) OVER ( ORDER BY order_date) AS running_total,
	avg_price,
	AVG(avg_price) OVER ( ORDER BY order_date) AS moving_avg_price
FROM (
	SELECT
		DATETRUNC(year,order_date) AS order_date,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS avg_price
	FROM dbo.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(year,order_date)
) t

-- --------------------------------------------
-- Performance Analysis
-- --------------------------------------------
/*
Comparing the current value to a target value.
Helps measure success and compare performance.
*/

/* Analyze the yearly performance of products by comparing each product's sales 
to both it's average sales performance and the previous year's sales.
*/


WITH yearly_product_sales AS (
	SELECT 
			YEAR(f.order_date) AS order_year,
			p.product_name,
			SUM(sales_amount) AS current_sales
	FROM dbo.fact_sales f
	LEFT JOIN  dbo.dim_products p
	ON p.product_key = f.product_key
	WHERE order_date is NOT NULL
	GROUP BY YEAR(f.order_date),
			 p.product_name
)
SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER ( PARTITION BY product_name) AS avg_sales,
	current_sales- AVG(current_sales) OVER ( PARTITION BY product_name) AS diff_avg,
	CASE 
		WHEN current_sales- AVG(current_sales) OVER ( PARTITION BY product_name)> 0 THEN 'Above avg'
		WHEN current_sales -AVG(current_sales) OVER ( PARTITION BY product_name) <0 THEN 'Below avg'
		ELSE 'Avg'
	END AS avg_change,
	-- Year over Year analysis
	LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_sales,
	current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_change,
	CASE WHEN current_sales-LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	     WHEN current_sales-LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		 ELSE 'No change'
	END AS prv_change
FROM yearly_product_sales
ORDER BY product_name,order_year

-- ----------------------------------------------------
-- Part to whole analysis
-- ----------------------------------------------------

/*
Analyze how an individual part is performing campared to the overall,
allowing us to to understand which category has greatest impact on the business.
*/

-- Which category contribute the most to overall sales.
SELECT
	category,
	cat_sales,
	SUM(cat_sales) OVER () AS total_sales,
	CONCAT(ROUND((CAST(cat_sales AS FLOAT)/SUM(cat_sales) OVER() )* 100,2),'%')  AS percent_contribution
FROM (
	SELECT
		p.category,
		SUM(f.sales_amount) AS cat_sales
	FROM dbo.fact_sales f
	LEFT JOIN dbo.dim_products p
	ON f.product_key = p.product_key
	GROUP BY p.category
) t
ORDER BY percent_contribution DESC

-- --------------------------------------------
-- Data Segmentation
-- --------------------------------------------
/*
Group the data based on a specific range.
Helps undertand correlation between two measures.
*/

-- segment product into cost ranges and count the products in each category.
SELECT 
	cost_range,
	COUNT(product_key) AS no_of_products
FROM (
	SELECT
		product_key,
		product_name,
		cost,
		CASE WHEN cost < 100 THEN 'Below 100'
			 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
			 WHEN cost BETWEEN 501 AND 1000 THEN '501-1000'
			 ELSE 'Above 1000'
		END AS cost_range
	FROM dbo.dim_products
) t 
GROUP BY cost_range
ORDER BY no_of_products

/*
Group customers into three segments based on their spending behavior:
	- VIP: customers with atleast 12 months of history and spending more than $5,000.
	- Regular: customers with atleast 12 months of history but spending $5000 or less.
	- New: customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/
WITH customer_segments AS (
	SELECT
		c.customer_key,
		CASE WHEN DATEDIFF(month,MIN(f.order_date),MAX(f.order_date)) >=12
				  AND SUM(f.sales_amount) >5000 THEN 'VIP'
			 WHEN DATEDIFF(month,MIN(f.order_date),MAX(f.order_date)) >=12
				  AND SUM(f.sales_amount)  <=5000 THEN 'Regular'
			 ELSE 'New'
		END AS  segments
		FROM dbo.dim_customers c
		LEFT JOIN dbo.fact_sales f
		ON c.customer_key = f.customer_key
		GROUP BY c.customer_key
)
SELECT
	segments,
	COUNT(customer_key) AS no_of_customers	
FROM customer_segments
GROUP BY segments
ORDER BY COUNT(customer_key) DESC
	
-- --------------------------------------
-- Reporting
-- --------------------------------------
/*
============================================================================
Customer Report
============================================================================
Purpose:
	- This report consolidates key customer metrics and behaviors

Highlights:
	1. Gather essential fields such as names, ages and transaction details.
	2. segment customers into categories (VIP, Regular, New) and age groups.
	3. Aggregate customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan ( in months)
	4. calculates valuable KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend
===========================================================================
*/
IF OBJECT_ID( 'dbo.report_customers','V') IS NOT NULL
	DROP VIEW dbo.report_customers;
GO
CREATE VIEW dbo.report_customers AS 
-- Base query : Retrieve core columns from table
WITH base_query AS (
	SELECT 

		f.order_number,
		f.product_key,
		f.order_date,
		f.sales_amount,
		f.quantity,
		c.customer_key,
		c.customer_number,
		CONCAT(c.first_name,' ',c.last_name) AS customer_name,
		DATEDIFF(year,c.birthdate, GETDATE()) AS age
	FROM dbo.fact_sales f
	LEFT JOIN dbo.dim_customers c
	ON c.customer_key = f.customer_key
	WHERE order_date IS NOT NULL
) , customer_agrregations AS (
/*---------------------------------------------------------------------------
 Customer Aggregations: Summarizes key metrics at the customer level
---------------------------------------------------------------------------*/
	SELECT
		customer_key,
		customer_number,
		customer_name,
		age,
		CASE 
			WHEN age < 20 THEN 'Below 20'
			WHEN age BETWEEN 20 AND 29 THEN '20-29'
			WHEN age BETWEEN 30 AND 39 THEN '30-39'
			WHEN age BETWEEN 40 AND 49 THEN '40-49'
			ELSE '50 and above'
		END AS age_group,
		COUNT(DISTINCT order_number) AS total_orders,
		COUNT( DISTINCT product_key) AS total_products,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		MAX(order_date) AS last_order,
		DATEDIFF(month,MIN(order_date) , MAX(order_date)) AS lifespan
	FROM base_query
	GROUP BY customer_key,
       		 customer_number,
			 customer_name,
			 age
)
SELECT 
	customer_key,
    customer_number,
    customer_name,
	age,
    age_group,
	CASE 
	    WHEN lifespan >=12 AND total_sales >5000 THEN 'VIP'
		WHEN lifespan >=12 AND total_sales <=5000 THEN 'Regular'
		ELSE 'New'
	END AS segmentation,
    total_orders,
    total_products,
    total_sales,
    total_quantity,
	last_order,
	lifespan,
	DATEDIFF(month, last_order, GETDATE()) AS recency,
	-- Compuate average order value (AVO)
	CASE 
		WHEN total_sales = 0 THEN 0
		ELSE total_sales/total_orders 
	END AS avg_order_value,
	-- Compuate average monthly spend
	CASE 
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales/lifespan
	END AS avg_monthly_order
FROM customer_agrregations

/*
===============================================================================
Product Report
===============================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers (unique)
       - lifespan (in months)
    4. Calculates valuable KPIs:
       - recency (months since last sale)
       - average order revenue (AOR)
       - average monthly revenue
===============================================================================
*/
-- =============================================================================
-- Create Report: dbo.report_products
-- =============================================================================
IF OBJECT_ID('dbo.report_products','V') IS NOT NULL
	DROP VIEW dbo.report_products;
GO

CREATE VIEW dbo.report_products AS
	WITH base_query AS (
		SELECT 
			p.product_key,
			p.category,
			p.subcategory,
			p.product_name,
			p.cost,
			f.order_number,
			f.customer_key,
			f.order_date,
			f.sales_amount,
			f.quantity
		FROM dbo.fact_sales f
		LEFT JOIN dbo.dim_products p
		ON f.product_key = p.product_key
		WHERE order_date IS NOT NULL
	), product_aggregations AS (
/*---------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
---------------------------------------------------------------------------*/
		SELECT 
			product_key,
			category,
			subcategory,
			product_name,
			cost,
			COUNT(DISTINCT order_number) AS total_orders,
			SUM(sales_amount) AS total_sales,
			SUM(quantity) AS total_quantity,
			SUM(DISTINCT customer_key) AS total_customers,
			MAX(order_date) AS last_order,
			DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
			ROUND(AVG(CAST(sales_amount AS FLOAT)/NULLIF(quantity,0)),1) AS avg_selling_price
		FROM base_query
		GROUP BY 
			   product_key,
			   category,
			   subcategory,
			   product_name,
			   cost
	)
/*---------------------------------------------------------------------------
  3) Final Query: Combines all product results into one output
---------------------------------------------------------------------------*/
	SELECT
		product_key,
		category,
		subcategory,
		product_name,
		total_orders,
		total_sales,
		total_quantity,
		total_customers,
		last_order,
		lifespan,
		DATEDIFF(month, last_order, GETDATE()) AS recency,
		avg_selling_price,
		CASE 
			WHEN total_sales >50000 THEN 'High performer'
			WHEN total_sales <10000 THEN 'Mid range'
			ELSE 'Low performer'
		END AS product_segment,
	-- Average Order Revenue (AOR)
		CASE 
			WHEN total_orders=0 THEN 0
			ELSE total_sales/total_orders 
		END AS avg_order_revenue,
		-- Average Monthly Revenue
		CASE 
			WHEN lifespan =0 THEN total_sales
			ELSE total_sales/lifespan
		END AS avg_monthly_revenue
	FROM product_aggregations
