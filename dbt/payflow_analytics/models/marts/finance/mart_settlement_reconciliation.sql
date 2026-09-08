{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='(settlement_date, merchant_id, batch_id)'
) }}

SELECT
    b.settlement_date,
    b.merchant_id,
    b.batch_id,
    b.expected_net_amount AS expected_amount,
    b.actual_net_amount AS actual_amount,
    b.actual_net_amount - b.expected_net_amount AS difference,
    countIf(i.reconciliation_status = 'MATCHED') AS matched_count,
    countIf(i.reconciliation_status = 'AMOUNT_MISMATCH') AS mismatch_count,
    countIf(i.reconciliation_status = 'MISSING') AS missing_count,
    countIf(i.reconciliation_status = 'DUPLICATE') AS duplicate_count,
    b.settlement_status AS reconciliation_status
FROM {{ ref('stg_settlement_batches') }} b
LEFT JOIN {{ ref('stg_settlement_items') }} i ON b.batch_id = i.settlement_batch_id
GROUP BY settlement_date, merchant_id, batch_id, expected_amount, actual_amount, difference, reconciliation_status
