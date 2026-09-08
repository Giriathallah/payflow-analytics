SELECT
    refund_id,
    payment_id,
    refund_reference,
    amount AS refund_amount,
    status AS refund_status,
    reason AS refund_reason,
    source_timestamp AS refunded_at
FROM {{ source('payflow_core', 'refunds_current') }}
WHERE is_deleted = 0
