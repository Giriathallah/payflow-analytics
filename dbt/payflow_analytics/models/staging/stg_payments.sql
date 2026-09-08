SELECT
    payment_id,
    merchant_id,
    payment_method_id,
    external_reference,
    amount,
    fee_amount,
    net_amount,
    currency,
    status,
    failure_reason,
    latest_version AS version,
    initiated_at,
    authorized_at,
    captured_at,
    settled_at
FROM {{ source('payflow_core', 'v_payments_latest') }}
