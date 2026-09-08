-- ============================================================
-- Superset Dashboard 3: Merchant Analytics Queries
-- Database: payflow_mart
-- ============================================================

-- 1. Chart: Top Merchants by Payment Volume
SELECT
    merchant_name,
    sum(gross_amount) AS total_gross_volume,
    sum(transaction_count) AS total_transactions
FROM payflow_mart.mart_merchant_daily_performance
GROUP BY merchant_name
ORDER BY total_gross_volume DESC
LIMIT 10;

-- 2. Chart: Merchant Success Rate Comparison
SELECT
    merchant_name,
    sum(successful_transaction_count) AS success_tx,
    sum(transaction_count) AS total_tx,
    round(sum(successful_transaction_count) / sum(transaction_count) * 100, 2) AS success_rate_pct
FROM payflow_mart.mart_merchant_daily_performance
GROUP BY merchant_name
ORDER BY success_rate_pct DESC;

-- 3. Chart: Merchant Fee Contribution
SELECT
    merchant_name,
    sum(fee_amount) AS total_fee_contributed
FROM payflow_mart.mart_merchant_daily_performance
GROUP BY merchant_name
ORDER BY total_fee_contributed DESC;

-- 4. Chart: Refund Rate per Merchant
SELECT
    merchant_name,
    sum(refund_amount) AS total_refunds,
    sum(gross_amount) AS gross_volume,
    if(sum(gross_amount) > 0, round(sum(refund_amount) / sum(gross_amount) * 100, 2), 0) AS refund_rate_pct
FROM payflow_mart.mart_merchant_daily_performance
GROUP BY merchant_name
ORDER BY refund_rate_pct DESC;

-- 5. Chart: Net Settlement per Merchant
SELECT
    merchant_name,
    sum(net_settlement) AS total_net_settlement
FROM payflow_mart.mart_merchant_daily_performance
GROUP BY merchant_name
ORDER BY total_net_settlement DESC;
