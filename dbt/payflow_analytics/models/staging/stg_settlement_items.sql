SELECT
    item_id,
    settlement_batch_id,
    payment_id,
    expected_amount,
    actual_amount,
    reconciliation_status
FROM {{ source('payflow_core', 'settlement_items_current') }}
WHERE is_deleted = 0
