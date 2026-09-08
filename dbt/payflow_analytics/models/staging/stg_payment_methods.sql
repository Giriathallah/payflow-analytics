SELECT
    payment_method_id,
    code AS payment_method_code,
    name AS payment_method_name,
    provider,
    type AS payment_type,
    is_active
FROM {{ source('payflow_core', 'payment_methods_current') }}
