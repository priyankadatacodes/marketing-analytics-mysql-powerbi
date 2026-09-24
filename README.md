# Marketing Performance, Customer Acquisition & Lifetime Value Analytics 📊

![MySQL](https://img.shields.io/badge/MySQL-8.0+-4479A1?logo=mysql\&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-336791)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?logo=powerbi\&logoColor=black)
![Status](https://img.shields.io/badge/Status-Completed-success)

## 📌 Project Overview

This project analyzes marketing performance, customer acquisition, campaign effectiveness, and customer lifetime value across **7 marketing channels**.

Using **MySQL, SQL, and Power BI**, the project covers the complete analytics workflow from raw data validation and cleaning to KPI analysis, customer economics, funnel analysis, retention, cohort analysis, and interactive dashboard reporting.

The analysis covers **43 months, 220 campaigns, and 3,075 customers**.

---

## 🎯 Business Problem

Marketing teams need to understand whether their acquisition spending is generating valuable customers and which channels and campaigns are performing effectively.

This project answers:

* Which marketing channels drive customer acquisition?
* How much does it cost to acquire a customer?
* What is the estimated lifetime value of customers?
* How does LTV compare with CAC across channels?
* Which campaigns generate better returns?
* Where are the biggest funnel drop-offs?
* How does customer retention change over time?
* How do channel rankings change across different periods?
* Is marketing spending generating positive ROAS and ROI?

### Goal

Evaluate **marketing efficiency, customer economics, campaign performance, and conversion performance** using historical marketing and customer data.

### Stakeholders

* Marketing Teams
* Campaign Managers
* Business Analysts
* Growth Teams
* Management

---

## 💾 Data Description

The project uses six raw CSV datasets.

### Data Sources

| Dataset                    | Description                                         |
| -------------------------- | --------------------------------------------------- |
| `customers.csv`            | Customer information                                |
| `campaigns.csv`            | Campaign details                                    |
| `campaign_performance.csv` | Campaign impressions, clicks, spend and performance |
| `conversions.csv`          | Lead and conversion funnel data                     |
| `transactions.csv`         | Customer transactions and revenue                   |
| `activity.csv`             | Customer activity and engagement                    |

### Dataset Size

* **Raw records:** 185,219
* **Cleaned records:** 175,309
* **Customers:** 3,075
* **Campaigns:** 220
* **Marketing channels:** 7
* **Analysis period:** 43 months

### Marketing Channels

* Referral
* Email
* Organic
* Display
* Social
* Paid Search
* Affiliate

### Data Quality Issues

The raw data contained:

* Multiple date formats
* 22 channel-name variations
* Mixed currency symbols
* Duplicate records
* Negative spend and revenue values
* Clicks greater than impressions
* Blank conversion stages
* Blank activity types
* Unmatched campaign IDs

---

## 🛠️ Tech Stack & Tools

| Tool           | Purpose                                        |
| -------------- | ---------------------------------------------- |
| **MySQL 8.0+** | Data storage, cleaning and transformation      |
| **SQL**        | Data validation, analysis and KPI calculations |
| **Power BI**   | Interactive dashboard and reporting            |
| **CSV**        | Raw data source                                |

### SQL Techniques Used

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

## ⚙️ Methodology & Approach

### 1. Data Collection & Validation

The raw datasets were loaded into MySQL and checked for:

* Missing values
* Duplicate records
* Invalid dates
* Invalid numeric values
* Referential integrity
* Channel inconsistencies
* Campaign mismatches

### 2. Data Cleaning

The data was standardized by:

* Converting inconsistent date formats
* Normalizing channel names
* Cleaning currency and numeric fields
* Handling duplicates
* Validating spend and revenue values
* Handling missing and invalid records

### 3. Data Modeling

The cleaned data was organized into a **star schema**.

#### Dimensions

* Customers
* Campaigns
* Channels
* Dates

#### Fact Tables

* Marketing Spend
* Campaign Performance
* Revenue
* Customer Activity
* Conversions

### 4. Marketing & Customer Analysis

Calculated and analyzed:

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

### 5. Power BI Reporting

The final analytical outputs were presented through a Power BI dashboard covering:

* Executive Overview
* Acquisition & Funnel
* Campaign Performance
* Customer Economics & Retention

---

## 📈 Key Insights & Results

### Marketing Spend & Revenue

* **Marketing Spend:** ₹23.01 Cr
* **Revenue:** ₹8.92 Cr
* **Spend–Revenue Gap:** ₹14.10 Cr
* **ROAS:** 0.39

### Customer Economics

* **CAC:** ~₹72K–₹75K
* **LTV:** ~₹9.7K–₹10K
* **LTV:CAC:** Below 1 across all channels
* **Highest LTV:CAC:** Referral at approximately 0.157

### Funnel Performance

Approximately **99.5% of leads did not progress to customers**, indicating a substantial drop between lead generation and final customer conversion.

### Channel Performance Over Time

Channel rankings changed across monthly periods:

| Channel | Ranking Movement |
| ------- | ---------------- |
| Display | #1 → #4          |
| Social  | #4 → #1          |
| Email   | #7 → #2          |

This shows that channel performance changed over time rather than remaining consistent.

### Campaign Performance

The top 5 campaigns accounted for approximately **5.47% of total marketing spend**.

### Retention

Customer retention remained approximately **83%–88%**, with an overall retention rate of **86.4%**.

### ROI

ROI was negative across all analyzed channels.

---

## 📊 KPI Summary

| KPI                |      Result |
| ------------------ | ----------: |
| Marketing Spend    |   ₹23.01 Cr |
| Revenue            |    ₹8.92 Cr |
| Spend–Revenue Gap  |   ₹14.10 Cr |
| CAC                |  ~₹72K–₹75K |
| LTV                | ~₹9.7K–₹10K |
| Highest LTV:CAC    |      ~0.157 |
| ROAS               |        0.39 |
| Retention          |       86.4% |
| Overall Conversion |    ~0.0015% |

---

## 🖼️ Power BI Dashboard

The Power BI dashboard contains **4 analytical pages**.

### 1. Executive Overview

![Executive Overview](powerbi/screenshots/01_executive_overview.png)

---

### 2. Acquisition & Funnel

![Acquisition & Funnel](powerbi/screenshots/02_acquisition_funnel.png)

---

### 3. Campaign Performance

![Campaign Performance](powerbi/screenshots/03_campaign_performance.png)

---

### 4. Customer Economics & Retention

![Customer Economics & Retention](powerbi/screenshots/04_customer_economics_retention.png)

---

## 🧩 Problems Encountered & Solutions

### Join Multiplication

**Problem:** Joining multiple fact tables directly caused duplicated rows and inflated metrics.

**Solution:** Used a structured star schema and controlled aggregations across fact tables.

### Slow Analytical Queries

**Problem:** Complex analytical views became slow when several calculations were executed together.

**Solution:** Separated analytical steps and optimized query structures.

### Numeric Conversion Issues

**Problem:** Spend and revenue fields contained currency symbols and inconsistent numeric formats.

**Solution:** Standardized numeric values during the data-cleaning stage.

### Cohort Timing

**Problem:** Customer activity needed to be aligned correctly with acquisition periods.

**Solution:** Created consistent cohort periods and date-based calculations for retention analysis.

---

## 📁 Repository Structure

```text
marketing-analytics-mysql-powerbi/
│
├── README.md
│
├── data/
│   └── raw/
│       ├── customers.csv
│       ├── campaigns.csv
│       ├── campaign_performance.csv
│       ├── conversions.csv
│       ├── transactions.csv
│       ├── activity.csv
│   
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

## 🚀 How to Run the Project

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/marketing-analytics-mysql-powerbi.git
```

### 2. Navigate to the Project

```bash
cd marketing-analytics-mysql-powerbi
```

### 3. Set Up MySQL

Install **MySQL 8.0+** and create a database for the project.

### 4. Load the Raw Data

Place the CSV files inside:

```text
data/raw/
```

### 5. Run the SQL Scripts

Run the scripts in this order:

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

### 6. Open the Power BI Dashboard

Open:

```text
powerbi/marketing_analytics.pbix
```

Connect Power BI to the MySQL database and refresh the data if required.

---

## 🔮 Future Work

Potential extensions include:

* More detailed marketing attribution
* Customer segmentation
* Predictive customer LTV
* Campaign response prediction
* Marketing budget optimization
* Automated reporting
* Incrementality and experiment analysis

---

## 📬 Contact

**Priyanka Lakra**
Data Analyst | SQL · Power BI · Business Analytics
Open to data Roles

