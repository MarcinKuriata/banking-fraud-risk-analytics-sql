-- ==============================================================================
-- File: 04_fraud_risk_mart.sql
-- Description: Analytical Mart View consolidating multi-factor risk scoring (0-100 pts)
-- Engine: Google BigQuery
-- ==============================================================================

CREATE OR REPLACE VIEW `project-80dc6d63-b4dc-4c88-a56.banking_dw.v_fact_fraud_monitoring` AS
WITH base_features AS (
  SELECT
    user_id,
    card_id,
    transaction_datetime,
    transaction_date,
    merchant_name,
    merchant_city,
    merchant_state,
    transaction_method,
    amount,
    is_fraud_numeric,

    -- Preceding location and timestamp for the card
    LAG(merchant_state) OVER (
      PARTITION BY user_id, card_id 
      ORDER BY transaction_datetime ASC
    ) AS prev_merchant_state,

    LAG(merchant_name) OVER (
      PARTITION BY user_id, card_id 
      ORDER BY transaction_datetime ASC
    ) AS prev_merchant_name,

    LAG(transaction_datetime) OVER (
      PARTITION BY user_id, card_id 
      ORDER BY transaction_datetime ASC
    ) AS prev_transaction_datetime,

    -- Trailing 10-transaction rolling baseline spend
    AVG(amount) OVER (
      PARTITION BY user_id 
      ORDER BY transaction_datetime ASC
      ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING
    ) AS avg_past_10_spend

  FROM `project-80dc6d63-b4dc-4c88-a56.banking_dw.stg_transactions`
),
risk_evaluated AS (
  SELECT
    user_id,
    card_id,
    transaction_datetime,
    transaction_date,
    merchant_name,
    merchant_city,
    merchant_state,
    transaction_method,
    amount,
    is_fraud_numeric,
    DATETIME_DIFF(transaction_datetime, prev_transaction_datetime, MINUTE) AS time_diff_minutes,
    
    -- Rule 1: Impossible Travel (Physical state jump in < 60 mins)
    CASE 
      WHEN prev_merchant_state IS NOT NULL 
       AND merchant_state IS NOT NULL 
       AND merchant_state != 'None' 
       AND prev_merchant_state != 'None' 
       AND merchant_state != prev_merchant_state 
       AND DATETIME_DIFF(transaction_datetime, prev_transaction_datetime, MINUTE) < 60 THEN 1
      ELSE 0 
    END AS flag_impossible_travel,

    -- Rule 2: Outlier Spend (>3x trailing 10-txn average and amount >= $100)
    CASE 
      WHEN avg_past_10_spend IS NOT NULL 
       AND amount > (avg_past_10_spend * 3) 
       AND amount >= 100 THEN 1 
      ELSE 0 
    END AS flag_spend_outlier,

    -- Rule 3: Rapid Velocity (burst txn at distinct merchant in <= 2 mins and amount >= $100)
    CASE 
      WHEN prev_merchant_name IS NOT NULL 
       AND merchant_name != prev_merchant_name 
       AND DATETIME_DIFF(transaction_datetime, prev_transaction_datetime, MINUTE) <= 2 
       AND amount >= 100 THEN 1 
      ELSE 0 
    END AS flag_rapid_velocity

  FROM base_features
)
SELECT
  user_id,
  card_id,
  transaction_datetime,
  transaction_date,
  merchant_name,
  merchant_city,
  merchant_state,
  transaction_method,
  amount,
  is_fraud_numeric,
  time_diff_minutes,
  flag_impossible_travel,
  flag_spend_outlier,
  flag_rapid_velocity,

  -- Fraud Risk Score (Weights: Travel 40 pts, Outlier Spend 35 pts, Velocity 25 pts)
  (flag_impossible_travel * 40 + flag_spend_outlier * 35 + flag_rapid_velocity * 25) AS risk_score,

  -- Risk Categorization Tier
  CASE 
    WHEN (flag_impossible_travel * 40 + flag_spend_outlier * 35 + flag_rapid_velocity * 25) >= 60 THEN 'HIGH'
    WHEN (flag_impossible_travel * 40 + flag_spend_outlier * 35 + flag_rapid_velocity * 25) >= 25 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS risk_category

FROM risk_evaluated;