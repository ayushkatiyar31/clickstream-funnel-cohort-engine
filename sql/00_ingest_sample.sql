SET TimeZone = 'UTC';
COPY (
    SELECT
        event_time::TIMESTAMP AS event_time,
        event_type, product_id, category_id,
        category_code, brand, price, user_id, user_session
    FROM read_csv('data/raw/2019-*.csv', header = true)
    WHERE hash(user_id) % 5 = 0
) TO 'data/parquet/events_20pct.parquet'
  (FORMAT PARQUET, COMPRESSION ZSTD);
  