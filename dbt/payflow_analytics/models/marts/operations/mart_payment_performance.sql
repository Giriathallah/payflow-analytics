{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='tuple()'
) }}

SELECT
    assumeNotNull(toDate(p.initiated_at)) AS date,
    toHour(p.initiated_at) AS hour,
    coalesce(pm.payment_method_name, 'UNKNOWN') AS payment_method,
    coalesce(pm.provider, 'UNKNOWN') AS provider,
    count(p.payment_id) AS transaction_count,
    countIf(p.status IN ('CAPTURED', 'SETTLED')) AS success_count,
    countIf(p.status IN ('FAILED', 'EXPIRED')) AS failure_count,
    if(count(p.payment_id) > 0, countIf(p.status IN ('CAPTURED', 'SETTLED')) / count(p.payment_id), 0) AS success_rate,
    sum(p.amount) AS gross_amount,
    avg(p.amount) AS average_amount
FROM {{ ref('stg_payments') }} p
LEFT JOIN {{ ref('stg_payment_methods') }} pm ON p.payment_method_id = pm.payment_method_id
GROUP BY date, hour, payment_method, provider
