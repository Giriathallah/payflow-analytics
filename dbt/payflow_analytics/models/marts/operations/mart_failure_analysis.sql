{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='tuple()'
) }}

SELECT
    assumeNotNull(toDate(p.initiated_at)) AS date,
    coalesce(pm.payment_method_name, 'UNKNOWN') AS payment_method,
    coalesce(pm.provider, 'UNKNOWN') AS provider,
    coalesce(p.failure_reason, 'UNKNOWN') AS failure_reason,
    count(p.payment_id) AS failure_count,
    sum(p.amount) AS failed_amount
FROM {{ ref('stg_payments') }} p
LEFT JOIN {{ ref('stg_payment_methods') }} pm ON p.payment_method_id = pm.payment_method_id
WHERE p.status IN ('FAILED', 'EXPIRED')
GROUP BY date, payment_method, provider, failure_reason
