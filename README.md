# Banking & Credit Card Fraud Risk Analytics (SQL & BigQuery)

## Executive Summary
An end-to-end financial data analytics and risk monitoring pipeline built on **24.3 million credit card transactions** using **Google BigQuery**. The project follows a strict dimensional modeling and staging workflow (Raw $\rightarrow$ Staging $\rightarrow$ Risk Modeling $\rightarrow$ Analytical Data Marts) designed to detect transaction velocity bursts, geographic travel anomalies, and customer spend outliers.

---

## Architecture & End-to-End Workflow

```text
[Raw CSVs: 24.3M records] 
       │
       ▼
[GCS & BigQuery RAW Layer] (raw_transactions, raw_cards, raw_users)
       │
       ▼ (Phase 1: 01_data_cleaning_and_staging.sql)
[Staging Layer: stg_transactions]
       │
       ▼ (Phase 2: 02_velocity_and_running_balances.sql)
[Velocity & Running Balances Analytics]
       │
       ▼ (Phase 3: 03_fraud_risk_scoring_rules.sql)
[Multi-Factor Anomaly & Outlier Detection]
       │
       ▼ (Phase 4: 04_fraud_risk_mart.sql)
[Analytical Fact Mart: v_fact_fraud_monitoring] (Risk Score 0-100 pts)
       │
       ▼ (Phase 5: 05_customer_risk_profile.sql)
[Analytical Dimension Mart: v_dim_user_risk_profile] (Customer Segmentation)
```

---

## Step-by-Step Implementation & Empirical Findings

### Phase 1: Data Hygiene, Parsing & Staging (`01_data_cleaning_and_staging.sql`)
* **Objective:** Clean raw ingested tables, handle messy e-commerce null values, and standardize date formats into query-optimized types.
* **Key Operations:**
  - Parsed integer time components (`Year`, `Month`, `Day`, `Time`) into ISO-8601 timestamps (`DATETIME`).
  - Standardized empty merchant locations (`NULL` $\rightarrow$ `'None'`) to distinguish online e-commerce from physical in-store card swipes.
  - Converted string flags (`Is_Fraud?`) into binary indicators (`1`/`0`) as `is_fraud_numeric` to enable arithmetic aggregations and fraud rate calculations.
  - Cleaned currency strings (`$amount`) into numeric floats.

---

### Phase 2: Transaction Velocity & Running Balances (`02_velocity_and_running_balances.sql`)
* **Objective:** Detect rapid-fire transaction patterns and calculate intra-day cumulative spend exposure.
* **Key Operations:**
  - Implemented `LAG(transaction_datetime)` partitioned by `(user_id, card_id)` to calculate delta minutes (`time_diff_minutes`).
  - Implemented `LAG(merchant_name)` to identify merchant transitions.
  - Engineered **Rapid Velocity Flag:** consecutive transactions across distinct merchants within $\le 2$ minutes for amounts $\ge \$100$.
  - Calculated cumulative daily spend using running balance window frames: `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.

---

### Phase 3: Outlier Spend & Geographic Travel Anomalies (`03_fraud_risk_scoring_rules.sql`)
* **Objective:** Identify behavioral spend deviations and physically impossible travel hops.
* **Key Operations:**
  - **Spend Outliers:** Calculated a dynamic baseline using a trailing window frame:
    $$\text{Trailing 10-Txn Average} = \text{AVG}(amount) \text{ OVER (ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING)}$$
    Flagged spend surges exceeding $3\times$ historical baseline ($\ge \$100$).
  - **Impossible Travel:** Flagged physical state hops (`prev_merchant_state != merchant_state`) occurring within $< 60$ minutes, strictly excluding online transactions (`'None'`).

---

### Phase 4: Consolidating Multi-Factor Fraud Risk Mart (`04_fraud_risk_mart.sql`)
* **Objective:** Combine individual anomaly flags into a centralized transaction-level **Fraud Risk Score (0–100 points)** and categorize exposure into actionable tiers.
* **Scoring Weights:**
  - **Impossible Travel:** $40\text{ pts}$
  - **Spend Outlier:** $35\text{ pts}$
  - **Rapid Velocity:** $25\text{ pts}$
* **Risk Categorization:**
  - **HIGH:** $\ge 60\text{ pts}$ (Multiple severe anomalies)
  - **MEDIUM:** $25\text{--}59\text{ pts}$ (Single anomaly threshold breached)
  - **LOW:** $< 25\text{ pts}$ (Normal activity)

#### Results & Risk Tier Validation (`v_fact_fraud_monitoring`):
```sql
SELECT 
  risk_category,
  COUNT(*) AS total_transactions,
  SUM(is_fraud_numeric) AS fraud_transactions,
  ROUND(AVG(is_fraud_numeric) * 100, 3) AS fraud_rate_pct,
  ROUND(AVG(risk_score), 1) AS avg_risk_score,
  CAST(ROUND(SUM(amount), 2) AS NUMERIC) AS total_exposure_usd
FROM `project-80dc6d63-b4dc-4c88-a56.banking_dw.v_fact_fraud_monitoring`
GROUP BY risk_category
ORDER BY avg_risk_score DESC;
```

| Risk Category | Total Transactions | Fraud Transactions | Fraud Rate (%) | Avg Risk Score | Total Exposure (USD) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **HIGH** | 20,876 | 298 | **1.427%** | 71.5 | $5,798,847.12 |
| **MEDIUM** | 1,520,041 | 7,193 | **0.473%** | 35.2 | $324,972,037.24 |
| **LOW** | 22,845,983 | 22,266 | **0.097%** | 0.0 | $733,327,232.88 |

> **Key Analytical Takeaway:** The scoring model demonstrated strong monotonic risk separation. The **HIGH** category yielded a **1.427% fraud rate**—nearly **$15\times$ higher** than the baseline rate (**0.097%**)—while isolating only **0.08%** of the entire 24.3M transaction volume for high-priority operational review.

---

### Phase 5: Customer-Level Profiling & Behavioral Segmentation (`05_customer_risk_profile.sql`)
* **Objective:** Aggregate transaction-level signals to create a 360-degree behavioral risk profile on the customer dimension (`user_id`).
* **Segmentation Logic:**
  - **CONFIRMED_VICTIM:** Users with $\ge 1$ confirmed fraud transaction.
  - **HIGH_SUSPICION:** Users with $\ge 3$ HIGH-risk transactions but no confirmed fraud filed yet.
  - **ELEVATED_ACTIVITY:** Users with $\ge 10$ MEDIUM-risk transactions.
  - **STANDARD:** Users exhibiting regular spending patterns.

#### Results & Customer Segmentation Breakdown (`v_dim_user_risk_profile`):
```sql
SELECT 
  customer_risk_segment,
  COUNT(*) AS total_users,
  SUM(total_transactions) AS total_txns,
  SUM(total_fraud_transactions) AS total_frauds,
  CAST(ROUND(SUM(total_fraud_amount_lost_usd), 2) AS NUMERIC) AS total_fraud_losses_usd
FROM `project-80dc6d63-b4dc-4c88-a56.banking_dw.v_dim_user_risk_profile`
GROUP BY customer_risk_segment
ORDER BY total_frauds DESC;
```

| Customer Risk Segment | Total Users | Total Transactions | Total Confirmed Frauds | Total Direct Losses (USD) |
| :--- | :--- | :--- | :--- | :--- |
| **CONFIRMED_VICTIM** | 1,343 | 22,127,450 | 29,757 | **$3,231,338.63** |
| **HIGH_SUSPICION** | 181 | 1,877,732 | 0 | $0.00 |
| **ELEVATED_ACTIVITY** | 199 | 298,331 | 0 | $0.00 |
| **STANDARD** | 277 | 83,367 | 0 | $0.00 |

> **Key Analytical Takeaway:** All **$3.23M** in confirmed fraud losses were concentrated across 1,343 accounts. Crucially, the model identified a cohort of **181 HIGH_SUSPICION customers** displaying severe behavioral and travel anomalies, serving as a high-value candidate pool for preventive security measures.

---

## Repository Structure

```text
banking-fraud-risk-analytics-sql/
├── sql/
│   ├── 01_data_cleaning_and_staging.sql
│   ├── 02_velocity_and_running_balances.sql
│   ├── 03_fraud_risk_scoring_rules.sql
│   ├── 04_fraud_risk_mart.sql
│   └── 05_customer_risk_profile.sql
├── data/
│   └── .gitkeep
├── .gitignore
└── README.md
```

---

## Technical Stack & SQL Patterns Summary
* **Platform:** Google BigQuery (Standard SQL) & Google Cloud Storage
* **Window Specifications:**
  - `ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING` for leak-free rolling baselines.
  - `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` for intra-day running totals.
  - `LAG() OVER (PARTITION BY user_id, card_id ORDER BY transaction_datetime)` for sequential state-space tracking.
* **Data Typing & Precision:**
  - `CAST(... AS NUMERIC)` to enforce clean monetary formatting and suppress exponential notation.
  - `DATETIME_DIFF(..., MINUTE)` for precise inter-event temporal analytics.