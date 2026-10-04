SELECT
    COUNT(*)                                              AS raw_rows,
    COUNT(*) FILTER (WHERE price IS NULL)                 AS null_price_rows,
    COUNT(*) FILTER (WHERE price <= 0)                    AS nonpositive_price_rows,
    COUNT(*) FILTER (WHERE price > 0)                     AS rows_after_price_filter,
    (SELECT COUNT(*) FROM stg_events)                     AS rows_in_stg_events,
    COUNT(*) FILTER (WHERE price > 0) - (SELECT COUNT(*) FROM stg_events) AS duplicates_removed
FROM read_parquet('data/parquet/events_20pct.parquet');