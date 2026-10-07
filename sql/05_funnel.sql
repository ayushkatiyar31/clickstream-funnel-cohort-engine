CREATE OR REPLACE TABLE session_stages AS
SELECT
    session_id,
    user_id,
    MIN(event_time) FILTER (WHERE event_type = 'view') AS first_view,
    MIN(event_time) FILTER (WHERE event_type = 'cart') AS first_cart,
    MIN(event_time) FILTER (WHERE event_type = 'purchase') AS first_purchase
FROM events_sessionized
GROUP BY 1, 2;



CREATE OR REPLACE TABLE mart_funnel_overall AS
WITH counts AS (
    SELECT
        'loose' AS funnel_type,
        1 AS step,
        'view' AS stage,
        COUNT(*) FILTER (WHERE first_view IS NOT NULL) AS n_sessions
    FROM session_stages

    UNION ALL

    SELECT
        'loose',
        2,
        'cart',
        COUNT(*) FILTER (WHERE first_cart IS NOT NULL)
    FROM session_stages

    UNION ALL

    SELECT
        'loose',
        3,
        'purchase',
        COUNT(*) FILTER (WHERE first_purchase IS NOT NULL)
    FROM session_stages

    UNION ALL

    SELECT
        'strict',
        1,
        'view',
        COUNT(*) FILTER (WHERE first_view IS NOT NULL)
    FROM session_stages

    UNION ALL

    SELECT
        'strict',
        2,
        'cart',
        COUNT(*) FILTER (WHERE first_view <= first_cart)
    FROM session_stages

    UNION ALL

    SELECT
        'strict',
        3,
        'purchase',
        COUNT(*) FILTER (
            WHERE first_view <= first_cart
              AND first_cart <= first_purchase
        )
    FROM session_stages
)
SELECT
    *,
    ROUND(
        100.0 * n_sessions /
        LAG(n_sessions) OVER (
            PARTITION BY funnel_type
            ORDER BY step
        ),
        2
    ) AS step_conv_pct,

    ROUND(
        100.0 * n_sessions /
        FIRST_VALUE(n_sessions) OVER (
            PARTITION BY funnel_type
            ORDER BY step
        ),
        2
    ) AS cum_conv_pct
FROM counts;



CREATE OR REPLACE TABLE mart_funnel_category AS
WITH sc AS (
    SELECT
        session_id,
        category_l1,
        MAX((event_type = 'view')::INT) AS v,
        MAX((event_type = 'cart')::INT) AS c,
        MAX((event_type = 'purchase')::INT) AS p
    FROM events_sessionized
    GROUP BY 1, 2
),
agg AS (
    SELECT
        category_l1,
        SUM(v) AS view_sessions,
        SUM(v * c) AS cart_sessions,
        SUM(v * c * p) AS purchase_sessions
    FROM sc
    GROUP BY 1
)
SELECT
    *,
    ROUND(100.0 * cart_sessions / NULLIF(view_sessions, 0), 2) AS view_to_cart_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(cart_sessions, 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(view_sessions, 0), 2) AS view_to_purchase_pct
FROM agg;



-- =========================================================
-- Block D: Brand funnel
-- =========================================================

CREATE OR REPLACE TABLE mart_funnel_brand AS
WITH sc AS (
    SELECT
        session_id,
        brand,
        MAX((event_type = 'view')::INT) AS v,
        MAX((event_type = 'cart')::INT) AS c,
        MAX((event_type = 'purchase')::INT) AS p
    FROM events_sessionized
    WHERE brand <> 'unknown'
    GROUP BY 1, 2
),
agg AS (
    SELECT
        brand,
        SUM(v) AS view_sessions,
        SUM(v * c) AS cart_sessions,
        SUM(v * c * p) AS purchase_sessions
    FROM sc
    GROUP BY 1
)
SELECT *,
    ROUND(100.0 * cart_sessions / NULLIF(view_sessions, 0), 2) AS view_to_cart_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(cart_sessions, 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(view_sessions, 0), 2) AS view_to_purchase_pct
FROM agg
ORDER BY view_sessions DESC
LIMIT 30;



-- =========================================================
-- Block E: Price band funnel
-- =========================================================

CREATE OR REPLACE TABLE dim_price_band AS
WITH prod AS (
    SELECT
        product_id,
        MEDIAN(price) AS price
    FROM stg_events
    GROUP BY 1
)
SELECT
    product_id,
    price,
    NTILE(5) OVER (ORDER BY price) AS price_band
FROM prod;


CREATE OR REPLACE TABLE mart_funnel_priceband AS
WITH sc AS (
    SELECT
        e.session_id,
        b.price_band,
        MAX((e.event_type = 'view')::INT) AS v,
        MAX((e.event_type = 'cart')::INT) AS c,
        MAX((e.event_type = 'purchase')::INT) AS p
    FROM events_sessionized e
    JOIN dim_price_band b USING (product_id)
    GROUP BY 1, 2
),
agg AS (
    SELECT
        price_band,
        SUM(v) AS view_sessions,
        SUM(v * c) AS cart_sessions,
        SUM(v * c * p) AS purchase_sessions
    FROM sc
    GROUP BY 1
),
rng AS (
    SELECT
        price_band,
        MIN(price) AS min_price,
        MAX(price) AS max_price,
        COUNT(*) AS n_products
    FROM dim_price_band
    GROUP BY 1
)
SELECT
    agg.*,
    rng.min_price,
    rng.max_price,
    rng.n_products,
    ROUND(100.0 * cart_sessions / NULLIF(view_sessions, 0), 2) AS view_to_cart_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(cart_sessions, 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(view_sessions, 0), 2) AS view_to_purchase_pct
FROM agg
JOIN rng USING (price_band)
ORDER BY price_band;


-- =========================================================
-- Block F: Hour and day-of-week funnel
-- =========================================================

CREATE OR REPLACE TABLE mart_funnel_hour AS
SELECT *,
    ROUND(100.0 * cart_sessions / NULLIF(view_sessions, 0), 2) AS view_to_cart_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(cart_sessions, 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(view_sessions, 0), 2) AS view_to_purchase_pct
FROM (
    SELECT
        EXTRACT(hour FROM session_start)::INT AS hour_of_day,
        COUNT(*) AS n_sessions,
        COUNT(*) FILTER (WHERE n_views > 0) AS view_sessions,
        COUNT(*) FILTER (WHERE n_views > 0 AND n_carts > 0) AS cart_sessions,
        COUNT(*) FILTER (
            WHERE n_views > 0
              AND n_carts > 0
              AND n_purchases > 0
        ) AS purchase_sessions
    FROM sessions
    GROUP BY 1
)
ORDER BY hour_of_day;


CREATE OR REPLACE TABLE mart_funnel_dow AS
SELECT *,
    ROUND(100.0 * cart_sessions / NULLIF(view_sessions, 0), 2) AS view_to_cart_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(cart_sessions, 0), 2) AS cart_to_purchase_pct,
    ROUND(100.0 * purchase_sessions / NULLIF(view_sessions, 0), 2) AS view_to_purchase_pct
FROM (
    SELECT
        EXTRACT(isodow FROM session_start)::INT AS dow_num,
        dayname(MIN(session_start)) AS day_name,
        COUNT(*) AS n_sessions,
        COUNT(*) FILTER (WHERE n_views > 0) AS view_sessions,
        COUNT(*) FILTER (WHERE n_views > 0 AND n_carts > 0) AS cart_sessions,
        COUNT(*) FILTER (
            WHERE n_views > 0
              AND n_carts > 0
              AND n_purchases > 0
        ) AS purchase_sessions
    FROM sessions
    GROUP BY 1
)
ORDER BY dow_num;




-- =========================================================
-- Block G: Session diagnostics
-- =========================================================

CREATE OR REPLACE TABLE mart_session_diagnostics AS
SELECT
    COUNT(*) AS n_sessions,
    ROUND(100.0 * AVG((s.n_events = 1)::INT), 2) AS bounce_pct,
    ROUND(AVG(s.n_events), 2) AS avg_events_per_session,
    MEDIAN(s.n_events) AS median_events_per_session,
    ROUND(
        AVG(
            date_diff('second', s.session_start, t.first_cart)
        ) / 60.0,
        2
    ) AS avg_min_to_first_cart,
    ROUND(
        MEDIAN(
            date_diff('second', s.session_start, t.first_cart)
        ) / 60.0,
        2
    ) AS median_min_to_first_cart
FROM sessions s
JOIN session_stages t USING (session_id);