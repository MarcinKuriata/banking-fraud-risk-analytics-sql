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
[Risk & Velocity Analytics] (Window Functions, CTEs, spend thresholds)
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
  - Data hygiene & null handling: `IFNULL()`
  - Metric flag conversion: `IF(Is_Fraud_, 1, 0)`
  - Window Functions (In Progress): `LAG()`, `LEAD()`, `SUM() OVER ()`, `AVG() OVER ()`

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

### Phase 1: Data Engineering & Staging Layer (`stg_transactions`) [DONE]
* Reconstructed standardized timestamps (`transaction_datetime`) by parsing string time formats (`HH:MM`) combined with year, month, and day integers.
* Cleaned error states by transforming `NULL` fields into explicit `'None'` categories for reliable aggregation and filtering.
* Normalized boolean fraud indicators into binary integers (`1`/`0`) to support direct calculations of `SUM(is_fraud)` and transaction fraud rates (`AVG(is_fraud)`).

### Phase 2: Transaction Monitoring & Window Analytics [IN PROGRESS]
* Velocity Checks: identifying transaction bursts (< 120s between consecutive operations on the same card).
* Cumulative Spend: tracking running daily totals per user using partitioned window frames.
* Baseline Profiling: rolling 30-day average spend to flag out-of-pattern spikes.