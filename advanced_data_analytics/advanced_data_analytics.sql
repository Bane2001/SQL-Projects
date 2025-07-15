--sales performance over time - by year
select
year(order_date) as order_year,
sum(sales_amount) as total_sales,
count(distinct customer_key) nu_of_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null
group by year(order_date)
order by year(order_date)

--sales performance over time - by month
select
year(order_date) as order_year,
month(order_date) as order_month,
sum(sales_amount) as total_sales,
count(distinct customer_key) nu_of_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null
group by year(order_date), month(order_date)
order by year(order_date), month(order_date)

select
DATETRUNC(month, order_date) as order_date,
sum(sales_amount) as total_sales,
count(distinct customer_key) nu_of_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null
group by DATETRUNC(month, order_date)
order by DATETRUNC(month, order_date)

--if format function is used, then it can not be sorted corectly
select
format(order_date, 'yyyy-MMM') as order_date,
sum(sales_amount) as total_sales,
count(distinct customer_key) nu_of_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null
group by format(order_date, 'yyyy-MMM')
order by format(order_date, 'yyyy-MMM')

--calculate the total sales per month
--and running total of sales over time for each year
select
sale_date,
total_sale,
sum(total_sale) over(partition by year(sale_date) order by sale_date) as running_total
from (
	select 
	DATETRUNC(month, order_date) as sale_date,
	SUM(sales_amount) as total_sale
	from gold.fact_sales
	where order_date is not null
	group by DATETRUNC(month, order_date)
)t

--performance analysis
/*analyse yearly performance of products by comparing their sales
  to both the average sales performance of the product and the previous year's sales*/
with yearly_product_sale as (
	select
	year(f.order_date) as sales_year,
	p.product_name as product_name,
	sum(f.sales_amount) as current_sales
	from gold.fact_sales as f
	left join gold.dim_products as p
	on f.product_key = p.product_key
	where f.order_date is not null
	group by year(f.order_date),p.product_name
)
select
sales_year,
product_name,
current_sales,
avg(current_sales) over(partition by product_name) as avg_sales,
current_sales - avg(current_sales) over(partition by product_name) as dif_average,
case when current_sales - avg(current_sales) over(partition by product_name) > 0 then 'Above Average'
	 when current_sales - avg(current_sales) over(partition by product_name) < 0 then 'Below Average'
	 else 'Average'
end as avg_change,
--year over year
lag(current_sales) over(partition by product_name order by sales_year) as py_sales,
current_sales - lag(current_sales) over(partition by product_name order by sales_year) as py_diff,
case when current_sales - lag(current_sales) over(partition by product_name order by sales_year) > 0 then 'Increase'
	 when current_sales - lag(current_sales) over(partition by product_name order by sales_year) < 0 then 'Decrease'
	 else 'No Change'
end as py_change
from yearly_product_sale
order by product_name, sales_year

--part to whole analysis
--which categories contribute the most to overall sales
with category_sales as (
	select
	p.category as category_name,
	sum(sales_amount) as tottal_sales_product
	from gold.fact_sales as f
	left join gold.dim_products as p
	on f.product_key = p.product_key
	group by p.category
)
select
category_name,
tottal_sales_product,
sum(tottal_sales_product) over() as total_sale,
concat(round((cast(tottal_sales_product as float) / sum(tottal_sales_product) over()) * 100, 2), '%') as procentage
from category_sales
order by tottal_sales_product

--data segmentation
/*segment product in to cost ranges and
  count how many products fall in to each segment*/
with total_products as (
	select
	product_key,
	product_name,
	cost,
	case when cost < 100 then 'Bellow 100'
		 when cost between 100 and 500 then '100-500'
		 when cost between 500 and 1000 then '500-1000'
		 else 'above 1000'
	end cost_range
	from gold.dim_products
)
select
cost_range,
count(product_key) as t_products
from total_products
group by cost_range
order by t_products desc

/*group customers into three segmemnts based on their spending behavior:
	-VIP: Customers with at least 12 month of history and spending more than $5000
	-Regular: Customers with at least 12 month of history and spending less than $5000
	- New: Customers with less than 12 month of history
*/
with customer_segment as (
select
	c.customer_key,
	c.first_name,
	sum(f.sales_amount) as total_spending,
	min(f.order_date) as first_order,
	max(f.order_date) as last_order,
	--datediff(month, max(f.order_date), min(f.order_date)) as nu_month
	datediff(month, min(f.order_date), max(f.order_date)) as nu_month
	from gold.fact_sales as f
	left join gold.dim_customers as c
	on f.customer_key = c.customer_key
	group by c.customer_key, c.first_name
)
select
customer_grade,
count(customer_key) as total_customer
from (
	select
	customer_key,
	case when nu_month >= 12 and total_spending >= 5000 then 'VIP'
		 when nu_month >= 12 and total_spending < 5000 then 'Regular'
		 else 'New'
	end as customer_grade
	from customer_segment
	--order by nu_month desc
)t
group by customer_grade

/*
==============================================================================
Customer Report
==============================================================================
Purpose:
	-This report consolidates key customer metrics and behaviors

Higlights:
	1. Gathers essential fields such as: names, ages and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Agregates customer-level metrics:
		-total orders
		-total sales
		-total quantity purchased
		-total products
		-purchasing lifespan (month)
	4. Calculate valuable KPI's"
		-recency (month since last order)
		-average order value
		-average monthly spend
=================================================================================
*/
/*---------------------------------------------
Base Query: retrives core columns from tables
*/---------------------------------------------
with base_query as (
/*---------------------------------------------
Base Query: retrives core columns from tables
*/---------------------------------------------
	select
		f.order_number,
		f.product_key,
		f.order_date,
		f.sales_amount,
		f.quantity,
		c.customer_key,
		c.customer_number,
		concat(c.first_name, ' ', c.last_name) as customer_name,
		datediff(year, c.birthdate, getdate()) as age
	from gold.fact_sales as f
	left join gold.dim_customers as c
	on f.customer_key = c.customer_key
	where order_date is not null

/*
Agregates customer-level metrics:
		-total orders
		-total sales
		-total quantity purchased
		-total products
		-purchasing lifespan (month)
*/
), customer_aggregation as (
	select
		customer_key,
		customer_number,
		customer_name,
		age,
		count(distinct order_number) as total_orders,
		sum(sales_amount) as total_sales,
		sum(quantity) as total_quantity,
		count(distinct product_key) as total_products,
		max(order_date) as last_order_date,
		datediff(month, min(order_date), max(order_date)) as lifespan_months
	from base_query
	group by 
		customer_key,
		customer_number,
		customer_name,
		age
)
select
	customer_key,
	customer_number,
	customer_name,
	age,
	case when age < 20 then 'bellow 20'
		 when age between 20 and 29 then 'bellow 30'
		 when age between 30 and 39 then 'bellow 40'
		 when age between 40 and 49 then 'bellow 50'
		 when age between 50 and 59 then 'bellow 60'
		 else 'above 60'
	end as age_grade,
	case when lifespan_months >= 12 and total_sales >= 5000 then 'VIP'
			 when lifespan_months >= 12 and total_sales < 5000 then 'Regular'
			 else 'New'
	end as customer_grade,
	last_order_date,
	datediff(month, last_order_date, getdate()) as recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	lifespan_months,
	--compute average orsder value (AVO)
	case when total_sales = 0 then 0
		 else total_sales / total_orders
		 end as avg_order_value,
	--compute average monthly spend
	case when lifespan_months = 0 then total_sales
		 else total_sales / lifespan_months
	end as avg_monthly_spend
from customer_aggregation