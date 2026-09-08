WITH payments AS (
    SELECT
        payment_id,
        merchant_id,
        payment_method_id,
        amount AS gross_amount,
        fee_amount,
        net_amount,
        status,
        initiated_at
    FROM {{ ref('stg_payments') }}
),
refunds_agg AS (
    SELECT
        payment_id,
        sum(refund_amount) AS total_refund_amount
    FROM {{ ref('stg_refunds') }}
    WHERE refund_status = 'COMPLETED'
    GROUP BY payment_id
)
SELECT
    p.payment_id,
    p.merchant_id,
    p.payment_method_id,
    p.gross_amount,
    p.fee_amount,
    coalesce(r.total_refund_amount, 0) AS refund_amount,
    p.gross_amount - p.fee_amount - coalesce(r.total_refund_amount, 0) AS net_amount,
    p.status,
    p.initiated_at
FROM payments p
LEFT JOIN refunds_agg r ON p.payment_id = r.payment_id
