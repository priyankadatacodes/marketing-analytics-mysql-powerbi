# 📊 Marketing Performance, Customer Acquisition & Lifetime Value Analytics

[![MySQL](https://img.shields.io/badge/MySQL-8.0%2B-4479A1?logo=mysql\&logoColor=white)](https://www.mysql.com/)
[![SQL](https://img.shields.io/badge/SQL-Advanced-336791)](https://www.mysql.com/)
[![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?logo=powerbi\&logoColor=black)](https://powerbi.microsoft.com/)
[![Status](https://img.shields.io/badge/Status-Completed-success)](https://github.com/priyankadatacodes/marketing-analytics-mysql-powerbi)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

> **End-to-end marketing analytics project using MySQL, SQL, and Power BI to evaluate customer acquisition, campaign performance, customer economics, retention, funnel conversion, ROAS, and ROI.**

---

## 📌 Executive Summary

This project analyzes marketing performance across **7 channels**, covering **43 months, 220 campaigns, and 3,075 customers**.

The analysis follows a complete workflow:

**Raw Data → MySQL → Data Cleaning → Analytical Modeling → SQL Analysis → Power BI**

The project focuses on understanding whether marketing investment is generating valuable customers and which channels and campaigns are performing effectively.

### Core Business Question

> **Are marketing investments generating efficient customer acquisition and sustainable customer value?**

---

## 🎯 Business Problem

Marketing teams need visibility into both **acquisition efficiency** and **customer economics**.

This project answers:

* Which channels drive customer acquisition?
* How much does it cost to acquire a customer?
* What is the estimated customer lifetime value?
* How does LTV compare with CAC?
* Which campaigns generate better returns?
* Where are the major funnel drop-offs?
* How does customer retention change over time?
* How does channel performance change across periods?
* Is marketing spending generating positive ROAS and ROI?

### Stakeholders

* Marketing Teams
* Campaign Managers
* Business Analysts
* Growth Teams
* Management

---

## 📊 Key Metrics

| KPI                |          Result |
| ------------------ | --------------: |
| Marketing Spend    |   **₹23.01 Cr** |
| Revenue            |    **₹8.92 Cr** |
| Spend–Revenue Gap  |   **₹14.10 Cr** |
| CAC                |  **~₹72K–₹75K** |
| LTV                | **~₹9.7K–₹10K** |
| Highest LTV:CAC    |      **~0.157** |
| ROAS               |        **0.39** |
| Retention          |       **86.4%** |
| Overall Conversion |    **~0.0015%** |

---

# 1. Dataset

## Data Sources

The project uses six raw CSV datasets:

| Dataset                    | Description                                |
| -------------------------- | ------------------------------------------ |
| `customers.csv`            | Customer information                       |
| `campaigns.csv`            | Campaign details                           |
| `campaign_performance.csv` | Impressions, clicks, spend and performance |
| `conversions.csv`          | Lead and conversion funnel data            |
| `transactions.csv`         | Customer transactions and revenue          |
| `activity.csv`             | Customer activity and engagement           |

### Dataset Scale

| Metric             |     Value |
| ------------------ | --------: |
| Raw Records        |   185,219 |
| Cleaned Records    |   175,309 |
| Customers          |     3,075 |
| Campaigns          |       220 |
| Marketing Channels |         7 |
| Analysis Period    | 43 months |

### Marketing Channels

* Referral
* Email
* Organic
* Display
* Social
* Paid Search
* Affiliate

---

# 2. Data Quality & Preparation

The raw datasets contained several data-quality issues:

* Multiple date formats
* 22 channel-name variations
* Mixed currency symbols
* Duplicate records
* Negative spend and revenue values
* Clicks greater than impressions
* Blank conversion stages
* Blank activity types
* Unmatched campaign IDs

### Data Validation

The data was checked for:

* Missing values
* Duplicate records
* Invalid dates
* Invalid numeric values
* Referential integrity
* Channel inconsistencies
* Campaign mismatches

### Data Cleaning

The cleaning process included:

* Date standardization
* Channel normalization
* Currency and numeric-field cleaning
* Duplicate handling
* Spend and revenue validation
* Missing and invalid-record handling

---

# 3. Analytical Data Model

The cleaned data was organized into a **star schema**.

### Dimensions

* Customers
* Campaigns
* Channels
* Dates

### Fact Tables

* Marketing Spend
* Campaign Performance
* Revenue
* Customer Activity
* Conversions

This structure supports analysis across acquisition, campaigns, customer economics, retention, and conversion.

---

# 4. Tech Stack

| Technology     | Purpose                                   |
| -------------- | ----------------------------------------- |
| **MySQL 8.0+** | Data storage, cleaning and transformation |
| **SQL**        | Validation, analysis and KPI calculations |
| **Power BI**   | Interactive dashboards and reporting      |
| **CSV**        | Raw data source                           |

### SQL Techniques

* `REGEXP`
* `REGEXP_REPLACE`
* `ROW_NUMBER()`
* `RANK()`
* `NTILE()`
* `PERCENT_RANK()`
* Running totals
* Correlation analysis
* Views
* Stored procedures

---

# 5. Analytical Approach

## 5.1 Data Collection & Validation

Raw datasets were loaded into MySQL and validated for data-quality and referential-integrity issues.

## 5.2 Data Cleaning

Inconsistent dates, channels, currencies, duplicates, spend, revenue, and missing values were standardized.

## 5.3 Data Modeling

A star-schema structure was created to separate dimensions and business fact tables.

## 5.4 Marketing & Customer Analysis

The analysis calculates:

* Customer Acquisition Cost (CAC)
* Customer Lifetime Value (LTV)
* LTV:CAC
* ROAS
* ROI
* Conversion rates
* Funnel performance
* Retention
* Cohort performance
* Campaign performance
* Channel performance

## 5.5 Power BI Reporting

The final analysis is presented through four dashboard pages:

1. Executive Overview
2. Acquisition & Funnel
3. Campaign Performance
4. Customer Economics & Retention

---

# 6. Key Findings

## 6.1 Marketing Spend & Revenue

| Metric            |    Result |
| ----------------- | --------: |
| Marketing Spend   | ₹23.01 Cr |
| Revenue           |  ₹8.92 Cr |
| Spend–Revenue Gap | ₹14.10 Cr |
| ROAS              |      0.39 |

The analysis shows a substantial gap between marketing spend and revenue generated.

---

## 6.2 Customer Economics

| Metric          |                      Result |
| --------------- | --------------------------: |
| CAC             |                  ~₹72K–₹75K |
| LTV             |                 ~₹9.7K–₹10K |
| LTV:CAC         | Below 1 across all channels |
| Highest LTV:CAC |           Referral — ~0.157 |

Across the analyzed channels, LTV:CAC remained below 1.

---

## 6.3 Funnel Performance

Approximately **99.5% of leads did not progress to customers**, indicating a substantial drop between lead generation and final customer conversion.

---

## 6.4 Channel Performance Over Time

Channel rankings changed across monthly periods:

| Channel | Ranking Movement |
| ------- | ---------------- |
| Display | #1 → #4          |
| Social  | #4 → #1          |
| Email   | #7 → #2          |

This indicates that channel performance changed over time rather than remaining consistent.

---

## 6.5 Campaign Performance

The top 5 campaigns accounted for approximately **5.47% of total marketing spend**.

---

## 6.6 Customer Retention

Customer retention remained approximately **83%–88%**, with an overall retention rate of **86.4%**.

---

## 6.7 ROI

ROI was negative across all analyzed channels.

---

# 7. Power BI Dashboard

The Power BI dashboard contains four analytical pages.

### 1. Executive Overview

Provides an overall view of marketing spend, revenue, acquisition, and performance KPIs.

![Executive Overview](powerbi/01_executive_overview.png)

### 2. Acquisition & Funnel

Focuses on customer acquisition and conversion funnel performance.

![Acquisition & Funnel](powerbi/02_acquisition_funnel.png)

### 3. Campaign Performance

Analyzes campaign-level performance and marketing efficiency.

![Campaign Performance](powerbi/03_campaign_performance.png)

### 4. Customer Economics & Retention

Covers CAC, LTV, customer economics, and retention.

![Customer Economics & Retention](powerbi/04_customer_economics_retention.png)

---

# 8. Problems Encountered & Solutions

| Problem                       | Solution                                                      |
| ----------------------------- | ------------------------------------------------------------- |
| **Join multiplication**       | Used star schema and controlled fact-table aggregations       |
| **Slow analytical queries**   | Separated analytical steps and optimized query structures     |
| **Numeric conversion issues** | Standardized currency and numeric fields during cleaning      |
| **Cohort timing**             | Created consistent cohort periods and date-based calculations |

---

# 9. Repository Structure

```text
marketing-analytics-mysql-powerbi/
│
├── README.md
│
├── data_raw/
│   ├── customers.csv
│   ├── campaigns.csv
│   ├── campaign_performance.csv
│   ├── conversions.csv
│   ├── transactions.csv
│   └── activity.csv
│
├── sql/
│   ├── 01_raw_staging_setup.sql
│   ├── 01b_raw_data_validation.sql
│   ├── 02_data_cleaning.sql
│   ├── 03_database_schema.sql
│   ├── 04_populate_star_schema.sql
│   ├── 05_data_quality.sql
│   ├── 06_acquisition_analysis.sql
│   ├── 07_funnel_analysis.sql
│   ├── 08_cac_analysis.sql
│   ├── 09_campaign_analysis.sql
│   ├── 10_ltv_analysis.sql
│   ├── 11_retention_analysis.sql
│   ├── 12_cohort_analysis.sql
│   ├── 13_advanced_analysis.sql
│   ├── 14_create_views.sql
│   └── 15_stored_procedures.sql
│
└── powerbi/
    ├── marketing_analytics.pbix
    └── screenshots/
        ├── 01_executive_overview.png
        ├── 02_acquisition_funnel.png
        ├── 03_campaign_performance.png
        └── 04_customer_economics_retention.png
```

---

# 10. Setup & Execution

## Prerequisites

* MySQL 8.0+
* Power BI Desktop

## Clone Repository

```bash
git clone https://github.com/priyankadatacodes/marketing-analytics-mysql-powerbi.git
cd marketing-analytics-mysql-powerbi
```

## Load Raw Data

Place the CSV files inside:

```text
data_raw/
```

## Run SQL Pipeline

Execute the scripts in the following order:

```text
01_raw_staging_setup.sql
01b_raw_data_validation.sql
02_data_cleaning.sql
03_database_schema.sql
04_populate_star_schema.sql
05_data_quality.sql
06_acquisition_analysis.sql
07_funnel_analysis.sql
08_cac_analysis.sql
09_campaign_analysis.sql
10_ltv_analysis.sql
11_retention_analysis.sql
12_cohort_analysis.sql
13_advanced_analysis.sql
14_create_views.sql
15_stored_procedures.sql
```

## Open Power BI

Open:

```text
powerbi/marketing_analytics.pbix
```

Connect Power BI to the MySQL database and refresh the data if required.

---

# 11. Future Improvements

* More detailed marketing attribution
* Customer segmentation
* Predictive customer LTV
* Campaign response prediction
* Marketing budget optimization
* Automated reporting
* Incrementality and experiment analysis

---

# 12. Skills Demonstrated

### SQL & Database

* MySQL
* Data cleaning
* Data validation
* Star-schema modeling
* Views
* Stored procedures
* Advanced SQL
* Window functions

### Marketing Analytics

* CAC
* LTV
* LTV:CAC
* ROAS
* ROI
* Funnel analysis
* Campaign analysis
* Channel performance
* Retention
* Cohort analysis

### Power BI

* Executive dashboards
* KPI reporting
* Acquisition analysis
* Funnel visualization
* Campaign reporting
* Customer economics
* Retention analysis

---

# 13. Author

**Priyanka Lakra**
Data Analyst | SQL · Power BI · Business Analytics

🌐 [Portfolio](https://bloomindata.in/)

💻 [GitHub](https://github.com/priyankadatacodes)

---

# 14. License

This project is licensed under the **MIT License**.
