# Power BI Semantic Model & Report Corrections

Source: `powerbi/marketing_analytics.pbix` (read directly from the file). The model is an **import** model over 10 reporting views from `sql/14_create_views.sql`, plus a helper table (`Funnel_Chart_Data`) and a measures table (`_Measures`); there is no Power Query/M content stored in the file.

## 1. Tables

| Table | Rows | Role |
|---|---:|---|
| `vw_channel_performance` | 7 | Channel-level spend, revenue, customers, CAC, LTV, ROAS, ROI, retention (first-touch basis) |
| `vw_channel_ltv_cac` | 7 | Channel list used as the shared channel dimension / slicer source |
| `vw_funnel_performance` | 7 | Impressions → customers by channel |
| `vw_retention` | 7 | Retention by `acquisition_channel` (CRM basis) |
| `vw_campaign_performance` | 220 | Campaign-level measures (older view version without `campaign_id`) |
| `vw_customer_economics` | 9,985 | One row per customer (LTV, retention flag) |
| `vw_cohort_retention` | 44 | Signup-month cohorts, M1–M4 |
| `vw_channel_cohort_performance` | 306 | Channel × cohort, M1 and M4 |
| `vw_monthly_marketing_performance`, `vw_monthly_revenue` | 43 / 44 | Monthly spend/traffic and revenue |
| `Funnel_Chart_Data` | 28 | Unpivoted funnel (channel × stage) feeding the funnel visual |
| `_Measures` | 0 | Holder table for DAX measures |

## 2. Relationships (10)

| From | To | Cardinality | Filter | Active |
|---|---|---|---|---|
| `vw_campaign_performance[channel_name]` | `vw_channel_ltv_cac[channel_name]` | many-to-one | single | yes |
| `vw_channel_cohort_performance[channel_name]` | `vw_channel_ltv_cac[channel_name]` | many-to-one | single | yes |
| `vw_channel_performance[channel_name]` | `vw_channel_ltv_cac[channel_name]` | one-to-one | both | yes |
| `vw_funnel_performance[channel_name]` | `vw_channel_ltv_cac[channel_name]` | one-to-one | both | yes |
| `vw_retention[channel_name]` | `vw_channel_ltv_cac[channel_name]` | one-to-one | both | yes |
| `vw_customer_economics[acquisition_channel]` | `vw_channel_performance[channel_name]` | many-to-one | single | yes |
| `vw_channel_cohort_performance[cohort_month]` | `vw_cohort_retention[cohort_month]` | many-to-one | single | yes |
| `vw_monthly_marketing_performance[month]` | `vw_monthly_revenue[month]` | one-to-one | both | yes |
| `Funnel_Chart_Data[channel_name]` | `vw_channel_ltv_cac[channel_name]` | many-to-one | single | yes |
| `Funnel_Chart_Data[lead_conversion_pct]` | `vw_funnel_performance[lead_conversion_pct]` | many-to-one | single | **no** |

Observations: the model is a hub of channel-level tables around `vw_channel_ltv_cac` rather than a fact/dimension star over the SQL star schema, so ratios cannot be recomputed from facts inside Power BI; the inactive relationship on a percentage column is unintended and can be deleted.

## 3. DAX measures (15) and one calculated column

| Measure | DAX |
|---|---|
| Total Revenue | `SUM('vw_channel_performance'[total_revenue])` — campaign-attributed revenue |
| Total Ad Spend | `SUM('vw_channel_performance'[total_spend])` |
| Total Customers Acquired | `SUM('vw_channel_performance'[customers_acquired])` |
| Blended ROAS | `DIVIDE([Total Revenue], [Total Ad Spend])` |
| **Overall ROI** | `DIVIDE([Total Revenue] - [Total Ad Spend], [Total Ad Spend])` |
| CAC | `DIVIDE([Total Ad Spend], [Total Customers Acquired])` |
| Average LTV | `AVERAGE('vw_customer_economics'[customer_ltv])` — all 9,985 customers |
| LTV to CAC Ratio | `DIVIDE([Average LTV], [CAC])` |
| Total Retained Customers / Total Customers (Retention Base) | `SUM` of `vw_retention[retained_customers]` / `[total_customers]` |
| Retention Rate % | `DIVIDE([Total Retained Customers], [Total Customers (Retention Base)])` |
| Monthly Spend / Monthly Revenue | `SUM` of the monthly views |
| Avg Spend Per Campaign / Avg Revenue Per Campaign | `AVERAGEX('vw_campaign_performance', …)` |

Calculated column `vw_campaign_performance[Is Top 5 Campaign]`: `RANKX(ALL(table), [total_spend])` → "Top 5 Campaigns" / "Remaining 215".

Notes
- The existing measures are correct ratios of sums. `Overall ROI` = −0.6126 existed but was not placed on any visual; the page tables used `Sum()` of the pre-computed ratio columns instead.
- `Average LTV` (all customers) and `CAC` (acquired customers) use different populations, so `LTV to CAC Ratio` mixes them (0.133 vs. the channel-level 0.094–0.157 computed on acquired customers).
- `Retention Rate %` (86.4%) comes from `vw_retention` (CRM `acquisition_channel` basis), whereas the "Retention Rate by Channel" chart uses `vw_channel_performance[retention_rate_pct]` (first-touch basis).
- The model data is a snapshot slightly different from a fresh run of the SQL: spend ₹230,128,289 vs ₹230,140,742 and attributed revenue ₹89,140,344 vs ₹89,166,066 (0.005% and 0.029%); customers, impressions, clicks and leads match exactly.

## 4. Corrections applied to the report

The corrected file changes only the report layout; **the data model (tables, relationships, measures, data) is byte-for-byte unchanged**. No new measures could be added because the compressed model cannot be edited safely outside Power BI Desktop.

| Page | Visual | Problem | Change |
|---|---|---|---|
| 1 | KPI cards | ROI not shown | Added the existing `Overall ROI` measure (−0.61) next to Blended ROAS |
| 2 | Funnel Detail by Channel | Total row summed CTR, lead rate and conversion % (22.87, 81.9, 0.0107) | Total row hidden; per-channel rows are unchanged and correct |
| 3 | Campaign table | Grouped by name + channel (162 groups for 220 campaigns); `Sum()` of ratio columns added up the merged campaigns; Total row showed ROAS 98.12, ROI −121.88, CAC ₹17.9M | `total_spend` is now a grouping column (unique for all 220 campaigns), so each row is one campaign and its ROAS/ROI/CAC/LTV:CAC are that campaign's own values (ROI = ROAS − 1 on every row); Total row hidden; title "Top 15" corrected |
| 4 | "Does Month-0 Appeal Predict Long-Term Value?" | Plots average M1 and M4 retention %, but was labelled "Month 0 / Month 4 Revenue" | Relabelled "Avg Month-1 / Month-4 Retention %", title "Month-1 vs Month-4 Retention % by Channel" |
| 4 | Retention Rate by Channel | Value axis started at 75, exaggerating a 6% spread | Axis set to 0–100 |

**Status of verification.** The edited file was checked structurally (valid archive, valid JSON in every visual, unchanged data model, same measures and relationships) and against the model's own data (220 unique rows, no merged campaigns, ROI = ROAS − 1 on all rows, Overall ROI −0.6126). **It has not been opened in Power BI Desktop**: open it, confirm each page renders, then re-export the four screenshots in `powerbi/` (the existing PNGs still show the pre-correction totals).

## 5. Remaining improvements (need Power BI Desktop)
- Add campaign-level ratio measures and a Total row that is a true ratio of sums (see [powerbi_fix_guide.md](powerbi_fix_guide.md)); replace `vw_campaign_performance` with the refreshed view that includes `campaign_id`.
- Use one secondary-axis range for spend and revenue on the page-1 trend chart (currently separate axes).
- Align `Average LTV` and `CAC` on the same customer population.
- Delete the inactive `Funnel_Chart_Data` → `vw_funnel_performance` relationship.
