-- Step 9: Data Profiling
-- Clickstream Funnel & Cohort Engine
-- Dataset: 20% sample of October-November 2019 e-commerce events


-- 1. Size and date range
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT user_id) AS users,
    COUNT(DISTINCT user_session) AS sessions,
    COUNT(DISTINCT product_id) AS products,
    MIN(event_time) AS first_event,
    MAX(event_time) AS last_event
FROM 'data/parquet/events_20pct.parquet';


-- 2. Quick overview of every column
SUMMARIZE
SELECT *
FROM 'data/parquet/events_20pct.parquet';


-- 3. Event type split
SELECT
    event_type,
    COUNT(*) AS n,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS pct
FROM 'data/parquet/events_20pct.parquet'
GROUP BY 1
ORDER BY n DESC;


-- 4. NULL percentages
SELECT
    ROUND(
        100.0 * AVG((category_code IS NULL)::INT),
        1
    ) AS category_code_null_pct,
    ROUND(
        100.0 * AVG((brand IS NULL)::INT),
        1
    ) AS brand_null_pct
FROM 'data/parquet/events_20pct.parquet';


-- 5. Bad prices
SELECT
    COUNT(*) AS bad_price_rows
FROM 'data/parquet/events_20pct.parquet'
WHERE price <= 0;


-- 6. Exact duplicates
SELECT
    COUNT(*) AS total_rows,
    (
        SELECT COUNT(*)
        FROM (
            SELECT DISTINCT *
            FROM 'data/parquet/events_20pct.parquet'
        )
    ) AS distinct_rows
FROM 'data/parquet/events_20pct.parquet';


-- 7. Events per day
SELECT
    event_time::DATE AS day,
    COUNT(*) AS events
FROM 'data/parquet/events_20pct.parquet'
GROUP BY 1
ORDER BY 1;


-- 8. Purchases with no earlier view or cart
WITH s AS (
    SELECT
        user_session,
        MIN(event_time) FILTER (
            WHERE event_type = 'purchase'
        ) AS first_purchase,
        MIN(event_time) FILTER (
            WHERE event_type IN ('view', 'cart')
        ) AS first_view_cart
    FROM 'data/parquet/events_20pct.parquet'
    GROUP BY user_session
)
SELECT
    COUNT(*) FILTER (
        WHERE first_purchase IS NOT NULL
    ) AS purchase_sessions,
    COUNT(*) FILTER (
        WHERE first_purchase IS NOT NULL
          AND (
              first_view_cart IS NULL
              OR first_view_cart > first_purchase
          )
    ) AS purchases_without_earlier_view_or_cart
FROM s;