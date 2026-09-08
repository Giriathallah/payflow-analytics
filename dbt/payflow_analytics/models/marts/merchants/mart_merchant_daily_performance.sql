{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='tuple()'
) }}

SELECT
    assumeNotNull(payment_date) AS date,
    merchant_id,
    merchant_name,
    total_transactions AS transaction_count,
    successful_transactions AS successful_transaction_count,
    gross_amount,
    total_fee_amount AS fee_amount,
    total_refund_amount AS refund_amount,
    net_settlement_amount AS net_settlement,
    success_rate
FROM {{ ref('int_merchant_daily_payments') }}
