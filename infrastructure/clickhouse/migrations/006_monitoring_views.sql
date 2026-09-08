-- ============================================================
-- 006: Event history + real-time aggregate tables & views
-- Used by Grafana for operational monitoring.
-- ============================================================

-- ─── Layer 4: Event history (fact tables) ──────────────────

CREATE TABLE IF NOT EXISTS payflow_core.fact_payment_status_events (
    event_id            String,
    payment_id          String,
    merchant_id         String,
    from_status         Nullable(String),
    to_status           LowCardinality(String),
    reason              Nullable(String),
    payment_version     Int32,
    occurred_at         DateTime64(3),
    ingested_at         DateTime64(3),
    pipeline_latency_ms Int64
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(occurred_at)
ORDER BY (payment_id, payment_version, occurred_at);

-- Populate fact_payment_status_events by joining status_history
-- with the latest payment CDC event to get merchant_id.
CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_fact_payment_status_events
TO payflow_core.fact_payment_status_events AS
SELECT
    sh.event_id,
    sh.payment_id,
    p.merchant_id,
    sh.from_status,
    sh.to_status,
    sh.reason,
    sh.payment_version,
    sh.occurred_at,
    sh.ingested_at,
    toInt64(dateDiff('millisecond', sh.occurred_at, sh.ingested_at)) AS pipeline_latency_ms
FROM payflow_raw.status_history_events AS sh
LEFT JOIN payflow_core.payments_current AS p
    ON sh.payment_id = p.payment_id;

CREATE TABLE IF NOT EXISTS payflow_core.fact_refund_events (
    refund_id        String,
    payment_id       String,
    refund_reference String,
    amount           Float64,
    status           LowCardinality(String),
    reason           Nullable(String),
    source_timestamp DateTime64(3),
    ingested_at      DateTime64(3)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (payment_id, source_timestamp);

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_fact_refund_events
TO payflow_core.fact_refund_events AS
SELECT
    refund_id,
    payment_id,
    refund_reference,
    amount,
    status,
    reason,
    source_timestamp,
    ingested_at
FROM payflow_raw.refund_cdc_events;

CREATE TABLE IF NOT EXISTS payflow_core.fact_settlement_events (
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
    source_timestamp     DateTime64(3),
    ingested_at          DateTime64(3)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(settlement_date)
ORDER BY (merchant_id, settlement_date);

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_fact_settlement_events
TO payflow_core.fact_settlement_events AS
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
    source_timestamp,
    ingested_at
FROM payflow_raw.settlement_batch_cdc_events;

-- ─── Layer 5: Real-time aggregates ─────────────────────────

-- Payment metrics per minute
CREATE TABLE IF NOT EXISTS payflow_core.payment_metrics_per_minute (
    minute             DateTime,
    transaction_count  AggregateFunction(count, UInt64),
    successful_count   AggregateFunction(sum, UInt64),
    failed_count       AggregateFunction(sum, UInt64),
    gross_amount       AggregateFunction(sum, Float64),
    average_amount     AggregateFunction(avg, Float64),
    p95_amount         AggregateFunction(quantile(0.95), Float64)
) ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(minute)
ORDER BY minute;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_payment_metrics_per_minute
TO payflow_core.payment_metrics_per_minute AS
SELECT
    toStartOfMinute(source_timestamp)                          AS minute,
    countState()                                               AS transaction_count,
    sumState(toUInt64(status IN ('CAPTURED','SETTLED')))        AS successful_count,
    sumState(toUInt64(status IN ('FAILED','EXPIRED')))          AS failed_count,
    sumState(amount)                                           AS gross_amount,
    avgState(amount)                                           AS average_amount,
    quantileState(0.95)(amount)                                AS p95_amount
FROM payflow_raw.payment_cdc_events
WHERE source_operation IN ('c', 'r')
GROUP BY minute;

-- Failure metrics per minute
CREATE TABLE IF NOT EXISTS payflow_core.failure_metrics_per_minute (
    minute           DateTime,
    failure_reason   LowCardinality(String),
    failure_count    AggregateFunction(count, UInt64),
    failure_amount   AggregateFunction(sum, Float64)
) ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(minute)
ORDER BY (minute, failure_reason);

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_failure_metrics_per_minute
TO payflow_core.failure_metrics_per_minute AS
SELECT
    toStartOfMinute(source_timestamp) AS minute,
    coalesce(failure_reason, 'UNKNOWN') AS failure_reason,
    countState()                        AS failure_count,
    sumState(amount)                    AS failure_amount
FROM payflow_raw.payment_cdc_events
WHERE status = 'FAILED'
  AND source_operation IN ('c', 'u', 'r')
GROUP BY minute, failure_reason;

-- Ingestion (pipeline) metrics per minute
CREATE TABLE IF NOT EXISTS payflow_core.ingestion_metrics_per_minute (
    minute                    DateTime,
    event_count               AggregateFunction(count, UInt64),
    average_pipeline_latency  AggregateFunction(avg, Float64),
    p95_pipeline_latency      AggregateFunction(quantile(0.95), Float64)
) ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(minute)
ORDER BY minute;

CREATE MATERIALIZED VIEW IF NOT EXISTS payflow_core.mv_ingestion_metrics_per_minute
TO payflow_core.ingestion_metrics_per_minute AS
SELECT
    toStartOfMinute(ingested_at)     AS minute,
    countState()                     AS event_count,
    avgState(
        toFloat64(dateDiff('millisecond', source_timestamp, ingested_at))
    )                                AS average_pipeline_latency,
    quantileState(0.95)(
        toFloat64(dateDiff('millisecond', source_timestamp, ingested_at))
    )                                AS p95_pipeline_latency
FROM payflow_raw.payment_cdc_events
GROUP BY minute;

-- ─── Convenience views for Grafana queries ─────────────────

CREATE VIEW IF NOT EXISTS payflow_core.v_payment_metrics_per_minute AS
SELECT
    minute,
    countMerge(transaction_count)  AS transaction_count,
    sumMerge(successful_count)     AS successful_count,
    sumMerge(failed_count)         AS failed_count,
    sumMerge(gross_amount)         AS gross_amount,
    avgMerge(average_amount)       AS average_amount,
    quantileMerge(0.95)(p95_amount) AS p95_amount
FROM payflow_core.payment_metrics_per_minute
GROUP BY minute
ORDER BY minute;

CREATE VIEW IF NOT EXISTS payflow_core.v_failure_metrics_per_minute AS
SELECT
    minute,
    failure_reason,
    countMerge(failure_count)  AS failure_count,
    sumMerge(failure_amount)   AS failure_amount
FROM payflow_core.failure_metrics_per_minute
GROUP BY minute, failure_reason
ORDER BY minute;

CREATE VIEW IF NOT EXISTS payflow_core.v_ingestion_metrics_per_minute AS
SELECT
    minute,
    countMerge(event_count)                    AS event_count,
    avgMerge(average_pipeline_latency)         AS average_pipeline_latency_ms,
    quantileMerge(0.95)(p95_pipeline_latency)  AS p95_pipeline_latency_ms
FROM payflow_core.ingestion_metrics_per_minute
GROUP BY minute
ORDER BY minute;
