-- ============================================================
-- 003: Raw CDC tables (append-only MergeTree)
-- These store every CDC event for audit and debugging.
-- Duplicates are preserved intentionally in the raw layer.
-- ============================================================

-- ---------- merchants ----------
CREATE TABLE IF NOT EXISTS payflow_raw.merchant_cdc_events (
    merchant_id      String,
    external_id      String,
    name             String,
    category         String,
    city             String,
    fee_rate         Float64,
    is_active        UInt8,
    source_operation LowCardinality(String),
    source_timestamp DateTime64(3),
    ingested_at      DateTime64(3) DEFAULT now64(3),
    is_deleted       UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (merchant_id, source_timestamp);

-- ---------- payment_methods ----------
CREATE TABLE IF NOT EXISTS payflow_raw.payment_method_cdc_events (
    payment_method_id String,
    code              String,
    name              String,
    provider          String,
    type              LowCardinality(String),
    is_active         UInt8,
    source_operation  LowCardinality(String),
    source_timestamp  DateTime64(3),
    ingested_at       DateTime64(3) DEFAULT now64(3),
    is_deleted        UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (payment_method_id, source_timestamp);

-- ---------- payments ----------
CREATE TABLE IF NOT EXISTS payflow_raw.payment_cdc_events (
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
    source_operation   LowCardinality(String),
    source_timestamp   DateTime64(3),
    ingested_at        DateTime64(3) DEFAULT now64(3),
    is_deleted         UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (payment_id, version, source_timestamp);

-- ---------- status_history ----------
CREATE TABLE IF NOT EXISTS payflow_raw.status_history_events (
    event_id         String,
    payment_id       String,
    from_status      Nullable(String),
    to_status        LowCardinality(String),
    reason           Nullable(String),
    payment_version  Int32,
    occurred_at      DateTime64(3),
    source_operation LowCardinality(String),
    source_timestamp DateTime64(3),
    ingested_at      DateTime64(3) DEFAULT now64(3),
    is_deleted       UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (payment_id, payment_version, source_timestamp);

-- ---------- refunds ----------
CREATE TABLE IF NOT EXISTS payflow_raw.refund_cdc_events (
    refund_id        String,
    payment_id       String,
    refund_reference String,
    amount           Float64,
    status           LowCardinality(String),
    reason           Nullable(String),
    source_operation LowCardinality(String),
    source_timestamp DateTime64(3),
    ingested_at      DateTime64(3) DEFAULT now64(3),
    is_deleted       UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (refund_id, source_timestamp);

-- ---------- settlement_batches ----------
CREATE TABLE IF NOT EXISTS payflow_raw.settlement_batch_cdc_events (
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
    source_operation     LowCardinality(String),
    source_timestamp     DateTime64(3),
    ingested_at          DateTime64(3) DEFAULT now64(3),
    is_deleted           UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (batch_id, source_timestamp);

-- ---------- settlement_items ----------
CREATE TABLE IF NOT EXISTS payflow_raw.settlement_item_cdc_events (
    item_id               String,
    settlement_batch_id   String,
    payment_id            String,
    expected_amount       Float64,
    actual_amount         Float64,
    reconciliation_status LowCardinality(String),
    source_operation      LowCardinality(String),
    source_timestamp      DateTime64(3),
    ingested_at           DateTime64(3) DEFAULT now64(3),
    is_deleted            UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (item_id, source_timestamp);
