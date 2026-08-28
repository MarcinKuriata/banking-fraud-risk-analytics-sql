-- ==============================================================================
-- File: 01_data_cleaning_and_staging.sql
-- Description: Staging layer transformation and data quality standardization.
-- Engine: Google BigQuery
-- ==============================================================================

CREATE OR REPLACE TABLE `project-80dc6d63-b4dc-4c88-a56.banking_dw.stg_transactions` AS
SELECT 
  -- Keys and ids ()
  CAST(User AS INT64) AS user_id,
  CAST(Card AS INT64) AS card_id,

  -- Convert to datetime
  DATETIME(
  Year, 
  Month, 
  Day,
  CAST(split(Time, ':')[offset(0)] as int64),
  CAST(split(Time, ':')[offset(01)] as int64), 
  0
  ) AS transaction_datetime,
  
  -- Convert to date
  DATE(Year, Month, Day) AS transaction_date,
  
  -- Transaction amount 
  Amount AS amount, 

  -- Transaction context 
  'Use Chip' AS transaction_method, 
  'Merchant Name' AS merchant_name, 
  'Merchant City' AS merchant_city,
  'Merchant State' AS merchant_state, 
  'Zip' AS zip_code, 
  'MCC' AS merchant_category_code, 

  -- Null to 'None' change 
  IFNULL(Errors_, 'None') AS error_reason,

  -- Is_Fraud convert to (0,1)
  IF(`Is Fraud_`, 1, 0) AS is_fraud_numeric
FROM 
  `project-80dc6d63-b4dc-4c88-a56.banking_dw.raw_transactions`