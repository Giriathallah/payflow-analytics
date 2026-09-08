SELECT
    batch_id,
    merchant_id,
    settlement_reference,
    settlement_date,
    gross_amount,
    fee_amount,
    refund_amount,
    expected_net_amount,
    actual_net_amount,
    status AS settlement_status
FROM {{ source('payflow_core', 'settlement_batches_current') }}
WHERE is_deleted = 0
