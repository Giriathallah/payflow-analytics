-- ============================================================
-- Superset Dashboard 1: Executive Overview Queries
-- Database: payflow_mart
-- Connection configured through CLICKHOUSE_* environment variables
-- ============================================================

-- 1. KPI: Total Payment Volume (IDR)
SELECT sum(gross_amount) AS total_payment_volume
FROM payflow_mart.mart_payment_performance;

-- 2. KPI: Total Transaction Count
SELECT sum(transaction_count) AS total_transactions
FROM payflow_mart.mart_payment_performance;

-- 3. KPI: Success Rate (%)
SELECT 
    if(sum(transaction_count) > 0, round(sum(success_count) / sum(transaction_count) * 100, 2), 0) AS success_rate_pct
FROM payflow_mart.mart_payment_performance;

-- 4. KPI: Total Fee Revenue (IDR)
SELECT sum(fee_amount) AS total_fee_revenue
FROM payflow_mart.mart_merchant_daily_performance;

-- 5. KPI: Total Refund Amount (IDR)
SELECT sum(refund_amount) AS total_refund_amount
FROM payflow_mart.mart_merchant_daily_performance;

-- 6. KPI: Net Settlement Amount (IDR)
SELECT sum(net_settlement) AS total_net_settlement
FROM payflow_mart.mart_merchant_daily_performance;

-- 7. KPI: Settlement Mismatch Amount (IDR)
SELECT sum(abs(difference)) AS total_mismatch_amount
FROM payflow_mart.mart_settlement_reconciliation
WHERE reconciliation_status != 'MATCHED';

-- 8. Chart: Daily Transaction Volume & Count Trend
SELECT
    date,
    sum(transaction_count) AS total_transactions,
    sum(successful_transaction_count) AS successful_transactions,
    sum(gross_amount) AS total_volume
FROM payflow_mart.mart_merchant_daily_performance
GROUP BY date
ORDER BY date ASC;
