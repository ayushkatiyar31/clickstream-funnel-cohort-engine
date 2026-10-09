-- =========================================================
-- Block A: Cohort helper tables
-- =========================================================

CREATE OR REPLACE TABLE user_cohort AS
SELECT
    user_id,
    DATE_TRUNC('week', MIN(event_time))::DATE AS cohort_week
FROM stg_events
GROUP BY 1;


CREATE OR REPLACE TABLE user_week_activity AS
SELECT
    user_id,
    DATE_TRUNC('week', event_time)::DATE AS activity_week,
    MAX((event_type = 'purchase')::INT) AS bought
FROM stg_events
GROUP BY 1, 2;




-- =========================================================
-- Block B: Weekly cohort retention mart
-- =========================================================

CREATE OR REPLACE TABLE mart_cohort_weekly AS
WITH bounds AS (
    SELECT
        (SELECT MIN(cohort_week) FROM user_cohort) AS first_week,
        (SELECT MAX(activity_week) FROM user_week_activity) AS last_week
),

cohort_size AS (
    SELECT
        cohort_week,
        COUNT(*) AS cohort_users
    FROM user_cohort
    GROUP BY 1
),

joined AS (
    SELECT
        u.cohort_week,
        a.activity_week,
        DATE_DIFF(
            'week',
            u.cohort_week,
            a.activity_week
        ) AS week_number,
        a.user_id,
        a.bought
    FROM user_cohort u
    JOIN user_week_activity a USING (user_id)
)

SELECT
    j.cohort_week,
    j.week_number,
    c.cohort_users,
    COUNT(*) AS active_users,
    SUM(j.bought) AS purchasing_users,

    ROUND(
        100.0 * COUNT(*) / c.cohort_users,
        2
    ) AS retention_pct,

    ROUND(
        100.0 * SUM(j.bought) / c.cohort_users,
        2
    ) AS purchase_retention_pct,

    (j.cohort_week = b.first_week) AS is_baseline_cohort,

    (
        j.activity_week IN (b.first_week, b.last_week)
    ) AS is_partial_week

FROM joined j
JOIN cohort_size c USING (cohort_week)
CROSS JOIN bounds b

GROUP BY
    j.cohort_week,
    j.activity_week,
    j.week_number,
    c.cohort_users,
    b.first_week,
    b.last_week

ORDER BY 1, 2;




-- =========================================================
-- Block C: Week-1 retention by first known category
-- =========================================================

CREATE OR REPLACE TABLE mart_retention_by_first_category AS

WITH first_cat AS (
    SELECT
        user_id,
        category_l1 AS first_category
    FROM stg_events
    WHERE category_l1 <> 'unknown'
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY user_id
        ORDER BY event_time, product_id, event_type
    ) = 1
),

eligible AS (
    SELECT user_id
    FROM user_cohort
    WHERE cohort_week > (
        SELECT MIN(cohort_week) FROM user_cohort
    )
    AND cohort_week + 7 <= (
        SELECT MAX(cohort_week) FROM user_cohort
    )
),

week1 AS (
    SELECT a.user_id
    FROM user_week_activity a
    JOIN user_cohort u USING (user_id)
    WHERE DATE_DIFF(
        'week',
        u.cohort_week,
        a.activity_week
    ) = 1
)

SELECT
    f.first_category,
    COUNT(*) AS users,
    COUNT(w.user_id) AS retained_week1,
    ROUND(
        100.0 * COUNT(w.user_id) / COUNT(*),
        2
    ) AS week1_retention_pct
FROM first_cat f
JOIN eligible e USING (user_id)
LEFT JOIN week1 w USING (user_id)
GROUP BY 1
HAVING COUNT(*) >= 1000
ORDER BY week1_retention_pct DESC;