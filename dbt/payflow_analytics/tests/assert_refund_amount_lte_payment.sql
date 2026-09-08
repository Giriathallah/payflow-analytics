-- Singular test: Ensure refund amount does not exceed payment gross amount
SELECT
    r.refund_id,
    r.payment_id,
    r.refund_amount,
    p.amount AS gross_amount
FROM {{ ref('stg_refunds') }} r
JOIN {{ ref('stg_payments') }} p ON r.payment_id = p.payment_id
WHERE r.refund_amount > p.amount
