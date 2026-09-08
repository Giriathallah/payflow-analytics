SELECT
    payment_id,
    merchant_id,
    payment_method_id,
    status AS final_status,
    initiated_at,
    authorized_at,
    captured_at,
    settled_at,
    toInt64(dateDiff('millisecond', initiated_at, authorized_at)) AS authorization_duration_ms,
    toInt64(dateDiff('millisecond', authorized_at, captured_at)) AS capture_duration_ms,
    toInt64(dateDiff('millisecond', captured_at, settled_at)) AS settlement_duration_ms,
    toInt64(dateDiff('millisecond', initiated_at, coalesce(settled_at, captured_at, authorized_at, initiated_at))) AS total_lifecycle_duration_ms
FROM {{ ref('stg_payments') }}
