SELECT
    i.item_id,
    i.settlement_batch_id,
    i.payment_id,
    b.merchant_id,
    b.settlement_date,
    i.expected_amount,
    i.actual_amount,
    i.actual_amount - i.expected_amount AS difference,
    i.reconciliation_status
FROM {{ ref('stg_settlement_items') }} i
LEFT JOIN {{ ref('stg_settlement_batches') }} b ON i.settlement_batch_id = b.batch_id
