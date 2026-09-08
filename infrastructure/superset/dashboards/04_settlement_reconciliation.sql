-- ============================================================
-- Superset Dashboard 4: Settlement Reconciliation Queries
-- Database: payflow_mart
-- ============================================================

-- 1. Chart: Matched vs Mismatch Item Count Summary
SELECT
    'Matched' AS category, sum(matched_count) AS count FROM payflow_mart.mart_settlement_reconciliation
UNION ALL
SELECT
    'Amount Mismatch' AS category, sum(mismatch_count) AS count FROM payflow_mart.mart_settlement_reconciliation
UNION ALL
SELECT
    'Missing' AS category, sum(missing_count) AS count FROM payflow_mart.mart_settlement_reconciliation
UNION ALL
SELECT
    'Duplicate' AS category, sum(duplicate_count) AS count FROM payflow_mart.mart_settlement_reconciliation;

-- 2. Chart: Expected vs Actual Net Settlement by Date
SELECT
    settlement_date,
    sum(expected_amount) AS total_expected,
    sum(actual_amount) AS total_actual,
    sum(difference) AS net_discrepancy
FROM payflow_mart.mart_settlement_reconciliation
GROUP BY settlement_date
ORDER BY settlement_date ASC;

-- 3. Chart: Missing Settlement Items Detail
SELECT
    settlement_date,
    merchant_id,
    batch_id,
    missing_count
FROM payflow_mart.mart_settlement_reconciliation
WHERE missing_count > 0
ORDER BY settlement_date DESC;

-- 4. Chart: Duplicate Settlement Items Detail
SELECT
    settlement_date,
    merchant_id,
    batch_id,
    duplicate_count
FROM payflow_mart.mart_settlement_reconciliation
WHERE duplicate_count > 0
ORDER BY settlement_date DESC;

-- 5. Chart: Mismatch Breakdown by Merchant
SELECT
    merchant_id,
    sum(mismatch_count) AS total_mismatches,
    sum(difference) AS total_amount_difference
FROM payflow_mart.mart_settlement_reconciliation
GROUP BY merchant_id
HAVING total_mismatches > 0 OR total_amount_difference != 0
ORDER BY total_mismatches DESC;

-- 6. Chart: Reconciliation Batch Status Trend
SELECT
    settlement_date,
    reconciliation_status,
    count(batch_id) AS batch_count
FROM payflow_mart.mart_settlement_reconciliation
GROUP BY settlement_date, reconciliation_status
ORDER BY settlement_date ASC;
