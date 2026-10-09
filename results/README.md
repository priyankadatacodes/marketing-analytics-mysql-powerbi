# Results exports

CSV extracts of the project's reporting views, produced by running the 16 scripts in `sql/` end-to-end
(MariaDB 10.11 stand-in for MySQL 8; see [docs/validation_notes.md](../docs/validation_notes.md)).
They let a reader inspect the key outputs without a database.

| File | Source view | Grain | Rows |
|---|---|---|---:|
| `kpi_summary.csv` | `vw_kpi_summary` | portfolio (1 row) | 1 |
| `channel_performance.csv` | `vw_channel_performance` | channel | 7 |
| `campaign_performance.csv` | `vw_campaign_performance` | campaign (unique `campaign_id`) | 220 |
| `funnel_by_channel.csv` | `vw_funnel_performance` | channel | 7 |
| `monthly_spend_revenue_roas.csv` | `vw_monthly_marketing_performance` + `vw_monthly_revenue` | calendar month (dated rows only) | 43 |
| `cohort_retention.csv` | `vw_cohort_retention` | signup month | 44 |

Notes
- Monthly files exclude records whose date is missing (mapped to the `19000101` unknown-date member), so monthly
  totals are lower than the headline totals (spend ₹220.9M dated vs ₹230.1M total).
- `cohort_retention.csv` includes the most recent signup months, whose M1–M4 windows are incomplete; the
  SQL (`13_advanced_analysis.sql`) restricts cohort-trend tests to cohorts up to 2026-03 with ≥20 customers.
- Currency: figures are shown as stored (₹ symbols and `$` were stripped during cleaning; no FX conversion was applied).
