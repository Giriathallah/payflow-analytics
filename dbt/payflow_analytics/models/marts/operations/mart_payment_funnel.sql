{{ config(
    materialized='table',
    engine='MergeTree()',
    order_by='(date, merchant_id)'
) }}

SELECT
    toDate(occurred_at) AS date,
    merchant_id,
    countIf(to_status = 'INITIATED') AS initiated_count,
    countIf(to_status = 'AUTHORIZED') AS authorized_count,
    countIf(to_status = 'CAPTURED') AS captured_count,
    countIf(to_status = 'SETTLED') AS settled_count,
    countIf(to_status = 'FAILED') AS failed_count,
    countIf(to_status = 'REFUNDED') AS refunded_count
FROM {{ ref('stg_payment_status_events') }}
GROUP BY date, merchant_id
