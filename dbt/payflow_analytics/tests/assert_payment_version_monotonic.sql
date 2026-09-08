-- Singular test: Ensure payment version is always positive (> 0)
SELECT
    payment_id,
    version
FROM {{ ref('stg_payments') }}
WHERE version <= 0
