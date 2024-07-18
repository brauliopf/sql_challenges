/*
Q1: You have two tables:
'response_times' with columns (request_id, response_time_ms, device_type_id) and
'device_types' with columns (device_type_id, device_name, manufacturer).
Write a query to calculate the 95th percentile of response times for each device manufacturer.
*/

-- get response times for each device manufacturer
WITH maufacturer_times AS (
    SELECT d.manufacturer, r.response_time_ms
    FROM response_times r
    JOIN device_types d
    ON r.device_type_id = d.device_type_id
    ORDER BY d.manufacturer, r.response_time_ms;
)

-- get the 95th percentile of response times for each device manufacturer
SELECT manufacturer, PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms) AS percentile_95
FROM maufacturer_times;

/*
Q2: Given a table 'daily_visits' with columns (visit_date, visit_count),
write a query to calculate the 7-day moving average of daily visits for each date.
*/
SELECT visit_date, AVG(visit_count) OVER (ORDER BY visit_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg

/*
Q3: Given a table 'stock_prices' with columns (date, stock_symbol, closing_price).
What's the cumulative change in stock price compared to the starting price of the year?
*/

-- Assume the starting price of the year is the closing price on the first date in the table
-- Get initial value with FIRST_VALUE window function and current value with LAST_VALUE
WITH reference_prices AS (
    SELECT
        stock_symbol,
        FIRST_VALUE(closing_price) OVER (PARTITION BY stock_symbol ORDER BY date ASC) AS initial_price,
        LAST_VALUE(closing_price) OVER (PARTITION BY stock_symbol ORDER BY date ASC) AS initial_price
    FROM stock_prices
)
-- calculate changes
SELECT stock_symbol,
    (closing_price - initial_price) AS cumulative_change,
    IF(closing_price = initial_price, 0, (closing_price - initial_price) / closing_price AS cumulative__relative_change
FROM reference_prices;

/*
Q4: You have two tables:
'products' with columns (product_id, product_name, category_id, price) and
'categories' with columns (category_id, category_name).
What is the price difference between each product and the next most expensive product in that category?
*/
-- List products per category and order by price
WITH ranked_products AS (
    SELECT
        category_id, product_id, product_name, price
    FROM products
    ORDER BY category_id, price ASC
),

-- Use window function LEAD to calculate price differences within categories
ranked_with_next_price AS (
    SELECT
    category_id, product_id, product_name, price,
    LEAD(price) OVER (PARTITION BY category_id ORDER BY price ASC) AS next_price
    FROM ranked_products;
)

SELECT category_id, product_id, product_name, price, next_price, next_price - price AS price_difference
FROM ranked_with_next_price;

/*
Q5: Given a table 'customer_spending' with columns (customer_id, total_spend),
how would you divide customers into 10 deciles based on their total spending?
*/
-- use the window function NTILE
SELECT customer_id, total_spend,
    NTILE(10) OVER (ORDER BY total_spend ASC) AS decile
FROM customer_spending;

/*
Q6: Using a table 'daily_active_users' with columns (activity_date, user_count),
write a query to calculate the day-over-day change in user count and the growth rate.
*/
SELECT
    activity_date, user_count,
    user_count - LAG(user_count) OVER (ORDER BY activity_date ASC) AS daily_change,
    (user_count - LAG(user_count) OVER (ORDER BY activity_date ASC)) / LAG(user_count) OVER (ORDER BY activity_date ASC) AS growth_rate
FROM daily_active_users;

/*
Q7: Given a table 'sales' with columns (sale_id, sale_date, amount), how would you calculate:
the total sales amount for each day of the current month, along with a running total of month-to-date sales?
*/
-- Get sales data form current month with DATE_PART
WITH sales_current_month AS (
    SELECT
        sale_id, sale_date,
        amount AS daily_sales
    FROM sales
    WHERE DATE_PART('month', sale_date) = DATE_PART('month', CURRENT_DATE)
    ORDER BY sale_date ASC
)

SELECT
    sale_date, daily_sales,
    SUM(daily_sales) OVER (ORDER BY sale_date ASC
                            ROWS BETWEEN UNBOUNDED PRECEDING
                            AND CURRENT ROW) AS month_to_date_sales
FROM sales_current_month;

/*
Q8: You have two tables
'employee_sales' with columns (employee_id, department_id, sales_amount) and
‘employees’ with columns (employee_id, employee_name),
write a query to identify the top 5 employees by sales amount in each department.
*/

SELECT
    es.department_id,
    RANK() OVER (PARTITION BY es.department_id ORDER BY es.sales_amount DESC) AS sales_rank,
    e.employee_name, es.sales_amount
FROM employee_sales es
LEFT JOIN employees e
ON es.employee_id = e.employee_id

/*
Q9: Using a table 'employee_positions' with columns (employee_id, position, start_date, end_date),
write a query to find employees who have been promoted (i.e., changed to a different position) within 6 months of their initial hire.
*/

-- Use a self-join to connect rows with the same employee_id and different positions. call the LEFT before_job and the RIGHT after_job
-- filter out rows where the difference between start_date of before_job and end_date of after_job is more than 6 months
SELECT
    before_job.employee_id, before_job.position AS initial_position, before_job.start_date AS hire_date,
    after_job.position AS promoted_position, after_job.start_date AS promotion_date
FROM employee_positions before_job
JOIN employee_positions after_job
ON before_job.employee_id = after_job.employee_id
AND
    DATE_PART('year', after_job.start_date) - DATE_PART('year', before_job.start_date)*12 +
    DATE_PART('month', after_job.start_date) - DATE_PART('month', before_job.start_date) <= 6;

/*
Q10: You have two tables:
'customer_transactions' with columns (customer_id, transaction_date, transaction_amount), and
'customer_info' with columns (customer_id, customer_name, signup_date).
Write a query to calculate the moving average of transaction amounts for each customer
over their last 3 transactions, but only for customers who have been signed up for more than a year.
*/

-- order transactions by customer_id and date
WITH customer_transactions_asc AS (SELECT * FROM customer_transactions ORDER BY customer_id, transaction_date ASC)

SELECT
    t.customer_id, t.transaction_date, t.transaction_amount,
    SUM(t.transaction_amount) OVER (PARTITION BY t.customer_id ORDER BY t.transaction_date ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_sum,
    AVG(t.transaction_amount) OVER (PARTITION BY t.customer_id ORDER BY t.transaction_date ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg
FROM customer_transactions_asc AS t
JOIN customer_info AS i
ON t.customer_id = i.customer_id
WHERE DATE_PART('year', i.signup_date) - DATE_PART('year', CURRENT_DATE) > 0;