-- Singular test: Ensure all payments have a positive amount (amount > 0)
SELECT
    payment_id,
    amount
FROM {{ ref('stg_payments') }}
WHERE amount <= 0
