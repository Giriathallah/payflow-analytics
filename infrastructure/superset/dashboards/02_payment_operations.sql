-- ============================================================
-- Superset Dashboard 2: Payment Operations Queries
-- Database: payflow_mart
-- ============================================================

-- 1. Chart: Hourly Transaction Volume (TPH)
SELECT
    date,
    hour,
    sum(transaction_count) AS total_transactions,
    sum(success_count) AS success_transactions,
    sum(failure_count) AS failed_transactions
FROM payflow_mart.mart_payment_performance
GROUP BY date, hour
ORDER BY date ASC, hour ASC;

-- 2. Chart: Success vs Failure Distribution
SELECT
    'Success' AS category,
    sum(success_count) AS count
FROM payflow_mart.mart_payment_performance
UNION ALL
SELECT
    'Failure' AS category,
    sum(failure_count) AS count
FROM payflow_mart.mart_payment_performance;

-- 3. Chart: Payment Funnel
SELECT
    sum(initiated_count) AS initiated,
    sum(authorized_count) AS authorized,
    sum(captured_count) AS captured,
    sum(settled_count) AS settled,
    sum(failed_count) AS failed,
    sum(refunded_count) AS refunded
FROM payflow_mart.mart_payment_funnel;

-- 4. Chart: Failure Reasons Breakdown
SELECT
    failure_reason,
    sum(failure_count) AS total_failures,
    sum(failed_amount) AS total_failed_amount
FROM payflow_mart.mart_failure_analysis
GROUP BY failure_reason
ORDER BY total_failures DESC;

-- 5. Chart: Payment Method Performance
SELECT
    payment_method,
    sum(transaction_count) AS total_transactions,
    sum(success_count) AS successful_transactions,
    round(sum(success_count) / sum(transaction_count) * 100, 2) AS success_rate_pct,
    sum(gross_amount) AS gross_amount
FROM payflow_mart.mart_payment_performance
GROUP BY payment_method
ORDER BY total_transactions DESC;

-- 6. Chart: Provider Performance Comparison
SELECT
    provider,
    sum(transaction_count) AS total_transactions,
    sum(success_count) AS successful_transactions,
    round(sum(success_count) / sum(transaction_count) * 100, 2) AS success_rate_pct,
    sum(gross_amount) AS gross_amount
FROM payflow_mart.mart_payment_performance
GROUP BY provider
ORDER BY total_transactions DESC;
