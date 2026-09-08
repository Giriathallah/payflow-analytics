SELECT
    event_id,
    payment_id,
    merchant_id,
    from_status,
    to_status,
    reason,
    payment_version,
    occurred_at,
    ingested_at,
    pipeline_latency_ms
FROM {{ source('payflow_core', 'fact_payment_status_events') }}
