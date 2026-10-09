# Validation Notes & Known Limitations

## 1. How the pipeline was validated
1. **Full re-execution.** All 16 SQL scripts (`01` → `15`) were executed in order against the six CSVs on a MariaDB 10.11 server (a MySQL-compatible stand-in), with `sql_mode` set to the strict MySQL-style defaults. Two environment differences were handled outside the repository files: the Windows `LOAD DATA` path, and MariaDB's name for the recursion-limit variable (`max_recursive_iterations` instead of `cte_max_recursion_depth`). No analytical SQL was changed. **MySQL 8 itself was not available for this check.**
2. **Independent recomputation.** `validation/verify_kpis.py` reimplements the cleaning rules and KPI logic in pandas straight from `data_raw/`. Staged row counts (9,985 / 220 / 25,164 / 18,940 / 58,000 / 72,000), first-touch customers by channel, CAC, LTV:CAC and the retention flag agree with the SQL run exactly.
3. **Cross-check with screenshots.** The views `vw_funnel_performance`, `vw_channel_performance` and `vw_customer_economics` reproduce the dashboard's impressions (198,818,934), clicks (6,492,079), leads (760,749), customers (3,075), channel CAC, LTV:CAC and retention values exactly.

## 2. Discrepancies identified (for review)

| # | Item | Earlier README / dashboard | Verified | Handling in this README |
|---|---|---|---|---|
| 1 | Customer count | "3,075 customers" | 9,985 customers after de-duplication; 3,075 are *acquired* (first-touch) customers | Both numbers reported and labelled |
| 2 | CAC | "~₹72K–₹75K" | ₹72.5K divides by 3,175 customers (`08` Q1, includes 100 customers whose conversion date is blank); ₹74.8K divides by 3,075 (dashboard, channel and monthly CAC) | ₹74.8K used; ₹72.5K noted |
| 3 | Cleaned records | "175,309" | 184,309 staged rows (SQL and pandas agree) | 184,309 used |
| 4 | Spend and revenue | Dashboard: ₹230,128,289 / ₹89,140,344 | SQL: ₹230,140,742 / ₹89,166,066 (Δ 0.005% / 0.029%) | SQL values used; difference unexplained (the screenshot may come from a slightly different load) |
| 5 | Funnel script vs dashboard | Dashboard funnel uses the views | `07_funnel_analysis.sql` excludes undated rows (190.3M impressions) and counts distinct `Customer`-stage customers per channel across all campaigns (3,175 overall, 3,693 summed across channels because a customer can appear in several), so its outputs differ from the dashboard (198.8M impressions, 3,075 customers) | Dashboard/view definitions used |
| 6 | Top-5 campaign spend share | 5.47% | 5.47% by campaign id; `13` Q1 groups by `campaign_name` and returns 22.1% | 5.47% used |
| 7 | "Channel rankings changed" (Display #1→#4, Social #4→#1, Email #7→#2) | README §6.4 | No SQL script in the repository produces monthly channel ranks | Claim omitted — source not available in repository |
| 8 | Power BI file | README listed `powerbi/marketing_analytics.pbix` and a `screenshots/` subfolder | The file was missing from the repository and has now been added (corrected, see `docs/powerbi_model.md`); screenshots sit directly in `powerbi/` | Structure documented as it exists |
| 9 | `campaign_name` distinct count | — | 51 distinct names in the SQL run vs 48 in pandas, because 5 duplicated campaign ids differ by a "(v2)" suffix and the SQL tie-break is arbitrary | "roughly 48–51" |

## 3. Analytical limitations
- **Three channel bases.** CAC, customer counts, retention-by-channel and LTV:CAC use the first-touch campaign channel; "Average LTV by channel" uses the CRM `acquisition_channel`; ROAS uses the channel of the campaign recorded on each transaction. For acquired customers the first two agree 14.8% of the time (about what random assignment gives, 14.3%).
- **LTV is revenue to date,** not margin-based or forecast, and recent customers have had less time to spend. The mean (₹9,954) is more than twice the median (₹4,075); the top 10% of customers account for 48.6% of revenue.
- **Retention.** The 86.4% flag counts any activity or purchase after day 30 at any later date; about half of dated events occur before the recorded signup date, and 414 customers have no signup date. The cohort matrix (≈ 24–25% active per month) is not comparable to the headline flag.
- **Attribution quality.** 9.9% of transactions (₹10.2M) have no campaign. For attributed transactions, about 89% fall outside the campaign's own start/end dates ‡, and spend and revenue are negatively correlated across the 220 campaigns (r = −0.20 ‡). Campaign-level ROAS should be treated as descriptive.
- **Funnel populations differ.** Impressions, clicks and leads come from campaign-performance reports; customers come from conversion records with no lead identifier linking them. The 99.6% lead-to-customer loss is a ratio between populations, not a tracked cohort. The five conversion stages (Lead, MQL, SQL, Opportunity, Customer) were not used for a stage-by-stage funnel.
- **Statistical significance.** Differences between channels are small relative to sampling variation: one-way ANOVA of customer revenue across first-touch channels p = 0.27; chi-square on customers vs. impressions p = 0.21; bootstrap 95% intervals for LTV:CAC overlap for six of seven channels — only Affiliate (0.081–0.109) and Referral (0.135–0.182) separate. No campaign has ROAS ≥ 1 (max 0.96).
- **Currency.** `$`-marked values were treated as ₹ with no conversion.
- **Spend treatment.** 140 negative spend entries were excluded instead of treated as credits (−₹1.09M, about 0.5% of spend).

‡ computed in `validation/verify_kpis.py` or the independent check; not produced by the SQL scripts.

## 4. ROI correction (applied)
The page-3 Total row showed ROI −121.88 because Power BI summed the 220 per-campaign ROI values. Portfolio ROI is (Σ attributed revenue − Σ spend) ÷ Σ spend = **−0.6126** (−0.5681 including unattributed revenue). `sql/14_create_views.sql` now exposes `campaign_id` in `vw_campaign_performance` (one unique row per campaign) and adds `vw_kpi_summary` with ratio-of-sums totals; on all 220 rows ROI = ROAS − 1 holds exactly. The Power BI pages themselves still need to be rebuilt on these objects (see `docs/powerbi_fix_guide.md`).

## 5. Suggested next fixes (not applied)
Group by `campaign_id` instead of `campaign_name` in scripts 06, 07, 09, 10 and 13; use one CAC denominator; standardise on a single channel definition; rebuild the Power BI tables with ratio measures; define retention on eligible customers within fixed windows; add a deterministic tie-break to the campaign de-duplication; commit the `.pbix`.
