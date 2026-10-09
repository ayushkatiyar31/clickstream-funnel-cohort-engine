-- =========================================================
-- Block A: RFM scores and customer segments
-- =========================================================

CREATE OR REPLACE TABLE mart_rfm AS

WITH ref AS (
    SELECT MAX(event_time)::DATE AS ref_date
    FROM stg_events
),

buyers AS (
    SELECT
        user_id,
        DATE_DIFF(
            'day',
            MAX(event_time)::DATE,
            (SELECT ref_date FROM ref)
        ) AS recency_days,
        COUNT(DISTINCT session_id) AS frequency,
        SUM(price) AS monetary
    FROM events_sessionized
    WHERE event_type = 'purchase'
    GROUP BY 1
),

cuts AS (
    SELECT
        quantile_cont(recency_days, [0.2, 0.4, 0.6, 0.8]) AS rc,
        quantile_cont(monetary, [0.2, 0.4, 0.6, 0.8]) AS mc
    FROM buyers
),

scored AS (
    SELECT
        b.*,

        CASE
            WHEN b.recency_days <= c.rc[1] THEN 5
            WHEN b.recency_days <= c.rc[2] THEN 4
            WHEN b.recency_days <= c.rc[3] THEN 3
            WHEN b.recency_days <= c.rc[4] THEN 2
            ELSE 1
        END AS r_score,

        CASE
            WHEN b.frequency = 1 THEN 1
            WHEN b.frequency = 2 THEN 2
            WHEN b.frequency <= 4 THEN 3
            WHEN b.frequency <= 7 THEN 4
            ELSE 5
        END AS f_score,

        CASE
            WHEN b.monetary <= c.mc[1] THEN 1
            WHEN b.monetary <= c.mc[2] THEN 2
            WHEN b.monetary <= c.mc[3] THEN 3
            WHEN b.monetary <= c.mc[4] THEN 4
            ELSE 5
        END AS m_score

    FROM buyers b
    CROSS JOIN cuts c
)

SELECT
    *,
    CASE
        WHEN r_score >= 4 AND f_score >= 3 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score <= 2 AND f_score >= 2 THEN 'At Risk'
        WHEN f_score >= 2 THEN 'Promising'
        WHEN r_score >= 3 THEN 'One-time recent'
        ELSE 'Hibernating'
    END AS segment
FROM scored;



-- =========================================================
-- Block B: Segment summary and top categories/brands
-- =========================================================

CREATE OR REPLACE TABLE mart_rfm_segment_summary AS
SELECT
    segment,
    COUNT(*) AS buyers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS buyer_pct,
    ROUND(SUM(monetary), 2) AS revenue,
    ROUND(
        100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (),
        2
    ) AS revenue_pct,
    ROUND(AVG(monetary), 2) AS avg_spend_per_buyer,
    ROUND(AVG(frequency), 2) AS avg_purchase_sessions,
    ROUND(SUM(monetary) / SUM(frequency), 2) AS aov_proxy,
    ROUND(AVG(recency_days), 1) AS avg_recency_days
FROM mart_rfm
GROUP BY 1
ORDER BY revenue DESC;


CREATE OR REPLACE TABLE mart_rfm_segment_category AS
WITH x AS (
    SELECT
        r.segment,
        e.category_l1,
        COUNT(*) AS items,
        ROUND(SUM(e.price), 2) AS revenue,
        ROW_NUMBER() OVER (
            PARTITION BY r.segment
            ORDER BY SUM(e.price) DESC
        ) AS rnk
    FROM events_sessionized e
    JOIN mart_rfm r USING (user_id)
    WHERE e.event_type = 'purchase'
      AND e.category_l1 <> 'unknown'
    GROUP BY 1, 2
)
SELECT *
FROM x
WHERE rnk <= 5
ORDER BY segment, rnk;


CREATE OR REPLACE TABLE mart_rfm_segment_brand AS
WITH x AS (
    SELECT
        r.segment,
        e.brand,
        COUNT(*) AS items,
        ROUND(SUM(e.price), 2) AS revenue,
        ROW_NUMBER() OVER (
            PARTITION BY r.segment
            ORDER BY SUM(e.price) DESC
        ) AS rnk
    FROM events_sessionized e
    JOIN mart_rfm r USING (user_id)
    WHERE e.event_type = 'purchase'
      AND e.brand <> 'unknown'
    GROUP BY 1, 2
)
SELECT *
FROM x
WHERE rnk <= 5
ORDER BY segment, rnk;
