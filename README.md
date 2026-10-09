# 1. Marketing Performance, Customer Acquisition & Lifetime Value Analytics

**Does marketing spend buy customers who are worth what they cost?** An end-to-end analysis of 7 channels, 220 campaigns and 185K records — from raw CSV extracts to a MySQL star schema and a four-page Power BI dashboard.

![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CTEs%20%7C%20Window%20Functions-336791)
![Power BI](https://img.shields.io/badge/Power%20BI-4%20pages-F2C811?logo=powerbi&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

![Executive overview dashboard](powerbi/01_executive_overview.png)

| Marketing spend | Attributed revenue | Blended ROAS | ROI | CAC | Revenue per customer (observed LTV) | LTV : CAC |
|---:|---:|---:|---:|---:|---:|---:|
| ≈ ₹230M | ≈ ₹89M | 0.39 | −0.61 | ₹74.8K | ≈ ₹10K | 0.09 – 0.16 (every channel < 1) |

> **Executive Takeaways**
>
> - 🔴 **ROAS 0.39** — every ₹1 spent returned ₹0.39 of attributed revenue (0.36–0.42 in every channel).
> - 🔴 **LTV:CAC below 1 in all seven channels** — customers have generated ≈ ₹10K of revenue against a ₹74.8K acquisition cost.
> - 🔴 **99.6% lead-to-customer gap** — the largest funnel loss is downstream of the click, and is uniform across channels.
> - 🟠 **Affiliate underperforms** — highest CAC, lowest LTV, and the only channel statistically separable from the best.
> - 🟢 **Measure first, then reallocate** — attribution and LTV definitions must be fixed before budget is moved.
>
> *Statistical validation prevented a misleading recommendation: Referral has the highest LTV:CAC, but ANOVA (p = 0.27) and bootstrap confidence intervals show most channel differences sit within sampling variation. Only Affiliate is clearly weaker.*

> **Terminology.** "LTV" here means **observed (revenue) LTV** — a customer's cumulative net revenue to date. It is not margin-based and not a forecast of future value.

**Contents:** [1 Title](#1-marketing-performance-customer-acquisition--lifetime-value-analytics) · [2 Business problem](#2-business-problem--objective) · [3 Dataset](#3-dataset-description) · [4 Tools](#4-tools--technologies) · [5 Workflow](#5-project-workflow--methodology) · [6 KPIs & insights](#6-key-kpis--business-insights) · [7 Dashboard](#7-dashboard--visualizations) · [8 Repository](#8-repository-structure) · [9 How to run](#9-how-to-run-the-project) · [10 Recommendations & limitations](#10-recommendations-limitations--future-scope)

---

# 2. Business Problem & Objective

Marketing teams need to see both **acquisition efficiency** and **customer economics**. Seven channels and 220 campaigns were generating spend, but there was no consistent view of what a customer costs, what a customer is worth, and where prospects are lost. The project answers:

- Which channels and campaigns acquire the most customers, and at what cost (CAC)?
- Is customer lifetime value sufficient to justify acquisition cost (LTV:CAC)?
- Which channels and campaigns return more revenue per rupee spent (ROAS, ROI)?
- Where do prospects drop out of the funnel (impressions → clicks → leads → customers)?
- How well are customers retained, and do newer cohorts behave differently?
- Is spend concentrated in a few campaigns or spread thinly?

**Objectives**

1. Load, profile and validate six inconsistent source files.
2. Standardise dates, categories, currencies and keys; remove duplicates and invalid records.
3. Model the data as a star schema that supports spend, revenue, conversion and activity analysis without double counting.
4. Define and calculate CAC, LTV, LTV:CAC, ROAS, ROI, funnel conversion, retention and cohort KPIs.
5. Compare channels and campaigns and identify performance gaps.
6. Present the results in a Power BI dashboard and translate them into recommendations.

**Audience:** marketing and growth teams, campaign managers, business analysts and management.

**Summary of result.** Recorded revenue was well below spend (ROAS 0.39). CAC (₹74.8K) is roughly seven to eight times the revenue each customer has generated to date (≈ ₹10K). About 99.6% of leads do not appear as customers. Channel differences are small; only Affiliate stands out. On this data no channel recovers its acquisition cost, so the first priority is fixing measurement, not reallocating budget.

---

# 3. Dataset Description

| Dataset / table | Raw rows | Cleaned rows | Purpose |
|---|---:|---:|---|
| `customers.csv` | 10,500 | 9,985 | Customer profile, signup date, CRM acquisition channel |
| `campaigns.csv` | 225 | 220 | Campaign name, channel, type, start/end dates |
| `campaign_performance.csv` | 25,184 | 25,164 | Daily impressions, clicks, leads and spend per campaign |
| `conversions.csv` | 19,000 | 18,940 | Funnel-stage events (Lead, MQL, SQL, Opportunity, Customer) |
| `transactions.csv` | 58,310 | 58,000 | Customer purchases and refunds, with optional campaign ID |
| `activity.csv` | 72,000 | 72,000 | Customer engagement events (8 activity types) |
| **Total** | **185,219** | **184,309** | |

- **Period:** 2023-01-04 to 2026-07-15 for spend and performance (43 calendar months); transactions run to August 2026.
- **Key dimensions:** channel (7), campaign (220), campaign type (4), customer, date, industry, country.
- **Key measures:** spend, impressions, clicks, leads, revenue, conversion stage, activity events.
- **Granularity:** campaign × day (spend, performance); transaction; conversion event; activity event.
- **Source:** the files in `data_raw/`; the original source system is not documented in the repository.
- **Detail:** [docs/data_dictionary.md](docs/data_dictionary.md).

**Data privacy.** `data_raw/customers.csv` contains customer names and email addresses. All 9,987 populated email values (raw rows, including duplicates) use the reserved domains `example.com`, `example.net` and `example.org`, which are non-routable placeholders. No phone numbers, passwords, API keys or tokens were found in any file. Because the dataset's origin is not documented, mask or remove `customer_name` and `email` if any record derives from real individuals.

---

# 4. Tools & Technologies

| Area | Tools |
|---|---|
| Database / SQL | MySQL 8.0+ — CTEs, recursive CTEs, window functions, `REGEXP`, views, stored procedures, indexes (scripts also executed on MariaDB 10.11 for verification) |
| BI | Power BI Desktop — 4-page report, 12-table import model, 15 DAX measures |
| Programming | Python 3 (pandas, NumPy, SciPy) — independent validation only, not the main analysis |
| Version control | Git, GitHub |

Not used in this project: Tableau, Excel / Google Sheets, notebooks.

---

# 5. Project Workflow & Methodology

```
Raw CSVs ──► Load as text ──► Profile ──► Clean & type ──► Star schema ──► Validate
 (6 files)    (01)            (01b)       (02)             (03, 04)        (05)
                                                                              │
Recommendations ◄── Insights ◄── Dashboard ◄── Views / procs ◄── KPIs & analysis (06–13)
