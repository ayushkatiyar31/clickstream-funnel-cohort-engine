# Metric Definitions

| Metric | Numerator | Denominator |
|---|---|---|
| Session | Events of one user with no gap > 30 min | n/a |
| Session conversion rate | Sessions with >= 1 purchase | All sessions |
| View→Cart rate | Sessions with a view AND a cart | Sessions with a view |
| Cart→Purchase rate | Sessions with a view AND cart AND purchase | Sessions with a view AND cart |
| View→Purchase rate | Same as above numerator | Sessions with a view |
| Cart abandonment | 1 - Cart→Purchase rate | |
| Bounce session | Sessions with exactly 1 event | All sessions |
| Revenue per session | Sum of purchase prices | All sessions |
| AOV (proxy) | Revenue | Sessions with a purchase |
| Time to first cart | Minutes from session start to first cart event | Sessions with a cart |

## Funnel rules
- Loose funnel: stage counts sessions that contain that event at all.
- Strict funnel: first_view <= first_cart <= first_purchase (ties allowed).
- Sliced funnels (category, brand, price band) are "nested": a session counts as
  a cart only if it also had a view in that slice, so rates never exceed 100%.
- A session can appear in several slices (see self-check), so slice counts must
  never be added together.
- Hour/weekday use session_start, so a session belongs to the hour it began.

## Treatment of purchases with no cart/view

The dataset contains sessions where a purchase occurs without a cart event
in the same session.

Observed results:

| Metric | Count |
|---|---:|
| Purchase sessions | 259,221 |
| Purchase sessions with no cart | 83,720 |
| Purchase sessions with no view | 926 |
| Cart after purchase | 4,734 |
| Cart with no view | 1,174 |

A likely explanation is the 30-minute sessionization rule. For example, a
user may view a product and add it to the cart, leave for more than 30 minutes,
and then return and purchase. The inactivity rule splits these events into
separate sessions.

These sessions are not automatically treated as invalid purchases.

Purchasing sessions are retained in the headline **session conversion rate**:

- Purchase sessions: 259,221
- All sessions: 3,741,708
- Session conversion rate: 6.93%

For the chronological funnel, sessions must follow:

**view → cart → purchase**

Therefore, sessions that cannot be placed into this sequence are excluded
from the **strict funnel**.

The resulting strict funnel conversion is **4.53%**, compared with **6.93%**
for the overall session purchase rate.

The two metrics answer different questions:

- **6.93% Session conversion rate:** What percentage of all sessions resulted
  in a purchase?
- **4.53% Strict funnel conversion:** What percentage of sessions progressed
  through the chronological view → cart → purchase funnel?

This distinction preserves observed purchase activity while maintaining a
logically ordered funnel for customer-journey analysis.

## RFM Analysis

- **Reference date:** The maximum event date in the dataset, 2019-11-30.
- **Recency:** Number of days between a buyer's most recent purchase and the reference date. A lower value means a more recent purchase.
- **Frequency:** Number of distinct purchase sessions per buyer.
- **Monetary:** Sum of purchase-event prices per buyer. This is not adjusted for quantity, discounts, or refunds.
- **R score:** Scored from 1–5 using the 20th, 40th, 60th, and 80th percentile cut points, with higher scores indicating more recent purchases.
- **F score:** Custom thresholds: 1 purchase session = 1; 2 = 2; 3–4 = 3; 5–7 = 4; 8 or more = 5. Custom thresholds were used because purchase frequency is highly skewed and many buyers purchased only once.
- **M score:** Scored from 1–5 using monetary-value percentile cut points.
- **Segments:** Champions (R ≥ 4, F ≥ 3); Loyal (R ≥ 3, F ≥ 3); At Risk (R ≤ 2, F ≥ 2); Promising (remaining buyers with F ≥ 2); One-time recent (remaining buyers with R ≥ 3); Hibernating (all remaining buyers). Rules are applied in order, with the first matching rule taking precedence.
- **Scope:** 139,462 buyers out of 1,063,104 observed users (13.12%).
- **Pareto finding:** The top 20% of buyers by monetary value generate approximately 72.2% of buyer revenue in this sampled dataset.
- **Limitations:** The observation window covers only October–November 2019, so recency is compressed. The 20% user sample supports analysis of patterns and shares but does not represent the full store's absolute revenue. Segment thresholds are specific to this dataset and should be reassessed with a longer observation period.