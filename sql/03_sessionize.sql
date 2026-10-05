CREATE OR REPLACE TABLE events_sessionized AS
WITH lagged AS (
    SELECT *,
        LAG(event_time) OVER (
            PARTITION BY user_id
            ORDER BY event_time, product_id, event_type) AS prev_time
    FROM stg_events
),
flagged AS (
    SELECT *,
        CASE WHEN prev_time IS NULL
                  OR event_time - prev_time > INTERVAL 30 MINUTE
             THEN 1 ELSE 0 END AS new_session_flag
    FROM lagged
),
numbered AS (
    SELECT *,
        SUM(new_session_flag) OVER (
            PARTITION BY user_id
            ORDER BY event_time, product_id, event_type
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_num
    FROM flagged
)
SELECT *, user_id::VARCHAR || '_' || session_num::VARCHAR AS session_id
FROM numbered;