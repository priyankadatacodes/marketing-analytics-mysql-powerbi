# Power BI Fix Guide — ratio measures and totals

**Status: guidance, not completed work.** The `.pbix` is not in the repository, so the dashboard could not be edited or re-exported. This guide documents the problem, the measures that fix it, and a checklist to prove the fix, so the pages can be rebuilt and the screenshots replaced.

## The problem
- **Pages 2 and 3:** the Total rows add up per-row ratio columns (CTR 22.87, lead rate 81.9, overall conversion 0.0107, ROAS 98.12, ROI −121.88, CAC ₹17.9M, LTV:CAC 32.99). These are sums of 7 channel ratios or of 220 campaign ratios. They reproduce exactly from the views (`SUM(roas)` over `vw_campaign_performance` = 98.14).
- **Page 3 rows:** the table is grouped by campaign name + channel; names repeat across campaigns, so one row can combine several campaigns whose ratios are then added (the identity ROI = ROAS − 1 fails by the number of campaigns combined).
- **Cause:** ratio columns computed in the SQL views were imported and set to *Sum*; ratios must be computed after aggregation.

## Fix
1. Import the **additive** columns (spend, revenue, impressions, clicks, leads, customer counts) and compute every ratio as a **measure**. Hide the pre-computed ratio columns from the report view.
2. Use `campaign_id` (unique) as the table row key; show `campaign_name` as a secondary label.
3. Use the measures below (table and column names assume the SQL object names; adjust to the model).

```DAX
Total Spend        = SUM ( fact_marketing_spend[spend] )
Attributed Revenue = CALCULATE ( SUM ( fact_customer_revenue[revenue] ),
                                 NOT ( ISBLANK ( fact_customer_revenue[campaign_key] ) ) )
Customers Acquired = DISTINCTCOUNT ( tbl_customer_first_touch[customer_key] )

ROAS  = DIVIDE ( [Attributed Revenue], [Total Spend] )
ROI   = [ROAS] - 1
CAC   = DIVIDE ( [Total Spend], [Customers Acquired] )

Impressions = SUM ( fact_campaign_performance[impressions] )
Clicks      = SUM ( fact_campaign_performance[clicks] )
Leads       = SUM ( fact_campaign_performance[leads] )
CTR                    = DIVIDE ( [Clicks], [Impressions] )
Lead Rate              = DIVIDE ( [Leads], [Clicks] )
Lead-to-Customer Rate  = DIVIDE ( [Customers Acquired], [Leads] )
Overall Conversion     = DIVIDE ( [Customers Acquired], [Impressions] )

Observed LTV = AVERAGE ( tbl_customer_ltv[customer_ltv] )
LTV:CAC      = DIVIDE ( [Observed LTV], [CAC] )
```

Model notes: relate `tbl_customer_first_touch[channel_key]` / `[campaign_key]` and the facts to `dim_channel` / `dim_campaign` so the same channel or campaign filter drives spend, revenue and customers. For channel-level LTV:CAC the SQL (`vw_channel_performance`) averages LTV over *acquired* customers; a measure that averages over all customers gives a different number (₹10.0K vs ₹9.8K overall) — pick one population and label it.

## Validation checklist (all values from the SQL run)
| Check | Expected |
|---|---|
| Spend card | ₹230,140,742 (screenshot shows ₹230,128,289 — reconcile) |
| Attributed revenue card | ₹89,166,066 (screenshot ₹89,140,344) |
| ROAS (total row and card) | 0.387 |
| ROI = ROAS − 1 | holds on every row and the total |
| CAC (total row) | ₹74,843 |
| CTR / lead rate / lead-to-customer / overall conversion (total row) | 3.27% / 11.72% / 0.40% / 0.0015% |
| Σ channel customers | 3,075 |
| Page-3 table rows | 220 (one per campaign id) |
| Channel table totals vs cards | equal |
