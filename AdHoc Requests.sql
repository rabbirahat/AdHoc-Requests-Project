
-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT * FROM dim_customer;

SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region ='APAC';

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The
-- final output contains these fields,
--                  unique_products_2020
-- 					unique_products_2021
-- 					percentage_chg

SELECT count(DISTINCT product_code) AS unique_products_2021 
FROM fact_sales_monthly
WHERE fiscal_year = 2021;

SELECT count(DISTINCT product_code) AS unique_products_2020 
FROM fact_sales_monthly
WHERE fiscal_year = 2020;

WITH cte1 AS (
	SELECT count(DISTINCT product_code) AS unique_products_2021 
    FROM fact_sales_monthly
	WHERE fiscal_year = 2021
),

cte2 AS (
	SELECT count(DISTINCT product_code) AS unique_products_2020 
    FROM fact_sales_monthly
	WHERE fiscal_year = 2020
),

cte3 AS (
	SELECT unique_products_2021, unique_products_2020
	FROM cte1
	CROSS JOIN cte2
)

SELECT *, round(((unique_products_2021 - unique_products_2020)/unique_products_2020)*100, 2) AS percentage_chg 
FROM cte3;

-- (334 - 245)/ 245 = 0.3633 == 36.33 %

-- 3. Provide a report with all the unique product counts for each segment and
-- sort them in descending order of product counts. The final output contains 2 fields,
--               segment
--               product_count

SELECT segment, 
		count(DISTINCT product_code) AS product_count
		FROM dim_product
		GROUP BY segment
		ORDER BY product_count DESC;


-- 4. Follow-up: Which segment had the most increase in unique products in
-- 2021 vs 2020? The final output contains these fields,
-- 				segment
-- 				product_count_2020
-- 				product_count_2021
-- 				difference


SELECT count(DISTINCT product_code) AS unique_products_2021 
FROM fact_sales_monthly
WHERE fiscal_year = 2021;

SELECT count(DISTINCT product_code) AS unique_products_2020 
FROM fact_sales_monthly
WHERE fiscal_year = 2020;

SELECT	
	p.segment,
	count(DISTINCT CASE WHEN S.fiscal_year = 2020 THEN S.product_code END) AS product_count_2020, 
    count(DISTINCT CASE WHEN S.fiscal_year = 2021 THEN S.product_code END) AS product_count_2021,

	(count(DISTINCT CASE WHEN S.fiscal_year = 2021 THEN S.product_code END)-
    count(DISTINCT CASE WHEN S.fiscal_year = 2020 THEN S.product_code END)) AS difference
    
FROM dim_product AS p
LEFT JOIN fact_sales_monthly AS S ON p.product_code = S.product_code
WHERE S.fiscal_year IN (2020, 2021)
GROUP BY p.segment
ORDER BY difference DESC;


-- 5. Get the products that have the highest and lowest manufacturing costs.The final output should contain these fields,
-- 				product_code
-- 				product
-- 				manufacturing_cost

SELECT p.product_code, p.product, f.manufacturing_cost
FROM dim_product AS p
LEFT JOIN fact_manufacturing_cost AS f ON p.product_code = f.product_code
WHERE manufacturing_cost = (SELECT max(manufacturing_cost) 
							FROM fact_manufacturing_cost)

UNION

SELECT p.product_code, p.product, f.manufacturing_cost
FROM dim_product AS p
LEFT JOIN fact_manufacturing_cost AS f ON p.product_code = f.product_code
WHERE manufacturing_cost = (SELECT min(manufacturing_cost) 
							FROM fact_manufacturing_cost);
                                

-- 6. Generate a report which contains the top 5 customers who received an
-- average high pre_invoice_discount_pct for the fiscal year 2021 and in the
-- Indian market. The final output contains these fields,
-- 			customer_code
-- 			customer
--  		average_discount_percentage
                                

WITH cte1 AS (
		SELECT a.customer_code, a.customer, a.market, b.fiscal_year, b.pre_invoice_discount_pct
        FROM dim_customer AS a
        JOIN fact_pre_invoice_deductions AS b
        ON a.customer_code = b.customer_code
),
cte2 as (
		SELECT
			customer_code,
			customer,
			market,
			fiscal_year,
            avg(pre_invoice_discount_pct) AS average_discount_pct
        FROM
			cte1
        WHERE
			fiscal_year = 2021 AND market = 'India'
        GROUP BY
			customer_code, customer, market, fiscal_year
)

SELECT customer_code, customer,round(average_discount_pct*100,2) AS average_discount_pct
FROM cte2
ORDER BY average_discount_pct DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer “Atliq
-- Exclusive” for each month. This analysis helps to get an idea of low and
-- high-performing months and take strategic decisions.
-- The final report contains these columns:
-- 		Month
-- 		Year
-- 		Gross sales Amount

-- Gross sales = Price * sold_quantity

WITH cte1 AS (
	SELECT a.customer_code, a.customer, b.date, b.product_code, b.fiscal_year, b.sold_quantity
    FROM dim_customer AS a
    JOIN fact_sales_monthly AS b
    ON a.customer_code = b.customer_code
    WHERE a.customer = 'Atliq Exclusive'
),
cte2 AS (
	SELECT a.customer_code, a.customer, a.date, a.product_code, a.fiscal_year, a.sold_quantity, b.gross_price 
	FROM cte1 AS a 
	JOIN fact_gross_price AS b
	ON a.product_code = b.product_code
)
SELECT monthname(date) AS Month,
	   fiscal_year AS Year,
	   round(sum(sold_quantity * gross_price)/1000000, 2) AS gross_sales_amt,
       'Millions' AS Unit
       FROM cte2
       GROUP BY monthname(date), fiscal_year;
        

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
-- output contains these fields sorted by the total_sold_quantity, Quarter, total_sold_quantity

-- Business year is starting from the month September 
-- Hence my year will start from september
-- hence, september to november will be my 1st quarter
-- , Dec to Feb will be my 2nd quarter
-- , Mar to May will be my 3rd quarter
-- , Jun to Aug will be my 4th quarter

SELECT * FROM fact_sales_monthly
WHERE fiscal_year IN (2020,2021);

SELECT CASE
			WHEN date BETWEEN '2019-09-01' AND '2019-11-01' THEN 1
            WHEN date BETWEEN '2019-12-01' AND '2020-02-01' THEN 2
            WHEN date BETWEEN '2020-03-01' AND '2020-05-01' THEN 3
            WHEN date BETWEEN '2020-06-01' AND '2020-08-01' THEN 4
            END AS Quarters,
            format(sum(sold_quantity), 0) AS total_sold_quantity
            FROM fact_sales_monthly
            WHERE fiscal_year = 2020
            GROUP BY Quarters
            ORDER BY total_sold_quantity DESC;


-- 9. Which channel helped to bring more gross sales in the fiscal year 2021
-- and the percentage of contribution? The final output contains these fields, channel, gross_sales_mln, percentage

-- pct contribution = (gross sales mon / total sales) * 100 

WITH cte1 AS (
	SELECT a.channel,
			b.product_code,
            b.fiscal_year,
            b.sold_quantity
    FROM dim_customer AS a
    JOIN fact_sales_monthly AS b
    ON a.customer_code = b.customer_code
    WHERE fiscal_year = 2021
),

cte2 AS (
	SELECT a.channel, a.product_code, a.sold_quantity, b.gross_price
	FROM cte1 AS a
	JOIN fact_gross_price AS b
	ON a.product_code = b.product_code
),

cte3 AS (
	SELECT channel,
	round(sum(sold_quantity * gross_price)/1000000, 2) AS gross_sales_mln
	FROM cte2
	GROUP BY channel
)

SELECT channel, gross_sales_mln, round((gross_sales_mln/total_sales)*100, 2) AS pct_contrib
FROM cte3, (SELECT sum(gross_sales_mln) AS total_sales FROM cte3) AS total
ORDER BY gross_sales_mln DESC;

-- 10. Get the Top 3 products in each division that have a high
-- total_sold_quantity in the fiscal_year 2021? The final output contains these fields,
-- 			division
-- 			product_code
-- 			product
-- 			total_sold_quantity
-- 			rank_order

WITH cte1 AS (
	SELECT 
		a.division,
        a.product_code,
        a.product,
        sum(b.sold_quantity) AS total_sold_quantity
	FROM dim_product AS a
	JOIN fact_sales_monthly AS b
	ON a.product_code = b.product_code
    WHERE b.fiscal_year = 2021
    GROUP BY a.division, a.product_code, a.product
),

-- I need to show 3 top products per division, top products will be based on total sold quantity

cte2 AS (
	SELECT *,
		rank() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) as `rank`
        FROM cte1
) 

SELECT * FROM cte2
WHERE `rank` <= 3;





