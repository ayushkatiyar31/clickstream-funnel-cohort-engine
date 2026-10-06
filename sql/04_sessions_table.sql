CREATE OR REPLACE TABLE sessions AS
SELECT
    session_id, user_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end,
    COUNT(*)                                        AS n_events,
    COUNT(*) FILTER (WHERE event_type='view')       AS n_views,
    COUNT(*) FILTER (WHERE event_type='cart')       AS n_carts,
    COUNT(*) FILTER (WHERE event_type='purchase')   AS n_purchases,
    COALESCE(SUM(price) FILTER (WHERE event_type='purchase'), 0) AS revenue
FROM events_sessionized
GROUP BY 1, 2;