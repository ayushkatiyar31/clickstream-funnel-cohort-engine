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
(Fill in after Step 4.)