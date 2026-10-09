# SQL pipeline

Target: MySQL 8.0+ (window functions, CTEs incl. recursive, `REGEXP_REPLACE`). Run the scripts in numeric order
in one database (`marketing_analytics`). Each script is self-contained and starts with `USE marketing_analytics;`.

| # | Script | Layer | What it does |
|---|---|---|---|
| 01 | `01_raw_staging_setup.sql` | Raw | Creates six all-`VARCHAR` raw tables and loads the CSVs (`LOAD DATA INFILE`) |
| 01b | `01b_raw_data_validation.sql` | Profiling | Counts blanks, duplicate keys, category variants, date-format mix, currency symbols, negatives, clicks>impressions, orphan keys |
| 02 | `02_data_cleaning.sql` | Staging | Typed `stg_*` tables: trimming, channel/country normalisation, 4-format date parsing, currency stripping, de-duplication, orphan removal |
| 03 | `03_database_schema.sql` | Model | DDL for 4 dimensions, 5 facts, foreign keys, indexes |
| 04 | `04_populate_star_schema.sql` | Model | Recursive-CTE calendar (+ unknown-date member), dimension and fact loads |
| 05 | `05_data_quality.sql` | Validation | Post-load checks (keys, orphans, null attribution, unknown dates, funnel logic) with PASS/FAIL summary |
| 06 | `06_acquisition_analysis.sql` | Analysis | Customers by channel, top campaigns (first-touch), month-over-month signup growth |
| 07 | `07_funnel_analysis.sql` | Analysis | CTR, lead and customer conversion, stage drop-off, traffic-vs-conversion quadrants |
| 08 | `08_cac_analysis.sql` | Analysis | Overall / channel / campaign / monthly CAC, 3-month moving average |
| 09 | `09_campaign_analysis.sql` | Analysis | Revenue, ROAS and ROI by channel / campaign / month; spend-vs-return screens |
| 10 | `10_ltv_analysis.sql` | Analysis | Customer LTV, LTV by channel/campaign, LTV:CAC verdicts, investment ranking |
| 11 | `11_retention_analysis.sql` | Analysis | 30-day post-signup retention flag, repeat customers, 90-day revenue split |
| 12 | `12_cohort_analysis.sql` | Analysis | M0–M4 cohort activity and revenue matrices |
| 13 | `13_advanced_analysis.sql` | Analysis | Running totals, top-5 spend concentration, NTILE/PERCENT_RANK, multi-criteria screens |
| 14 | `14_create_views.sql` | Reporting | 3 materialised tables (first-touch, LTV, retention) and 11 views for Power BI, including `vw_kpi_summary` (portfolio-level ROAS/ROI/CAC computed as ratios of sums) |
| 15 | `15_stored_procedures.sql` | Reporting | `sp_refresh_materialized_tables` and 3 parameterised read procedures |

Portability notes
- `01` contains Windows `LOAD DATA INFILE` paths; edit them to your `data_raw/` location.
- `04` sets `cte_max_recursion_depth` (MySQL 8). MariaDB uses `max_recursive_iterations` instead.
- `03` drops dimensions before facts, so re-running it on an existing database fails on the foreign keys; drop the `fact_*` tables first (or set `FOREIGN_KEY_CHECKS=0` for the rebuild).
