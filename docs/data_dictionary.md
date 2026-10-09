# Data Dictionary

Row counts are from running `sql/01`–`05` (raw → staging → star schema). Dates in the raw files appear in four text formats; all raw columns are loaded as `VARCHAR`.

## 1. Source files (`data_raw/`)

| File | Raw rows | Grain | Columns |
|---|---:|---|---|
| `customers.csv` | 10,500 | one row per customer record (duplicates present) | `customer_id`, `customer_name`, `email`, `signup_date`, `country`, `region`, `industry`, `acquisition_channel` |
| `campaigns.csv` | 225 | one row per campaign record (5 duplicate ids) | `campaign_id`, `campaign_name`, `channel`, `campaign_type`, `start_date`, `end_date` |
| `campaign_performance.csv` | 25,184 | campaign × day | `campaign_id`, `date`, `impressions`, `clicks`, `leads`, `spend` |
| `conversions.csv` | 19,000 | one conversion-stage event per customer × campaign | `conversion_id`, `customer_id`, `campaign_id`, `conversion_date`, `conversion_stage` (Lead / MQL / SQL / Opportunity / Customer) |
| `transactions.csv` | 58,310 | one transaction | `transaction_id`, `customer_id`, `campaign_id` (blank for ~10%), `transaction_date`, `revenue` |
| `activity.csv` | 72,000 | one activity event | `activity_id`, `customer_id`, `activity_date`, `activity_type` (8 types) |
| **Total** | **185,219** | | |

Data period: spend/performance dates run 2023-01-04 → 2026-07-15 (43 calendar months); transactions extend to 2026-08.
Currency: values carry `₹` or `$` symbols in some rows. Symbols were stripped and no exchange-rate conversion was applied (see [data_quality_log.md](data_quality_log.md)).

## 2. Staging layer (`stg_*`, script 02)

Typed copies of the raw tables: `DATE` for all date fields, `INT` for impressions/clicks/leads, `DECIMAL(12,2)` for spend and revenue, plus `is_refund BOOLEAN` on transactions.

| Table | Rows after cleaning |
|---|---:|
| `stg_customers` | 9,985 |
| `stg_campaigns` | 220 |
| `stg_campaign_performance` | 25,164 |
| `stg_conversions` | 18,940 |
| `stg_transactions` | 58,000 |
| `stg_activity` | 72,000 |
| **Total** | **184,309** |

## 3. Star schema (scripts 03–04)

### Dimensions

| Table | Rows | Key | Important columns |
|---|---:|---|---|
| `dim_customer` | 9,985 | `customer_key` (surrogate), `customer_id` (unique) | `signup_date` (414 NULL), `country`, `region`, `industry`, `acquisition_channel` (text) |
| `dim_campaign` | 220 | `campaign_key`, `campaign_id` (unique) | `campaign_name` (not unique), `channel_key`, `campaign_type`, `start_date`, `end_date` |
| `dim_channel` | 7 | `channel_key`, `channel_name` (unique) | `channel_type` (Paid / Owned / Organic / Earned) |
| `dim_date` | 1,462 | `date_key` (YYYYMMDD) | `full_date`, `month`, `quarter`, `year`, `week`, `year_month`; contains the unknown-date member `19000101` |

### Facts

| Table | Rows | Grain | Measures |
|---|---:|---|---|
| `fact_marketing_spend` | 25,164 | campaign × day | `spend` |
| `fact_campaign_performance` | 25,164 | campaign × day | `impressions`, `clicks`, `leads` |
| `fact_customer_revenue` | 58,000 | transaction | `revenue`, `is_refund` (`campaign_key` nullable) |
| `fact_customer_activity` | 72,000 | activity event | event count (`activity_type`) |
| `fact_conversions` | 18,940 | conversion event | stage (`conversion_stage`) |

### Reporting layer (script 14)

| Object | Type | Rows | Purpose |
|---|---|---:|---|
| `tbl_customer_first_touch` | table | 3,075 | One row per acquired customer: earliest dated `Customer`-stage conversion → campaign and channel |
| `tbl_customer_ltv` | table | 9,985 | Revenue-to-date per customer |
| `tbl_customer_retention` | table | 9,985 | 30-day post-signup retention flag |
| `vw_channel_performance` | view | 7 | Spend, revenue, customers, CAC, LTV, LTV:CAC, ROAS, ROI, retention by channel |
| `vw_campaign_performance` | view | 220 | Same measures by campaign (one row per `campaign_id`) |
| `vw_kpi_summary` | view | 1 | Portfolio totals: spend, attributed and total revenue, customers, CAC, ROAS, ROI (ratio of sums) |
| `vw_funnel_performance` | view | 7 | Impressions → clicks → leads → customers by channel |
| `vw_monthly_marketing_performance`, `vw_monthly_revenue` | views | 43 / 44 | Monthly spend/traffic and revenue |
| `vw_customer_economics`, `vw_channel_ltv_cac`, `vw_retention` | views | — | Customer-level and channel-level economics |
| `vw_cohort_retention`, `vw_channel_cohort_performance` | views | 44 / — | Signup-month cohort activity (M1–M4) |

## 4. Not available in the repository
Power BI model (tables, relationships, calculated columns, DAX measures, Power Query steps) — the `.pbix` file is not in the repository. A formal source-system data dictionary is also not available; the definitions above are derived from the files and SQL.
