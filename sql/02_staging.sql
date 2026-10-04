CREATE OR REPLACE TABLE stg_events AS
SELECT DISTINCT
    event_time, event_type, product_id, category_id,
    coalesce(lower(category_code), 'unknown')                              AS category_code,
    coalesce(nullif(split_part(lower(category_code), '.', 1), ''), 'unknown') AS category_l1,
    coalesce(nullif(split_part(lower(category_code), '.', 2), ''), 'unknown') AS category_l2,
    coalesce(brand, 'unknown')                                             AS brand,
    price, user_id, user_session
FROM read_parquet('data/parquet/events_20pct.parquet')
WHERE price > 0;