-- Singular test: Ensure actual net settlement amount in batches is non-negative (>= 0)
SELECT
    batch_id,
    actual_net_amount
FROM {{ ref('stg_settlement_batches') }}
WHERE actual_net_amount < 0
