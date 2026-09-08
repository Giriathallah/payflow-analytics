-- ============================================================
-- 002: Kafka engine tables
-- These tables only consume from Kafka topics.
-- They are NOT queried directly; materialized views
-- move data into the raw layer.
-- ============================================================

-- ---------- merchants ----------
CREATE TABLE IF NOT EXISTS payflow_raw.kafka_merchants (
    id             String,
    external_id    String,
    name           String,
    category       String,
    city           String,
    fee_rate       Float64,
    is_active      UInt8,
    created_at     String,
    updated_at     String,
    __deleted      String,
    __op           String,
    __table        String,
    __source_ts_ms Int64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list          = 'kafka:9092',
    kafka_topic_list           = 'payflow.public.merchants',
    kafka_group_name           = 'clickhouse_merchants',
    kafka_format               = 'JSONEachRow',
    kafka_num_consumers        = 1,
    kafka_skip_broken_messages = 100,
    kafka_handle_error_mode    = 'stream';

-- ---------- payment_methods ----------
CREATE TABLE IF NOT EXISTS payflow_raw.kafka_payment_methods (
    id         String,
    code       String,
    name       String,
    provider   String,
    type       String,
    is_active  UInt8,
    created_at String,
    updated_at String,
    __deleted      String,
    __op           String,
    __table        String,
    __source_ts_ms Int64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list          = 'kafka:9092',
    kafka_topic_list           = 'payflow.public.payment_methods',
    kafka_group_name           = 'clickhouse_payment_methods',
    kafka_format               = 'JSONEachRow',
    kafka_num_consumers        = 1,
    kafka_skip_broken_messages = 100,
    kafka_handle_error_mode    = 'stream';

-- ---------- payments ----------
CREATE TABLE IF NOT EXISTS payflow_raw.kafka_payments (
    id                 String,
    merchant_id        String,
    payment_method_id  String,
    external_reference String,
    amount             Float64,
    fee_amount         Float64,
    net_amount         Float64,
    currency           String,
    status             String,
    failure_reason     Nullable(String),
    version            Int32,
    initiated_at       String,
    authorized_at      Nullable(String),
    captured_at        Nullable(String),
    settled_at         Nullable(String),
    created_at         String,
    updated_at         String,
    __deleted          String,
    __op               String,
    __table            String,
    __source_ts_ms     Int64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list          = 'kafka:9092',
    kafka_topic_list           = 'payflow.public.payments',
    kafka_group_name           = 'clickhouse_payments',
    kafka_format               = 'JSONEachRow',
    kafka_num_consumers        = 1,
    kafka_skip_broken_messages = 100,
    kafka_handle_error_mode    = 'stream';

-- ---------- payment_status_history ----------
CREATE TABLE IF NOT EXISTS payflow_raw.kafka_status_history (
    id              String,
    payment_id      String,
    from_status     Nullable(String),
    to_status       String,
    reason          Nullable(String),
    payment_version Int32,
    occurred_at     String,
    created_at      String,
    __deleted       String,
    __op            String,
    __table         String,
    __source_ts_ms  Int64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list          = 'kafka:9092',
    kafka_topic_list           = 'payflow.public.payment_status_history',
    kafka_group_name           = 'clickhouse_status_history',
    kafka_format               = 'JSONEachRow',
    kafka_num_consumers        = 1,
    kafka_skip_broken_messages = 100,
    kafka_handle_error_mode    = 'stream';

-- ---------- refunds ----------
CREATE TABLE IF NOT EXISTS payflow_raw.kafka_refunds (
    id               String,
    payment_id       String,
    refund_reference String,
    amount           Float64,
    status           String,
    reason           Nullable(String),
    created_at       String,
    updated_at       String,
    __deleted        String,
    __op             String,
    __table          String,
    __source_ts_ms   Int64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list          = 'kafka:9092',
    kafka_topic_list           = 'payflow.public.refunds',
    kafka_group_name           = 'clickhouse_refunds',
    kafka_format               = 'JSONEachRow',
    kafka_num_consumers        = 1,
    kafka_skip_broken_messages = 100,
    kafka_handle_error_mode    = 'stream';

-- ---------- settlement_batches ----------
CREATE TABLE IF NOT EXISTS payflow_raw.kafka_settlement_batches (
    id                   String,
    merchant_id          String,
    settlement_reference String,
    settlement_date      String,
    gross_amount         Float64,
    fee_amount           Float64,
    refund_amount        Float64,
    expected_net_amount  Float64,
    actual_net_amount    Float64,
    status               String,
    created_at           String,
    updated_at           String,
    __deleted            String,
    __op                 String,
    __table              String,
    __source_ts_ms       Int64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list          = 'kafka:9092',
    kafka_topic_list           = 'payflow.public.settlement_batches',
    kafka_group_name           = 'clickhouse_settlement_batches',
    kafka_format               = 'JSONEachRow',
    kafka_num_consumers        = 1,
    kafka_skip_broken_messages = 100,
    kafka_handle_error_mode    = 'stream';

-- ---------- settlement_items ----------
CREATE TABLE IF NOT EXISTS payflow_raw.kafka_settlement_items (
    id                     String,
    settlement_batch_id    String,
    payment_id             String,
    expected_amount        Float64,
    actual_amount          Float64,
    reconciliation_status  String,
    created_at             String,
    updated_at             String,
    __deleted              String,
    __op                   String,
    __table                String,
    __source_ts_ms         Int64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list          = 'kafka:9092',
    kafka_topic_list           = 'payflow.public.settlement_items',
    kafka_group_name           = 'clickhouse_settlement_items',
    kafka_format               = 'JSONEachRow',
    kafka_num_consumers        = 1,
    kafka_skip_broken_messages = 100,
    kafka_handle_error_mode    = 'stream';
