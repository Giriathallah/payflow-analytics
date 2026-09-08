SELECT
    toDate(p.initiated_at) AS payment_date,
    p.merchant_id,
    m.merchant_name,
    m.merchant_category,
    count(p.payment_id) AS total_transactions,
    countIf(p.status IN ('CAPTURED', 'SETTLED')) AS successful_transactions,
    countIf(p.status IN ('FAILED', 'EXPIRED')) AS failed_transactions,
    sum(p.gross_amount) AS gross_amount,
    sum(p.fee_amount) AS total_fee_amount,
    sum(p.refund_amount) AS total_refund_amount,
    sum(p.net_amount) AS net_settlement_amount,
    if(count(p.payment_id) > 0, countIf(p.status IN ('CAPTURED', 'SETTLED')) / count(p.payment_id), 0) AS success_rate
FROM {{ ref('int_payment_financials') }} p
LEFT JOIN {{ ref('stg_merchants') }} m ON p.merchant_id = m.merchant_id
GROUP BY payment_date, p.merchant_id, m.merchant_name, m.merchant_category
