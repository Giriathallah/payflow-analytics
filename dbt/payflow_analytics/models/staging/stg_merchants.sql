SELECT
    merchant_id,
    external_id,
    name AS merchant_name,
    category AS merchant_category,
    city AS merchant_city,
    fee_rate,
    is_active
FROM {{ source('payflow_core', 'v_merchants_latest') }}
