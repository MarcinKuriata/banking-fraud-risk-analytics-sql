-- ==============================================================================
-- File: 03_fraud_risk_scoring_rules.sql
-- Description: Multi-factor fraud risk rules: Spend Outliers & Impossible Travel anomalies.
-- Engine: Google BigQuery
-- ==============================================================================

WITH enriched_transactions AS (
  SELECT
    user_id,
    card_id,
    transaction_datetime,
    transaction_date,
    merchant_name,
    merchant_state,
    merchant_city,
    amount,
    is_fraud_numeric,

    -- Preceding merchant location for the same card
    LAG(merchant_state) OVER (
      PARTITION BY user_id, card_id 
      ORDER BY transaction_datetime ASC
    ) AS prev_merchant_state,

    -- Preceding transaction timestamp for the same card
    LAG(transaction_datetime) OVER (
      PARTITION BY user_id, card_id 
      ORDER BY transaction_datetime ASC
    ) AS prev_transaction_datetime,

    -- Trailing 10-transaction spend baseline (excluding current transaction)
    AVG(amount) OVER (
      PARTITION BY user_id 
      ORDER BY transaction_datetime ASC
      ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING
    ) AS avg_past_10_spend

  FROM `project-80dc6d63-b4dc-4c88-a56.banking_dw.stg_transactions`
)
SELECT
  user_id,
  card_id,
  transaction_datetime,
  merchant_name,
  merchant_state,
  prev_merchant_state,
  amount,
  ROUND(avg_past_10_spend, 2) AS avg_past_10_spend,
  is_fraud_numeric,

  -- Elapsed time in minutes since preceding transaction
  DATETIME_DIFF(transaction_datetime, prev_transaction_datetime, MINUTE) AS time_diff_minutes,

  -- Rule 1: Impossible Travel Anomaly (physical state jump in < 60 minutes)
  CASE 
    WHEN prev_merchant_state IS NOT NULL 
     AND merchant_state IS NOT NULL
     AND merchant_state != 'None'
     AND prev_merchant_state != 'None'
     AND merchant_state != prev_merchant_state 
     AND DATETIME_DIFF(transaction_datetime, prev_transaction_datetime, MINUTE) < 60 THEN 1
    ELSE 0 
  END AS is_impossible_travel,

  -- Rule 2: Spend Outlier Anomaly (transaction > 3x trailing average and >= $100)
  CASE 
    WHEN avg_past_10_spend IS NOT NULL 
     AND amount > (avg_past_10_spend * 3) 
     AND amount >= 100 THEN 1 
    ELSE 0 
  END AS is_spend_outlier

FROM enriched_transactions;