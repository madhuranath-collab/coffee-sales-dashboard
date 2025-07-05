--1.Coffee Consumers Count
--How many people in each city are estimated to consume coffee, given that 25% of the population does?

select *,round((0.25*cast(population as float)/1000000.0),2) as consumers_count_in_millions from city
order by round((0.25*population/1000000.0),2)desc

--2.Total Revenue from Coffee Sales
--What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

select ci.city_name,sum(s.total) as total_sales from sales s
join customers c
on s.customer_id=c.customer_id
join city ci
on c.city_id=ci.city_id
where datepart(quarter,sale_date)=4 and year(sale_date)=2023
group by ci.city_name
order by sum(s.total) desc

--3.Sales Count for Each Product
--How many units of each coffee product have been sold?
--no of orders fro each product

select p.product_name,count(s.sale_id) as total_orders
from products p
join sales s
on p.product_id=s.product_id
group by p.product_name
order by count(s.sale_id) desc

--4.Average Sales Amount per customer per City 
--What is the average sales amount per customer in each city?

select ci.city_name,count(distinct c.customer_id) as cx,round((sum(s.total)/count(distinct c.customer_id)),2) as avg_sale_pr_cx from sales s
join customers c
on s.customer_id=c.customer_id
join city ci
on c.city_id=ci.city_id
group by ci.city_name
order by (sum(s.total)/count(distinct c.customer_id)) desc

--5.City Population and Coffee Consumers
--Provide a list of cities along with their populations and estimated coffee consumers.
--return city_name,current_cx,estimated_consumers

select ci.city_name,round(sum(0.25*CAST(ci.population AS FLOAT)/1000000),2) as estimated_counsumers_in_millions,
count(distinct c.customer_id) as current_cx
from city ci
join customers c
on ci.city_id=c.city_id
join sales s
on c.customer_id=s.customer_id
group by ci.city_name
order by round(sum(0.25*ci.population/1000000),2) desc

--6.Top Selling Products by City
--What are the top 3 selling products in each city based on sales volume?

with cte as(select ci.city_name, p.product_name,count(s.sale_id) as total_orders,
DENSE_RANK() over(partition by ci.city_name order by count(s.sale_id) desc) as rank
from city ci
join customers c
on ci.city_id=c.city_id
join sales s
on c.customer_id=s.customer_id
join products p
on s.product_id=p.product_id
group by ci.city_name,p.product_name
)

select city_name,product_name,total_orders from cte
where rank<=3

--7.Customer Segmentation by City
--How many unique customers are there in each city who have purchased coffee products?

select ci.city_name,
count(distinct c.customer_id) as current_cx
from city ci
join customers c
on ci.city_id=c.city_id
join sales s
on c.customer_id=s.customer_id
where s.product_id>=1 and s.product_id<=10
group by ci.city_name

--8.Average Sale vs Rent
--Find each city and their average sale per customer and avg rent per customer

select ci.city_name,round((sum(s.total)/count(distinct c.customer_id)),2) as avg_sal_pr_cx,
round((ci.estimated_rent/count(distinct c.customer_id)),2) as avg_rent_pr_cx
from city ci
join customers c
on ci.city_id=c.city_id
join sales s
on c.customer_id=s.customer_id
group by ci.city_name,ci.estimated_rent
order by (sum(s.total)/count(distinct c.customer_id)) desc,(ci.estimated_rent/count(distinct c.customer_id))

--9.Monthly Sales Growth
--Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly).

WITH monthly_sales AS (
    SELECT 
        ci.city_name,
        MONTH(s.sale_date) AS month,
        YEAR(s.sale_date) AS year,
        SUM(s.total) AS total_sale
    FROM sales AS s
    JOIN customers AS c ON c.customer_id = s.customer_id
    JOIN city AS ci ON ci.city_id = c.city_id
    GROUP BY ci.city_name, YEAR(s.sale_date), MONTH(s.sale_date)
),
growth_ratio AS (
    SELECT
        city_name,
        month,
        year,
        total_sale AS cr_month_sale,
        LAG(total_sale, 1) OVER (
            PARTITION BY city_name 
            ORDER BY year, month
        ) AS last_month_sale
    FROM monthly_sales
)
SELECT
    city_name,
    month,
    year,
    cr_month_sale,
    last_month_sale,
    ROUND(
        CAST((cr_month_sale - last_month_sale) * 100.0 / NULLIF(last_month_sale, 0) AS decimal(10,2)), 
        2
    ) AS growth_ratio
FROM growth_ratio
WHERE last_month_sale IS NOT NULL;

--10.Market Potential Analysis
--Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer

WITH city_table AS (
    SELECT 
        ci.city_name,
        SUM(s.total) AS total_revenue,
        COUNT(DISTINCT s.customer_id) AS total_cx,
        ROUND(
            CAST(SUM(s.total) AS float) / 
            NULLIF(CAST(COUNT(DISTINCT s.customer_id) AS float), 0), 
        2) AS avg_sale_pr_cx
    FROM sales AS s
    JOIN customers AS c ON s.customer_id = c.customer_id
    JOIN city AS ci ON ci.city_id = c.city_id
    GROUP BY ci.city_name
),
city_rent AS (
    SELECT 
        city_name, 
        estimated_rent,
        ROUND((CAST(population AS float) * 0.25) / 1000000, 3) AS estimated_coffee_consumer_in_millions
    FROM city
)
SELECT 
    cr.city_name,
    ct.total_revenue,
    cr.estimated_rent AS total_rent,
    ct.total_cx,
    cr.estimated_coffee_consumer_in_millions,
    ct.avg_sale_pr_cx,
    ROUND(
        CAST(cr.estimated_rent AS float) / 
        NULLIF(CAST(ct.total_cx AS float), 0), 
    2) AS avg_rent_per_cx
FROM city_rent AS cr
JOIN city_table AS ct ON cr.city_name = ct.city_name
ORDER BY ct.total_revenue DESC;


/*Recommendations

After analyzing the data, the recommended top three cities for new store openings are:

City 1: Pune

1.Average rent per customer is very low.
2.Highest total revenue.
3.Average sales per customer is also high.

City 2: Delhi

1.Highest estimated coffee consumers at 7.7 million.
2.Highest total number of customers, which is 68.
3.Average rent per customer is 330 (still under 500).

City 3: Jaipur

1.Highest number of customers, which is 69.
2.Average rent per customer is very low at 156.
3.Average sales per customer is better at 11.6k.
*/

