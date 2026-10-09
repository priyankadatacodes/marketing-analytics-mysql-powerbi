# Dashboard Guide (Power BI, 4 pages)

The report consumes the reporting views from `sql/14_create_views.sql` (the displayed figures reproduce `vw_funnel_performance`, `vw_channel_performance` and `vw_campaign_performance`). The `.pbix` file is **not available in the repository**, so measures, relationships and Power Query steps cannot be documented; this guide describes the four exported screenshots.

All pages share a header, a left-hand page navigation panel and a consistent pink/magenta palette.

## 1. Executive Overview — [screenshot](../powerbi/01_executive_overview.png)
**Purpose:** one-screen answer to "is marketing spend paying back?" for leadership.
**KPI cards:** Total Revenue ₹89.14M · Total Ad Spend ₹230.13M · Retention Rate 86.4% · CAC ₹74.84K · Blended ROAS 0.39 · Average LTV ₹10K.
**Visuals:** monthly Spend vs Revenue trend (columns for spend, area for revenue on a secondary axis, 2023-01 → 2026-07); CAC vs LTV by channel (scatter); LTV:CAC ratio by channel (ranked bars: Referral 0.157 … Affiliate 0.094).
**Questions answered:** How large is the gap between spend and revenue, and has it ever closed? Which channels have the cheapest acquisition and the highest customer value?
**Reading notes:** the two trend series use different axis scales, so the visual gap understates the spend/revenue difference; read the ROAS card for the magnitude. The final month (2026-07) is a partial month (data ends 15 July). The scatter's axes are truncated, which magnifies a ~10% LTV range.

## 2. Acquisition & Funnel — [screenshot](../powerbi/02_acquisition_funnel.png)
**Purpose:** show where prospects drop out between exposure and purchase, by channel.
**Visuals:** overall funnel (impressions 198.82M → clicks 6.49M → leads 0.76M → customers 3,075); channel funnel table (clicks, customers, impressions, leads, lead conversion, overall conversion, CTR); monthly leads generated; overall conversion rate by channel.
**Questions answered:** Which stage loses the most volume? Do channels differ in click-through or conversion?
**Reading notes:** the "customers" bar is not visible at this scale. CTR (3.19–3.32%) and lead rate (11.3–12.3%) are nearly the same across channels. In the table, the **Total row sums the ratio columns** (e.g. CTR 22.87); the correct totals are CTR 3.27%, lead rate 11.72%, overall conversion 0.0015%.

## 3. Campaign Performance — [screenshot](../powerbi/03_campaign_performance.png)
**Purpose:** let campaign managers find where spend is not matched by revenue.
**Visuals:** spend vs revenue scatter with average reference lines (₹1.05M spend, ₹405K revenue); budget concentration donut (top 5 campaigns ₹12.6M = 5.47% of ₹230.1M); campaign table with spend, customers, CAC, revenue, ROAS, ROI, LTV:CAC and conditional formatting; month slicer and channel buttons.
**Questions answered:** Which campaigns combine above-average spend with below-average revenue? Is spend concentrated in a few campaigns?
**Reading notes:** the donut shows spend is *diffuse* (5 of 220 campaigns would be 2.3% if spend were uniform). The table is grouped by campaign name + channel, and names repeat across campaigns, so several campaigns appear in one row; its ratio columns (ROAS, ROI, CAC, LTV:CAC) are **summed across those campaigns and in the Total row** (ROAS 98.12, ROI −121.88 = sums over 220 campaigns). Row-level ROAS/ROI/CAC cells should not be used until the table is rebuilt with ratio measures keyed by campaign id.

## 4. Customer Economics & Retention — [screenshot](../powerbi/04_customer_economics_retention.png)
**Purpose:** assess whether customers are worth what they cost and whether they stay.
**KPI cards:** Average LTV ₹10K · LTV:CAC 0.13 · Retention Rate 86.4%.
**Visuals:** average LTV by channel; CAC by channel; retention rate by channel (83.25–88.32%); "Does Month-0 appeal predict long-term value?" (month-0 vs month-4 revenue by channel); cohort retention matrix (M1–M4 by signup month, cohort sizes ≈ 190–250).
**Questions answered:** Which channels deliver higher-value or longer-lived customers? Do cohorts retain better over time?
**Reading notes:** the retention-by-channel axis starts at 75, which exaggerates a ~5-point range. "Average LTV by channel" is computed by the customer's CRM `acquisition_channel`, while CAC and the retention bars use the first-touch campaign channel, so the two channel bases are shown side by side. The 86.4% retention figure and the M1–M4 cohort values (≈ 19–31%) use different definitions (see [kpi_definitions.md](kpi_definitions.md)). The cohort table shows some signup months twice.

