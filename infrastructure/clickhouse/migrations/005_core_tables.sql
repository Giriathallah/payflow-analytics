-- ============================================================
-- 005: Core current-state tables (ReplacingMergeTree)
-- These use ReplacingMergeTree(version) so background merges
-- keep only the latest version per entity.
-- Views with argMax provide deterministic latest state
-- without requiring FINAL keyword.
-- ============================================================

-- ---------- merchants_current ----------
CREATE TABLE IF NOT EXISTS payflow_core.merchants_current (
    merchant_id  String,
    external_id  String,
    name         String,
    category     LowCardinality(String),
    city         String,
    fee_rate     Float64,
    is_active    UInt8,
    is_deleted   UInt8,
    source_timestamp DateTime64(3),
    ingested_at  DateTime64(3)
) ENGINE = ReplacingMergeTree(source_timestamp)
ORDER BY merchant_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_merchants_current
TO payflow_core.merchants_current AS
SELECT
    merchant_id,
    external_id,
    name,
    category,
    city,
    fee_rate,
    is_active,
    is_deleted,
    source_timestamp,
    ingested_at
FROM payflow_raw.merchant_cdc_events;

-- ---------- payment_methods_current ----------
CREATE TABLE IF NOT EXISTS payflow_core.payment_methods_current (
    payment_method_id String,
    code              String,
    name              String,
    provider          String,
    type              LowCardinality(String),
    is_active         UInt8,
    is_deleted        UInt8,
    source_timestamp  DateTime64(3),
    ingested_at       DateTime64(3)
) ENGINE = ReplacingMergeTree(source_timestamp)
ORDER BY payment_method_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_payment_methods_current
TO payflow_core.payment_methods_current AS
SELECT
    payment_method_id,
    code,
    name,
    provider,
    type,
    is_active,
    is_deleted,
    source_timestamp,
    ingested_at
FROM payflow_raw.payment_method_cdc_events;

-- ---------- payments_current ----------
CREATE TABLE IF NOT EXISTS payflow_core.payments_current (
    payment_id         String,
    merchant_id        String,
    payment_method_id  String,
    external_reference String,
    amount             Float64,
    fee_amount         Float64,
    net_amount         Float64,
    currency           LowCardinality(String),
    status             LowCardinality(String),
    failure_reason     Nullable(String),
    version            Int32,
    initiated_at       Nullable(DateTime64(3)),
    authorized_at      Nullable(DateTime64(3)),
    captured_at        Nullable(DateTime64(3)),
    settled_at         Nullable(DateTime64(3)),
    is_deleted         UInt8,
    source_timestamp   DateTime64(3),
    ingested_at        DateTime64(3)
) ENGINE = ReplacingMergeTree(version)
PARTITION BY toYYYYMM(coalesce(initiated_at, source_timestamp))
ORDER BY payment_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_payments_current
TO payflow_core.payments_current AS
SELECT
    payment_id,
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
    initiated_at,
    authorized_at,
    captured_at,
    settled_at,
    is_deleted,
    source_timestamp,
    ingested_at
FROM payflow_raw.payment_cdc_events;

-- ---------- refunds_current ----------
CREATE TABLE IF NOT EXISTS payflow_core.refunds_current (
    refund_id        String,
    payment_id       String,
    refund_reference String,
    amount           Float64,
    status           LowCardinality(String),
    reason           Nullable(String),
    is_deleted       UInt8,
    source_timestamp DateTime64(3),
    ingested_at      DateTime64(3)
) ENGINE = ReplacingMergeTree(source_timestamp)
ORDER BY refund_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_refunds_current
TO payflow_core.refunds_current AS
SELECT
    refund_id,
    payment_id,
    refund_reference,
    amount,
    status,
    reason,
    is_deleted,
    source_timestamp,
    ingested_at
FROM payflow_raw.refund_cdc_events;

-- ---------- settlement_batches_current ----------
CREATE TABLE IF NOT EXISTS payflow_core.settlement_batches_current (
    batch_id             String,
    merchant_id          String,
    settlement_reference String,
    settlement_date      Date,
    gross_amount         Float64,
    fee_amount           Float64,
    refund_amount        Float64,
    expected_net_amount  Float64,
    actual_net_amount    Float64,
    status               LowCardinality(String),
    is_deleted           UInt8,
    source_timestamp     DateTime64(3),
    ingested_at          DateTime64(3)
) ENGINE = ReplacingMergeTree(source_timestamp)
ORDER BY batch_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_settlement_batches_current
TO payflow_core.settlement_batches_current AS
SELECT
    batch_id,
    merchant_id,
    settlement_reference,
    settlement_date,
    gross_amount,
    fee_amount,
    refund_amount,
    expected_net_amount,
    actual_net_amount,
    status,
    is_deleted,
    source_timestamp,
    ingested_at
FROM payflow_raw.settlement_batch_cdc_events;

-- ---------- settlement_items_current ----------
CREATE TABLE IF NOT EXISTS payflow_core.settlement_items_current (
    item_id               String,
    settlement_batch_id   String,
    payment_id            String,
    expected_amount       Float64,
    actual_amount         Float64,
    reconciliation_status LowCardinality(String),
    is_deleted            UInt8,
    source_timestamp      DateTime64(3),
    ingested_at           DateTime64(3)
) ENGINE = ReplacingMergeTree(source_timestamp)
ORDER BY item_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_settlement_items_current
TO payflow_core.settlement_items_current AS
SELECT
    item_id,
    settlement_batch_id,
    payment_id,
    expected_amount,
    actual_amount,
    reconciliation_status,
    is_deleted,
    source_timestamp,
    ingested_at
FROM payflow_raw.settlement_item_cdc_events;

-- ============================================================
-- Convenience views using argMax (avoid FINAL overhead)
-- Wrapped in subqueries to avoid HAVING alias conflicts.
-- ============================================================

CREATE VIEW IF NOT EXISTS payflow_core.v_payments_latest AS
SELECT * FROM (
    SELECT
        payment_id,
        argMax(merchant_id, version)        AS merchant_id,
        argMax(payment_method_id, version)  AS payment_method_id,
        argMax(external_reference, version) AS external_reference,
        argMax(amount, version)             AS amount,
        argMax(fee_amount, version)         AS fee_amount,
        argMax(net_amount, version)         AS net_amount,
        argMax(currency, version)           AS currency,
        argMax(status, version)             AS status,
        argMax(failure_reason, version)     AS failure_reason,
        max(version)                        AS latest_version,
        argMax(initiated_at, version)       AS initiated_at,
        argMax(authorized_at, version)      AS authorized_at,
        argMax(captured_at, version)        AS captured_at,
        argMax(settled_at, version)         AS settled_at,
        argMax(is_deleted, version)         AS _is_deleted
    FROM payflow_core.payments_current
    GROUP BY payment_id
) WHERE _is_deleted = 0;

CREATE VIEW IF NOT EXISTS payflow_core.v_merchants_latest AS
SELECT * FROM (
    SELECT
        merchant_id,
        argMax(external_id, source_timestamp)  AS external_id,
        argMax(name, source_timestamp)         AS name,
        argMax(category, source_timestamp)     AS category,
        argMax(city, source_timestamp)         AS city,
        argMax(fee_rate, source_timestamp)     AS fee_rate,
        argMax(is_active, source_timestamp)    AS is_active,
        argMax(is_deleted, source_timestamp)   AS _is_deleted
    FROM payflow_core.merchants_current
    GROUP BY merchant_id
) WHERE _is_deleted = 0;

