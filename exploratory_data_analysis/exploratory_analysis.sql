-- explore all objects in the database
-- explore tables
select * from INFORMATION_SCHEMA.TABLES

--explore columns
select * from INFORMATION_SCHEMA.COLUMNS
where  TABLE_NAME = 'dim_customers'

-- explore countres our customers come from
select 
distinct country
from gold.dim_customers

-- explore all product categories 
select
distinct category,
subcategory,
product_name
from gold.dim_products
order by 1, 2, 3

-- find the date of first and last order
-- how many years between first and last order
select
min(order_date) as first_order,
max(order_date) as last_rder,
datediff(year, min(order_date), max(order_date)) as time_range_years,
datediff(month, min(order_date), max(order_date)) as time_range_month,
datediff(day, min(order_date), max(order_date)) as time_range_days
from gold.fact_sales

--find the youngest and oldest customer
select
min(birthdate) as oldest_customer,
max(birthdate) as youngest_customer,
datediff(year, min(birthdate), max(birthdate)) as age_dif_young_and_old,
datediff(year, min(birthdate), getdate()) as age_of_oldest_customer,
datediff(year, max(birthdate), getdate()) as age_of_young_customer
from gold.dim_customers

--measure exploration
--find the total sales
select 
sum(sales_amount) as total_sales
from gold.fact_sales

--how many items are sold
select 
sum(quantity) as total_quantity
from gold.fact_sales

-- find average price
select 
format(avg(price), 'C', 'en-ca') as average_price
from gold.fact_sales

-- find the total number of orders
select 
count(order_number) as total_number_orders
from gold.fact_sales

select 
count(distinct order_number) as total_number_orders
from gold.fact_sales

--find total number of products
select 
count(product_id) as total_number_products
from gold.dim_products

--total number of customers
select 
format(count(distinct customer_id), '0,0') as total_number_customers
from gold.dim_customers

--find total number of customers that has placed an order
select 
count(distinct customer_key) as total_nu_cust_ord
from gold.fact_sales

-- generate report that shows all key metrics of the busines
select 'Total Sales' as measure_name, sum(sales_amount) as measure_value from gold.fact_sales
union all
select 'Total Quantity', sum(quantity) from gold.fact_sales
union all
select 'Average Price', avg(price) from gold.fact_sales
union all
select 'Total Nu of Orders', count(distinct order_number) from gold.fact_sales
union all
select 'Total nu of Products', count(product_id) from gold.dim_products
union all
select 'Total nu of Customers', count(distinct customer_id) from gold.dim_customers
union all
select 'Total nu of Customer Orders', count(distinct customer_key) from gold.fact_sales

--magnitude analysis
--total nu of customers by country
select 
country, 
count(customer_id) as nu_of_customers
from gold.dim_customers
group by country
order by nu_of_customers desc

--total nu of customers by gender
select 
gender,
count(customer_id) as nu_of_customers
from gold.dim_customers
group by gender
order by nu_of_customers desc

--total number of products by category
select
category,
count(product_id) as number_of_products
from gold.dim_products
group by category
order by number_of_products desc

--average cost for each category
select
category,
avg(cost) as average_per_category
from gold.dim_products
group by category
order by average_per_category desc

-- total raveenue for each category
select
p.category,
sum(s.sales_amount) as ravenue
from gold.dim_products as p
left join gold.fact_sales as s
on p.product_key = s.product_key
group by p.category
order by ravenue desc

-- total ravenue by customer
select
c.customer_key,
c.first_name,
c.last_name,
sum(f.sales_amount) as ravenue
from gold.fact_sales as f
left join gold.dim_customers as c
on f.customer_key = c.customer_key
group by 
c.customer_key,
c.first_name,
c.last_name
order by ravenue desc

--ravenue by country
select
c.country,
sum(f.sales_amount) as ravenue
from gold.fact_sales as f
left join gold.dim_customers as c
on f.customer_key = c.customer_key
group by c.country
order by ravenue desc

--total sold items by country
select
c.country,
sum(f.quantity) as nu_of_Items
from gold.fact_sales as f
left join gold.dim_customers as c
on f.customer_key = c.customer_key
group by c.country
order by nu_of_Items desc

--ranking
--which 5 products generate the highest ravenue
select * from (
	select
	p.product_name,
	sum(f.sales_amount) as ravenue,
	ROW_NUMBER() over(order by sum(f.sales_amount) desc) as rank_product
	from gold.fact_sales as f
	left join gold.dim_products as p
	on f.product_key = p.product_key
	group by p.product_name
)t where rank_product <= 5