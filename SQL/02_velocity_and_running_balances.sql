-- ==============================================================================
-- File: 02_velocity_and_running_balances.sql
-- Description: Window analytics for transaction velocity and cumulative daily spend.
-- Engine: Google BigQuery
-- ==============================================================================

WITH lagged_transactions AS (
  SELECT
    user_id,
    card_id,
    transaction_datetime,
    transaction_date,
    merchant_name,
    amount,
    is_fraud_numeric,

    -- Retrieve preceding transaction timestamp for the same card
    LAG(transaction_datetime) OVER (
      PARTITION BY user_id, card_id 
      ORDER BY transaction_datetime ASC
    ) AS prev_transaction_datetime,

    -- Retrieve preceding merchant identifier for the same card
    LAG(merchant_name) OVER (
      PARTITION BY user_id, card_id 
      ORDER BY transaction_datetime ASC
    ) AS prev_merchant_name

  FROM `project-80dc6d63-b4dc-4c88-a56.banking_dw.stg_transactions`
)
SELECT
  user_id,
  card_id,
  transaction_datetime,
  transaction_date,
  merchant_name,
  amount,
  is_fraud_numeric,

  -- 1. Elapsed time in minutes since the previous transaction
  DATETIME_DIFF(transaction_datetime, prev_transaction_datetime, MINUTE) AS time_diff_mins,

  -- 2. Rapid-fire velocity flag: gap <= 2 mins, different merchant, amount >= $100
  CASE 
    WHEN DATETIME_DIFF(transaction_datetime, prev_transaction_datetime, MINUTE) <= 2
     AND merchant_name != prev_merchant_name
     AND amount >= 100 THEN 1
    ELSE 0 
  END AS is_suspicious_velocity,

  -- 3. Running daily spend accumulation per user
  SUM(amount) OVER (
    PARTITION BY user_id, transaction_date 
    ORDER BY transaction_datetime ASC
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS running_daily_spend

FROM lagged_transactions
ORDER BY user_id, card_id, transaction_datetime;