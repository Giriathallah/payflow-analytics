-- Singular test: Ensure payments with status 'SETTLED' have a non-null captured_at timestamp
SELECT
    payment_id,
    status,
    captured_at
FROM {{ ref('stg_payments') }}
WHERE status = 'SETTLED'
  AND captured_at IS NULL
