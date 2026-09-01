# Banking & Credit Card Fraud Risk Analytics (SQL & Power BI)

## Executive Summary
An end-to-end financial data analytics project simulating a core banking transaction monitoring and risk intelligence pipeline. The project focuses on data quality engineering, velocity fraud detection, rolling spend patterns, and customer behavioral risk scoring using Google BigQuery and Power BI.

---

## Data Pipeline Flow

```text
[Raw CSV Datasets] 
       |
       v
[Google Cloud Storage (GCS)] 
       |
       v
[Google BigQuery: RAW Layer] (raw_transactions, raw_cards, raw_users)
       |
       v
[Staging & Transformation] (stg_transactions: ISO-8601 parsing, type casting, flag normalization)
       |
       v
[Risk & Behavioral Analytics] (Window Functions, CTEs, spend thresholds, geo-velocity)
       |
       v
[BI Layer & Reporting] (Power BI KPIs & Risk Dashboards)
```

---

## Tech Stack & Methods
* **Database Engine:** Google BigQuery (Standard SQL)
* **Cloud Storage:** Google Cloud Storage (GCS)
* **Data Modeling:** Star Schema (Fact: Transactions | Dims: Users, Cards, Merchants)
* **Key SQL Techniques:**
  - Datetime reconstruction: `DATETIME()`, `SPLIT()`, `CAST()`
  - Data hygiene & null handling: `IFNULL()`, `COALESCE()`
  - Metric flag conversion: `IF(Is_Fraud_, 1, 0)`
  - Window Functions: `LAG()`, `DATETIME_DIFF()`, `AVG() OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING)`

---

## Repository Structure

```text
banking-fraud-risk-analytics-sql/
/-- sql/
    +-- 01_data_cleaning_and_staging.sql
    +-- 02_velocity_and_running_balances.sql
    +-- 03_fraud_risk_scoring_rules.sql
    +-- 04_customer_segmentation_rfm.sql
/-- data/
    +-- .gitkeep
+-- .gitignore
+-- README.md
```

---

## Analytical Roadmap & Progress

### Phase 1: Data Engineering & Staging Layer 
(`01_data_cleaning_and_staging.sql`) [DONE]
* Reconstructed standardized ISO-8601 timestamps (`transaction_datetime`) by parsing string time formats (`HH:MM`) combined with year, month, and day integers.
* Cleaned error states by transforming `NULL` fields into explicit `'None'` categories for reliable aggregation and filtering.
* Normalized boolean fraud indicators into binary integers (`1`/`0`) to support direct calculations of `SUM(is_fraud)` and transaction fraud rates (`AVG(is_fraud)`).

### Phase 2: Transaction Monitoring & Window Analytics
(`02_velocity_and_running_balances.sql`) [DONE]
* Implemented `LAG()` over partitioned user/card windows to track consecutive transaction gaps (`time_diff_mins`).
* Constructed a **Rapid-Fire Velocity** flag identifying high-risk bursts: interval $\le$ 2 minutes across distinct merchants with spend $\ge$ 100 USD.
* Engineered a cumulative daily balance metric (`running_daily_spend`) using partitioned running sums (`ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`).

### Phase 3: Outlier & Risk Threshold Rules 
(`03_fraud_risk_scoring_rules.sql`) [DONE]
* **Spend Outlier Detection:** Calculated trailing 10-transaction rolling baseline spend (`ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING`) to flag anomalous spend surges exceeding $3\times$ historical customer average.
* **Impossible Travel Velocity:** Engineered geographic anomaly detection tracking multi-state physical transitions occurring under 60 minutes.

### Phase 4: Customer Risk Profiling & Summary Table
(`04_customer_segmentation_rfm.sql`) [NEXT STEP]
* Consolidating transaction flags into customer-level risk aggregates.
* Exporting clean analytical marts for Power BI dashboarding.