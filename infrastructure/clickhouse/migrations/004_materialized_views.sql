-- ============================================================
-- 004: Materialized views — Kafka engine → raw tables
-- Each MV reads from the corresponding kafka_* table and
-- inserts into the raw CDC table.
-- ============================================================

-- ---------- merchants ----------
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_raw.mv_kafka_merchants
TO payflow_raw.merchant_cdc_events AS
SELECT
    id                                                      AS merchant_id,
    external_id,
    name,
    category,
    city,
    fee_rate,
    is_active,
    __op                                                    AS source_operation,
    fromUnixTimestamp64Milli(toInt64(__source_ts_ms))        AS source_timestamp,
    now64(3)                                                AS ingested_at,
    if(__deleted = 'true', 1, 0)                            AS is_deleted
FROM payflow_raw.kafka_merchants;

-- ---------- payment_methods ----------
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_raw.mv_kafka_payment_methods
TO payflow_raw.payment_method_cdc_events AS
SELECT
    id                                                      AS payment_method_id,
    code,
    name,
    provider,
    type,
    is_active,
    __op                                                    AS source_operation,
    fromUnixTimestamp64Milli(toInt64(__source_ts_ms))        AS source_timestamp,
    now64(3)                                                AS ingested_at,
    if(__deleted = 'true', 1, 0)                            AS is_deleted
FROM payflow_raw.kafka_payment_methods;

-- ---------- payments ----------
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_raw.mv_kafka_payments
TO payflow_raw.payment_cdc_events AS
SELECT
    id                                                      AS payment_id,
    merchant_id,
    payment_method_id,
    external_reference,
    amount,
    fee_amount,
    net_amount,
    currency,
    status,
    failure_reason,
    version,
    parseDateTime64BestEffortOrNull(initiated_at, 3)        AS initiated_at,
    parseDateTime64BestEffortOrNull(authorized_at, 3)       AS authorized_at,
    parseDateTime64BestEffortOrNull(captured_at, 3)         AS captured_at,
    parseDateTime64BestEffortOrNull(settled_at, 3)          AS settled_at,
    __op                                                    AS source_operation,
    fromUnixTimestamp64Milli(toInt64(__source_ts_ms))        AS source_timestamp,
    now64(3)                                                AS ingested_at,
    if(__deleted = 'true', 1, 0)                            AS is_deleted
FROM payflow_raw.kafka_payments;

-- ---------- status_history ----------
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_raw.mv_kafka_status_history
TO payflow_raw.status_history_events AS
SELECT
    id                                                      AS event_id,
    payment_id,
    from_status,
    to_status,
    reason,
    payment_version,
    parseDateTime64BestEffort(occurred_at, 3)               AS occurred_at,
    __op                                                    AS source_operation,
    fromUnixTimestamp64Milli(toInt64(__source_ts_ms))        AS source_timestamp,
    now64(3)                                                AS ingested_at,
    if(__deleted = 'true', 1, 0)                            AS is_deleted
FROM payflow_raw.kafka_status_history;

-- ---------- refunds ----------
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_raw.mv_kafka_refunds
TO payflow_raw.refund_cdc_events AS
SELECT
    id                                                      AS refund_id,
    payment_id,
    refund_reference,
    amount,
    status,
    reason,
    __op                                                    AS source_operation,
    fromUnixTimestamp64Milli(toInt64(__source_ts_ms))        AS source_timestamp,
    now64(3)                                                AS ingested_at,
    if(__deleted = 'true', 1, 0)                            AS is_deleted
FROM payflow_raw.kafka_refunds;

-- ---------- settlement_batches ----------
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_raw.mv_kafka_settlement_batches
TO payflow_raw.settlement_batch_cdc_events AS
SELECT
    id                                                      AS batch_id,
    merchant_id,
    settlement_reference,
    toDate(settlement_date)                                 AS settlement_date,
    gross_amount,
    fee_amount,
    refund_amount,
    expected_net_amount,
    actual_net_amount,
    status,
    __op                                                    AS source_operation,
    fromUnixTimestamp64Milli(toInt64(__source_ts_ms))        AS source_timestamp,
    now64(3)                                                AS ingested_at,
    if(__deleted = 'true', 1, 0)                            AS is_deleted
FROM payflow_raw.kafka_settlement_batches;

-- ---------- settlement_items ----------
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_raw.mv_kafka_settlement_items
TO payflow_raw.settlement_item_cdc_events AS
SELECT
    id                                                      AS item_id,
    settlement_batch_id,
    payment_id,
    expected_amount,
    actual_amount,
    reconciliation_status,
    __op                                                    AS source_operation,
    fromUnixTimestamp64Milli(toInt64(__source_ts_ms))        AS source_timestamp,
    now64(3)                                                AS ingested_at,
    if(__deleted = 'true', 1, 0)                            AS is_deleted
FROM payflow_raw.kafka_settlement_items;
