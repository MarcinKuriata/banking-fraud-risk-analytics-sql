-- ==============================================================================
-- File: 05_customer_risk_profile.sql
-- Description: Customer-level behavioral aggregation & risk segmentation view.
-- Engine: Google BigQuery
-- ==============================================================================

CREATE OR REPLACE VIEW `project-80dc6d63-b4dc-4c88-a56.banking_dw.v_dim_user_risk_profile` AS
WITH user_aggregates AS (
  SELECT
    user_id,
    
    -- Transaction volume and exposure metrics
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT card_id) AS total_cards_used,
    ROUND(SUM(amount), 2) AS total_spend_usd,
    ROUND(AVG(amount), 2) AS avg_ticket_size_usd,
    MAX(amount) AS max_single_transaction_usd,
    
    -- Activity timeline
    MIN(transaction_datetime) AS first_seen_datetime,
    MAX(transaction_datetime) AS last_seen_datetime,
    
    -- Risk flag counters
    SUM(flag_impossible_travel) AS count_impossible_travel_flags,
    SUM(flag_spend_outlier) AS count_spend_outlier_flags,
    SUM(flag_rapid_velocity) AS count_velocity_flags,
    
    -- Transactions by risk category tier
    COUNTIF(risk_category = 'HIGH') AS count_high_risk_txns,
    COUNTIF(risk_category = 'MEDIUM') AS count_medium_risk_txns,
    COUNTIF(risk_category = 'LOW') AS count_low_risk_txns,
    
    -- Actual confirmed fraud exposure
    SUM(is_fraud_numeric) AS total_fraud_transactions,
    ROUND(SUM(IF(is_fraud_numeric = 1, amount, 0)), 2) AS total_fraud_amount_lost_usd

  FROM `project-80dc6d63-b4dc-4c88-a56.banking_dw.v_fact_fraud_monitoring`
  GROUP BY user_id
)
SELECT
  user_id,
  total_transactions,
  total_cards_used,
  CAST(total_spend_usd AS NUMERIC) AS total_spend_usd,
  CAST(avg_ticket_size_usd AS NUMERIC) AS avg_ticket_size_usd,
  CAST(max_single_transaction_usd AS NUMERIC) AS max_single_transaction_usd,
  first_seen_datetime,
  last_seen_datetime,
  
  count_impossible_travel_flags,
  count_spend_outlier_flags,
  count_velocity_flags,
  count_high_risk_txns,
  count_medium_risk_txns,
  count_low_risk_txns,
  
  total_fraud_transactions,
  CAST(total_fraud_amount_lost_usd AS NUMERIC) AS total_fraud_amount_lost_usd,
  
  -- Elevated risk exposure rate (% of transactions tagged as HIGH or MEDIUM)
  ROUND((count_high_risk_txns + count_medium_risk_txns) / total_transactions * 100, 2) AS elevated_risk_rate_pct,
  
  -- Customer behavioral risk segmentation
  CASE 
    WHEN total_fraud_transactions > 0 THEN 'CONFIRMED_VICTIM'
    WHEN count_high_risk_txns >= 3 THEN 'HIGH_SUSPICION'
    WHEN count_medium_risk_txns >= 10 THEN 'ELEVATED_ACTIVITY'
    ELSE 'STANDARD'
  END AS customer_risk_segment

FROM user_aggregates;