# Data Dictionary

## Dataset summary

- **Source:** REES46 eCommerce Behavior Data (October–November 2019)
- **Sampling:** 20% of users using `hash(user_id) % 5 = 0`; all events for selected users are retained
- **Rows:** 21,923,857
- **Users:** 1,063,370
- **Sessions:** 4,582,775
- **Products:** 178,671
- **Date range:** 2019-10-01 to 2019-11-30
- **Event types:** view, cart, purchase

## Columns

| Column | Type | Meaning | NULL % | Notes |
|---|---|---|---:|---|
| `event_time` | TIMESTAMP | Date and time when the event occurred | 0% | Stored as UTC |
| `event_type` | VARCHAR | Type of user interaction | 0% | Values observed: view, cart, purchase |
| `product_id` | BIGINT | Unique identifier of the product | 0% | No NULL values |
| `category_id` | BIGINT | Unique identifier of the product category | 0% | No NULL values |
| `category_code` | VARCHAR | Hierarchical category name/code | 32.2% | Significant missing data |
| `brand` | VARCHAR | Product brand | 14.0% | Moderate missing data |
| `price` | DOUBLE | Product price at the time of the event | 0% | 50,675 rows have price <= 0 |
| `user_id` | BIGINT | Unique identifier of the user | 0% | No NULL values |
| `user_session` | VARCHAR | Identifier for a user's browsing session | 0% | Used for session-level analysis |

## Data quality findings

- **Event split:** 94.85% view, 3.62% cart, and 1.52% purchase events.
- **`category_code` NULL:** 32.2% of rows.
- **`brand` NULL:** 14.0% of rows.
- **Invalid/non-positive prices:** 50,675 rows have `price <= 0` (~0.23% of all events).
- **Exact duplicate rows:** 27,041 rows (~0.12% of all events).
- **Purchases without an earlier view/cart in the same session:** 1,437 out of 281,856 purchase sessions (~0.51%).
- **Date coverage:** Data spans 61 days from October 1 through November 30, 2019.
- **Daily event volume:** Event counts vary across the two months, with higher daily volumes observed toward late November. This is an observed pattern and is not automatically attributed to a specific business event.



## Cleaning log

The staging step applies the following cleaning rules:

- Exact duplicate rows are removed using `SELECT DISTINCT`.
- Rows with `price <= 0` are removed.
- NULL `category_code` values are replaced with `unknown`.
- NULL `brand` values are replaced with `unknown`.
- `category_code` is normalized to lowercase.
- Category levels are split into `category_l1` and `category_l2`.

### Cleaning results

| Metric | Result |
|---|---:|
| Raw rows | 21,923,857 |
| NULL price rows | 0 |
| Non-positive price rows | 50,675 |
| Rows after price filter | 21,873,182 |
| Rows in `stg_events` | 21,846,166 |
| Duplicate rows removed | 27,016 |
| Metric | Result |
|---|---:|
| Dataset sessions | 4,578,740 |
| Our sessions | 3,741,708 |
| Our sessions with 1 dataset session ID | 84.46% |
| Our sessions with multiple dataset IDs | 15.54% |


## Session definition
A session is a run of one user's events with no gap greater than 30 minutes.
Built with LAG → gap flag → running SUM (sql/03_sessionize.sql).
Sessions can cross midnight; they are not split by calendar day.

| Gap threshold | Sessions | vs 30 min |
|---|---:|---:|
| 15 min | 3,929,368 | +5.0% |
| 30 min | 3,741,708 | baseline |
| 60 min | 3,588,440 | -4.1% |

My sessions: **3,741,708**  
Dataset `user_session` IDs: **4,578,740**

Why they differ: The dataset provides its own `user_session` identifiers, but the exact rules used to generate them are not documented. This project uses a transparent 30-minute inactivity rule, so the two definitions can produce different session counts. A single dataset session may be split into multiple sessions under the 30-minute rule, while one of our sessions can contain multiple dataset session IDs. Neither definition is necessarily wrong; the project's definition is explicit, consistent, and reproducible for analysis.