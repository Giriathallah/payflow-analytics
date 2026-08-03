Ya, stack tersebut sudah cukup kuat. Rekomendasi saya:

* **Airflow tidak perlu** untuk versi ini.
* **dbt tetap digunakan**, tetapi bukan untuk streaming.
* Java tetap sebagai **source-system simulator**, bukan producer Kafka.
* Tambahkan **Prometheus** sebagai komponen pendukung Grafana. Grafana sendiri hanya memvisualisasikan data; ia tidak mengumpulkan seluruh metrik infrastruktur.

Debezium membaca perubahan PostgreSQL melalui logical decoding dan replication slot, lalu menerbitkan change event ke topic Kafka. Ketika pertama terhubung, Debezium juga dapat membuat snapshot awal sebelum melanjutkan streaming dari posisi WAL yang sesuai. Replication slot harus dimonitor karena dapat menahan WAL selama connector berhenti. ([Debezium][1])

# 1. Arsitektur final

```text
┌───────────────────────────────────────┐
│ Java Payment Data Generator           │
│ Spring Boot + Scheduled Jobs          │
│                                       │
│ - Generate payments                   │
│ - Change payment statuses             │
│ - Generate refunds                    │
│ - Generate settlements                │
│ - Simulate failures and mismatches    │
└──────────────────┬────────────────────┘
                   │ INSERT / UPDATE
                   ▼
┌───────────────────────────────────────┐
│ PostgreSQL OLTP                       │
│                                       │
│ merchants                             │
│ payments                              │
│ payment_status_history                │
│ refunds                               │
│ settlement_batches                    │
│ settlement_items                      │
└──────────────────┬────────────────────┘
                   │ PostgreSQL WAL
                   ▼
┌───────────────────────────────────────┐
│ Debezium PostgreSQL Connector         │
│ running on Kafka Connect              │
└──────────────────┬────────────────────┘
                   │ Change events
                   ▼
┌───────────────────────────────────────┐
│ Apache Kafka                          │
│                                       │
│ payflow.public.payments               │
│ payflow.public.payment_status_history │
│ payflow.public.refunds                │
│ payflow.public.settlement_batches     │
│ payflow.public.settlement_items       │
└──────────────────┬────────────────────┘
                   │ Consume
                   ▼
┌───────────────────────────────────────┐
│ ClickHouse                            │
│                                       │
│ kafka_* tables                        │
│        ↓                              │
│ materialized views                    │
│        ↓                              │
│ raw → core → mart                     │
└────────────┬──────────────────────────┘
             │
             ├───────────────────────────────┐
             ▼                               ▼
┌───────────────────────────┐  ┌────────────────────────────┐
│ dbt Core                  │  │ Real-time serving tables   │
│                           │  │                            │
│ staging                   │  │ minute metrics             │
│ intermediate              │  │ payment events             │
│ marts                     │  │ ingestion latency          │
│ tests                     │  │ current payment state      │
└────────────┬──────────────┘  └─────────────┬──────────────┘
             │                               │
             ▼                               ▼
┌───────────────────────────┐  ┌────────────────────────────┐
│ Apache Superset           │  │ Grafana                    │
│ Business analytics        │  │ Operational monitoring     │
└───────────────────────────┘  └─────────────┬──────────────┘
                                            │
                                      Prometheus metrics
```

# 2. Apakah dbt tetap diperlukan?

## Jawabannya: tidak wajib, tetapi sangat direkomendasikan

Tanpa dbt, pipeline ini tetap dapat berjalan:

```text
PostgreSQL
→ Debezium
→ Kafka
→ ClickHouse
→ Superset
```

Namun transformasi bisnis akan tersebar di:

* file SQL ClickHouse;
* materialized view;
* query Superset;
* query Grafana.

Akibatnya, business logic menjadi kurang terstruktur dan sulit diuji.

Dengan dbt:

```text
ClickHouse raw tables
        ↓
dbt staging
        ↓
dbt intermediate
        ↓
dbt marts
        ↓
Superset
```

dbt digunakan untuk:

* membersihkan struktur data CDC;
* membuat model current state;
* menggabungkan payment, merchant, refund, dan settlement;
* membuat fact dan dimension;
* membuat data mart;
* menjalankan data-quality test;
* membuat dokumentasi dan lineage model.

Adapter resmi `dbt-clickhouse` tersedia untuk menjalankan dbt Core terhadap ClickHouse. Dokumentasi repository resminya menyebutkan dukungan fitur dbt Core sampai 1.10, meskipun adapter tersebut belum tersedia langsung dalam dbt Cloud. Untuk proyek lokal Anda, hal ini bukan masalah karena yang digunakan adalah dbt Core melalui CLI. ([GitHub][2])

## dbt tidak membutuhkan Airflow

Anda dapat menjalankannya manual:

```bash
dbt build
```

Atau melalui Makefile:

```bash
make dbt-build
```

Setelah project stabil, jalankan dengan cron setiap lima menit:

```cron
*/5 * * * * cd /app/dbt && dbt build
```

Pembagiannya:

```text
ClickHouse Materialized View
→ transformasi ingestion yang harus langsung berjalan.

dbt
→ transformasi bisnis yang boleh diperbarui setiap beberapa menit.
```

Untuk dashboard yang benar-benar real-time, Superset atau Grafana dapat membaca tabel ClickHouse hasil materialized view secara langsung. Untuk dashboard eksekutif dan settlement, baca tabel mart yang dibuat dbt.

# 3. Ruang lingkup project

Project mensimulasikan payment gateway yang menerima pembayaran dari merchant dan melakukan settlement.

## Alur pembayaran

```text
INITIATED
    ↓
AUTHORIZED
    ↓
CAPTURED
    ↓
SETTLED
```

Jalur lain:

```text
INITIATED → FAILED
AUTHORIZED → EXPIRED
CAPTURED → REFUNDED
CAPTURED → CHARGEBACK
```

## Masalah bisnis yang dijawab

Platform harus dapat menjawab:

* berapa transaksi masuk per detik atau menit;
* berapa payment success rate;
* metode pembayaran apa yang paling sering gagal;
* merchant mana yang memiliki volume transaksi terbesar;
* berapa total fee yang diperoleh;
* berapa refund dan chargeback;
* transaksi mana yang belum masuk settlement;
* apakah nilai settlement sesuai;
* berapa end-to-end pipeline latency;
* apakah ada keterlambatan CDC;
* apakah ada duplicate atau missing transaction.

# 4. Java Payment Data Generator

Java digunakan sebagai simulator sistem transaksi.

Gunakan:

```text
Java
Spring Boot
Spring Data JPA
PostgreSQL Driver
Flyway
Spring Actuator
Micrometer
```

Java tidak perlu mengirim message langsung ke Kafka. Semua data harus ditulis ke PostgreSQL agar Debezium benar-benar menjadi satu-satunya jalur CDC.

## Struktur aplikasi Java

```text
apps/payment-generator/
├── src/main/java/com/payflow/generator/
│   ├── config/
│   │   ├── GeneratorProperties.java
│   │   └── SchedulingConfig.java
│   │
│   ├── domain/
│   │   ├── Merchant.java
│   │   ├── Payment.java
│   │   ├── PaymentStatusHistory.java
│   │   ├── Refund.java
│   │   ├── SettlementBatch.java
│   │   └── SettlementItem.java
│   │
│   ├── repository/
│   ├── service/
│   │   ├── PaymentGenerationService.java
│   │   ├── PaymentLifecycleService.java
│   │   ├── RefundGenerationService.java
│   │   ├── SettlementGenerationService.java
│   │   └── SimulationScenarioService.java
│   │
│   ├── scheduler/
│   │   ├── PaymentGeneratorScheduler.java
│   │   ├── PaymentTransitionScheduler.java
│   │   ├── RefundScheduler.java
│   │   └── SettlementScheduler.java
│   │
│   ├── controller/
│   │   ├── GeneratorController.java
│   │   └── ScenarioController.java
│   │
│   └── PaymentGeneratorApplication.java
│
├── src/main/resources/
│   ├── db/migration/
│   └── application.yml
└── pom.xml
```

## Scheduled jobs

### Payment generation job

Berjalan setiap satu detik:

```text
1. Pilih merchant.
2. Pilih payment method.
3. Buat nominal transaksi.
4. Buat payment berstatus INITIATED.
5. Tambahkan status history INITIATED.
6. Commit transaction.
```

Satu database transaction harus menyimpan:

```text
payments
payment_status_history
```

### Payment transition job

Berjalan setiap dua detik:

```text
INITIATED
├── 85% → AUTHORIZED
└── 15% → FAILED

AUTHORIZED
├── 95% → CAPTURED
├── 3%  → FAILED
└── 2%  → EXPIRED

CAPTURED
└── menunggu settlement
```

Persentase harus configurable, bukan hard-coded.

### Refund job

Berjalan setiap beberapa detik:

```text
Ambil payment CAPTURED atau SETTLED
        ↓
Tentukan sebagian kecil untuk refund
        ↓
Buat record refunds
        ↓
Tambahkan status history
```

Dukung:

* full refund;
* partial refund;
* failed refund.

### Settlement job

Dalam dunia nyata settlement bisa harian. Untuk demo lokal, percepat prosesnya.

Contohnya:

```text
Setiap 60 detik
= satu siklus settlement simulasi
```

Prosesnya:

```text
1. Kelompokkan payment CAPTURED per merchant.
2. Hitung gross amount.
3. Hitung merchant fee.
4. Hitung refund.
5. Hitung expected net settlement.
6. Buat settlement batch.
7. Buat settlement items.
8. Ubah payment menjadi SETTLED.
```

## Configuration

```yaml
simulation:
  enabled: true
  random-seed: 2026

  payment:
    transactions-per-second: 5
    min-amount: 10000
    max-amount: 5000000

  probabilities:
    authorization-success: 0.85
    capture-success: 0.95
    refund: 0.02
    chargeback: 0.005
    settlement-mismatch: 0.01
    duplicate-settlement: 0.002

  schedules:
    payment-generation-ms: 1000
    lifecycle-transition-ms: 2000
    refund-generation-ms: 10000
    settlement-generation-ms: 60000
```

## Control API

```http
POST /api/generator/start
POST /api/generator/stop

GET  /api/generator/status
GET  /api/generator/config

PUT  /api/generator/config

POST /api/scenarios/failure-spike
POST /api/scenarios/settlement-mismatch
POST /api/scenarios/high-traffic
POST /api/scenarios/duplicate-settlement
```

Contoh skenario:

```json
{
  "durationSeconds": 60,
  "failureRate": 0.4
}
```

Ini membuat project mudah didemonstrasikan tanpa mengubah source code.

# 5. PostgreSQL OLTP design

## Tabel merchants

```text
merchants
---------
id
external_id
name
category
city
fee_rate
is_active
created_at
updated_at
```

Kategori:

```text
SMALL
MEDIUM
ENTERPRISE
```

## Tabel payment_methods

```text
payment_methods
---------------
id
code
name
provider
type
is_active
created_at
updated_at
```

Contoh:

```text
BCA_VA
MANDIRI_VA
GOPAY
OVO
QRIS
CREDIT_CARD
```

## Tabel payments

```text
payments
--------
id
merchant_id
payment_method_id
external_reference
amount
fee_amount
net_amount
currency
status
failure_reason
version
initiated_at
authorized_at
captured_at
settled_at
created_at
updated_at
```

Gunakan `NUMERIC`, bukan floating point, untuk nilai uang.

Kolom `version` dinaikkan setiap status berubah:

```text
INITIATED  → version 1
AUTHORIZED → version 2
CAPTURED   → version 3
SETTLED    → version 4
```

Version ini nantinya membantu ClickHouse menangani event yang datang terlambat atau berulang.

## Tabel payment_status_history

```text
payment_status_history
----------------------
id
payment_id
from_status
to_status
reason
payment_version
occurred_at
created_at
```

Tabel ini bersifat append-only.

Meskipun Debezium dapat menangkap update pada tabel `payments`, tabel status history tetap penting karena:

* lebih mudah dianalisis;
* funnel lebih jelas;
* tidak bergantung pada parsing before/after event;
* durasi antar-status mudah dihitung;
* audit history tersimpan secara eksplisit.

## Tabel refunds

```text
refunds
-------
id
payment_id
refund_reference
amount
status
reason
created_at
updated_at
```

Status:

```text
REQUESTED
PROCESSING
COMPLETED
FAILED
```

## Tabel settlement_batches

```text
settlement_batches
------------------
id
merchant_id
settlement_reference
settlement_date
gross_amount
fee_amount
refund_amount
expected_net_amount
actual_net_amount
status
created_at
updated_at
```

## Tabel settlement_items

```text
settlement_items
----------------
id
settlement_batch_id
payment_id
expected_amount
actual_amount
reconciliation_status
created_at
updated_at
```

Status:

```text
MATCHED
AMOUNT_MISMATCH
MISSING
DUPLICATE
```

## Relationship

```text
merchants
   │
   ├──< payments
   │       │
   │       ├──< payment_status_history
   │       ├──< refunds
   │       └──< settlement_items
   │
   └──< settlement_batches
             └──< settlement_items
```

# 6. PostgreSQL untuk Debezium

PostgreSQL harus menggunakan logical replication:

```text
wal_level=logical
max_wal_senders=10
max_replication_slots=10
```

Buat user terpisah:

```text
payflow_app
payflow_debezium
```

Publication hanya mencakup tabel yang dibutuhkan:

```sql
CREATE PUBLICATION payflow_publication
FOR TABLE
    merchants,
    payment_methods,
    payments,
    payment_status_history,
    refunds,
    settlement_batches,
    settlement_items;
```

Jangan otomatis menggunakan `REPLICA IDENTITY FULL` pada semua tabel.

Gunakan primary key sebagai identity default. `FULL` hanya diperlukan bila Anda benar-benar membutuhkan seluruh nilai lama atau tabel tidak memiliki identity yang memadai. Penggunaan full row image menambah volume WAL dan ukuran event.

Replication slot mempertahankan WAL yang masih dibutuhkan connector. Karena itu slot yang tidak aktif terlalu lama dapat menambah pemakaian disk dan harus dimonitor. ([Debezium][1])

# 7. Debezium dan Kafka Connect

Gunakan satu PostgreSQL connector:

```text
connector name:
payflow-postgres-source

replication slot:
payflow_debezium_slot

publication:
payflow_publication

plugin:
pgoutput
```

`pgoutput` adalah output plugin bawaan PostgreSQL modern sehingga tidak memerlukan plugin eksternal tambahan. ([Debezium][1])

## Table include list

```text
public.merchants
public.payment_methods
public.payments
public.payment_status_history
public.refunds
public.settlement_batches
public.settlement_items
```

## Event format

Untuk MVP, gunakan JSON.

Gunakan unwrap transformation agar payload lebih mudah dikonsumsi ClickHouse:

```text
Debezium envelope
        ↓ unwrap
flat JSON record
```

Tetap tambahkan metadata:

```text
__op
__table
__source_ts_ms
__deleted
```

Contoh payment event:

```json
{
  "id": "cfa3...",
  "merchant_id": "7a9f...",
  "amount": 250000,
  "status": "CAPTURED",
  "version": 3,
  "updated_at": "2026-07-27T10:30:12.123Z",
  "__op": "u",
  "__table": "payments",
  "__source_ts_ms": 1785123012123,
  "__deleted": "false"
}
```

## Topic Kafka

```text
payflow.public.merchants
payflow.public.payment_methods
payflow.public.payments
payflow.public.payment_status_history
payflow.public.refunds
payflow.public.settlement_batches
payflow.public.settlement_items
```

## Konfigurasi lokal

Untuk portfolio lokal:

```text
Broker             : 1
Replication factor : 1
Partitions         : 3 per transactional topic
Retention          : 7 days
Serialization      : JSON
Kafka mode         : KRaft
```

Schema Registry belum perlu pada MVP. Tambahkan nanti ketika ingin mendemonstrasikan Avro, Protobuf, atau schema compatibility.

# 8. ClickHouse design

Pisahkan database atau schema secara logis:

```text
payflow_raw
payflow_core
payflow_mart
```

## Layer 1: Kafka engine tables

Contoh:

```text
payflow_raw.kafka_payments
payflow_raw.kafka_status_history
payflow_raw.kafka_refunds
payflow_raw.kafka_settlement_batches
payflow_raw.kafka_settlement_items
```

Tabel ini tidak digunakan langsung oleh dashboard. Tugasnya hanya membaca topic Kafka.

ClickHouse mendukung integrasi Kafka melalui table engine dan materialized view untuk memindahkan event ke tabel penyimpanan. Materialized view inkremental memindahkan beban transformasi ke waktu insert, sehingga cocok untuk parsing dan agregasi real-time. ([ClickHouse][3])

## Layer 2: raw CDC tables

```text
payflow_raw.payment_cdc_events
payflow_raw.status_history_events
payflow_raw.refund_cdc_events
payflow_raw.settlement_batch_cdc_events
payflow_raw.settlement_item_cdc_events
```

Contoh kolom raw payment:

```text
payment_id
merchant_id
payment_method_id
amount
fee_amount
net_amount
status
failure_reason
version
source_operation
source_timestamp
ingested_at
is_deleted
```

Engine:

```text
MergeTree
```

Contoh partition dan order:

```sql
PARTITION BY toYYYYMM(source_timestamp)
ORDER BY (payment_id, version, source_timestamp)
```

Raw layer harus append-only. Jangan hilangkan duplicate dari raw layer karena raw dipakai untuk audit dan debugging.

## Layer 3: core current-state tables

```text
payflow_core.merchants_current
payflow_core.payment_methods_current
payflow_core.payments_current
payflow_core.refunds_current
payflow_core.settlement_batches_current
payflow_core.settlement_items_current
```

Gunakan:

```text
ReplacingMergeTree(version)
```

Contohnya:

```sql
ENGINE = ReplacingMergeTree(version)
PARTITION BY toYYYYMM(created_at)
ORDER BY payment_id
```

Jangan bergantung pada background merge untuk setiap query dashboard.

Buat view menggunakan `argMax`:

```sql
SELECT
    payment_id,
    argMax(status, version) AS status,
    argMax(amount, version) AS amount,
    argMax(merchant_id, version) AS merchant_id,
    max(version) AS version
FROM payflow_raw.payment_cdc_events
WHERE is_deleted = 0
GROUP BY payment_id;
```

Dengan begitu dashboard tidak harus selalu memakai `FINAL`.

## Layer 4: event history

```text
payflow_core.fact_payment_status_events
payflow_core.fact_refund_events
payflow_core.fact_settlement_events
```

`fact_payment_status_events` berasal dari tabel PostgreSQL `payment_status_history`, bukan dari current-state payment.

Kolom:

```text
event_id
payment_id
merchant_id
from_status
to_status
reason
payment_version
occurred_at
ingested_at
pipeline_latency_ms
```

Pipeline latency:

```text
ingested_at - occurred_at
```

## Layer 5: real-time aggregates

Materialized view ClickHouse membuat:

```text
payflow_core.payment_metrics_per_minute
payflow_core.failure_metrics_per_minute
payflow_core.ingestion_metrics_per_minute
```

Contoh metrik:

```text
minute
transaction_count
successful_count
failed_count
gross_amount
average_amount
p95_amount
average_pipeline_latency
p95_pipeline_latency
```

Tabel ini digunakan oleh Grafana karena harus cepat dan hampir real-time.

# 9. dbt design

## Folder

```text
dbt/payflow_analytics/
├── dbt_project.yml
├── profiles.yml.example
├── models/
│   ├── staging/
│   │   ├── sources.yml
│   │   ├── stg_merchants.sql
│   │   ├── stg_payment_methods.sql
│   │   ├── stg_payments.sql
│   │   ├── stg_payment_status_events.sql
│   │   ├── stg_refunds.sql
│   │   └── stg_settlement_items.sql
│   │
│   ├── intermediate/
│   │   ├── int_payment_lifecycle.sql
│   │   ├── int_payment_financials.sql
│   │   ├── int_merchant_daily_payments.sql
│   │   └── int_settlement_matching.sql
│   │
│   └── marts/
│       ├── operations/
│       │   ├── mart_payment_performance.sql
│       │   ├── mart_failure_analysis.sql
│       │   └── mart_payment_funnel.sql
│       │
│       ├── merchants/
│       │   └── mart_merchant_daily_performance.sql
│       │
│       └── finance/
│           └── mart_settlement_reconciliation.sql
│
├── macros/
├── tests/
└── seeds/
```

## Staging models

Tugasnya:

* rename kolom;
* cast tipe;
* filter delete;
* deduplicate current state;
* standarkan status;
* standarkan timestamp.

Contoh:

```text
payflow_core.payments_current
        ↓
stg_payments
```

## Intermediate models

### `int_payment_lifecycle`

Satu baris per payment:

```text
payment_id
initiated_at
authorized_at
captured_at
settled_at
authorization_duration_ms
capture_duration_ms
settlement_duration_ms
final_status
```

### `int_payment_financials`

```text
payment_id
gross_amount
fee_amount
refund_amount
net_amount
```

### `int_settlement_matching`

```text
payment_id
expected_settlement
actual_settlement
difference
reconciliation_status
```

## Mart models

### `mart_payment_performance`

```text
date
hour
payment_method
provider
transaction_count
success_count
failure_count
success_rate
gross_amount
average_amount
```

### `mart_merchant_daily_performance`

```text
date
merchant_id
merchant_name
transaction_count
successful_transaction_count
gross_amount
fee_amount
refund_amount
net_settlement
success_rate
```

### `mart_settlement_reconciliation`

```text
settlement_date
merchant_id
batch_id
expected_amount
actual_amount
difference
matched_count
mismatch_count
missing_count
duplicate_count
reconciliation_status
```

## dbt tests

Tambahkan generic tests:

```text
not_null
unique
accepted_values
relationships
```

Tambahkan singular tests:

```text
payment amount tidak boleh <= 0
refund tidak boleh melebihi payment amount
settled payment harus memiliki captured event
payment version tidak boleh mundur
actual settlement tidak boleh negatif
```

Contoh test:

```sql
SELECT payment_id
FROM {{ ref('stg_payments') }}
WHERE status = 'SETTLED'
  AND captured_at IS NULL
```

## Menjalankan dbt tanpa Airflow

Untuk pengembangan:

```bash
make dbt-debug
make dbt-build
make dbt-test
make dbt-docs
```

Untuk demonstrasi:

```text
Real-time table:
update setiap event melalui materialized view.

dbt mart:
update manual atau setiap lima menit.
```

Jangan menjadwalkan dbt setiap beberapa detik. dbt bukan stream processor.

# 10. Superset implementation

Superset digunakan untuk **business analytics**, bukan health monitoring.

Superset mendukung koneksi ClickHouse menggunakan driver `clickhouse-connect` dan connection URI `clickhousedb://...`. ([Apache Superset][4])

Connection:

```text
clickhousedb://superset_reader:password@clickhouse:8123/payflow_mart
```

Buat user ClickHouse khusus read-only:

```text
superset_reader
```

Jangan gunakan user admin/default.

## Dashboard 1 — Executive Overview

Charts:

* Total Payment Volume
* Transaction Count
* Success Rate
* Total Fee Revenue
* Total Refund
* Net Settlement
* Settlement Mismatch Amount
* Daily Transaction Trend

Filter:

```text
date
merchant
payment method
provider
status
```

## Dashboard 2 — Payment Operations

Charts:

* transaction per minute;
* success versus failure;
* payment funnel;
* failure reasons;
* p50/p95 processing duration;
* payment method performance;
* provider performance.

## Dashboard 3 — Merchant Analytics

Charts:

* top merchants by payment volume;
* merchant success rate;
* merchant fee contribution;
* refund rate;
* chargeback rate;
* net settlement per merchant.

## Dashboard 4 — Settlement Reconciliation

Charts:

* matched versus mismatch;
* expected versus actual settlement;
* missing settlement items;
* duplicate items;
* mismatch by merchant;
* reconciliation trend.

# 11. Grafana implementation

Grafana digunakan untuk dua jenis data:

## Data-level monitoring

Grafana membaca ClickHouse langsung menggunakan ClickHouse datasource plugin. Plugin tersebut membutuhkan host, port, database, username, dan password ClickHouse. ([ClickHouse][5])

Panel:

* incoming events per second;
* payment CDC records per minute;
* pipeline latency;
* latest ingested event;
* failed parsing count;
* deleted event count;
* settlement event count.

## Infrastructure monitoring

Untuk monitoring service, tambahkan Prometheus:

```text
Java Actuator / Micrometer ─────┐
PostgreSQL exporter ────────────┤
Kafka JMX exporter ─────────────┤
Kafka Connect JMX exporter ─────┼──> Prometheus ──> Grafana
ClickHouse metrics endpoint ────┘
```

ClickHouse mendokumentasikan dua pendekatan monitoring Grafana: koneksi plugin langsung dan pendekatan berbasis Prometheus. Pendekatan Prometheus lebih sesuai untuk menjaga pemisahan antara operational monitoring dan analytical workload. ([ClickHouse][6])

## Dashboard Grafana

### Pipeline Health

* events generated per second;
* Kafka incoming messages;
* Kafka consumer lag;
* Debezium connector status;
* source-to-ClickHouse latency;
* last event received;
* failed or skipped record.

### PostgreSQL Health

* active connection;
* transaction rate;
* database size;
* WAL generated;
* replication slot retained WAL;
* long-running transaction.

### ClickHouse Health

* insert rate;
* query rate;
* query duration;
* active parts;
* background merges;
* disk usage;
* memory usage.

### Java Generator Health

* generated payment rate;
* scheduler execution time;
* scheduler failures;
* JVM heap;
* thread count;
* database connection pool.

## Alert rules

Contoh:

```text
Generator aktif tetapi tidak ada event selama 2 menit
Pipeline p95 latency > 5 detik
Debezium connector tidak running
Kafka consumer lag terus meningkat
Replication slot retained WAL terlalu besar
ClickHouse disk usage > 80%
Settlement mismatch ditemukan
dbt test terakhir gagal
```

# 12. Docker Compose profiles

Karena laptop Anda RAM 16 GB, jangan selalu menjalankan semua service.

Gunakan Compose profiles:

```yaml
profiles:
  core:
    - postgres
    - kafka
    - kafka-connect
    - clickhouse
    - payment-generator

  bi:
    - superset
    - superset-metadata-db

  monitoring:
    - prometheus
    - grafana
    - postgres-exporter

  tools:
    - kafka-ui
```

Command:

```bash
docker compose --profile core up -d
docker compose --profile bi up -d
docker compose --profile monitoring up -d
```

dbt sebaiknya dijalankan sebagai container one-off:

```bash
docker compose run --rm dbt build
```

Bukan container yang selalu hidup.

# 13. Struktur repository

```text
payflow-analytics/
├── apps/
│   └── payment-generator/
│
├── infrastructure/
│   ├── postgres/
│   │   ├── init/
│   │   └── config/
│   │
│   ├── kafka/
│   │   └── topics/
│   │
│   ├── kafka-connect/
│   │   └── connectors/
│   │       └── postgres-source.json
│   │
│   ├── clickhouse/
│   │   ├── users/
│   │   └── migrations/
│   │       ├── 001_databases.sql
│   │       ├── 002_kafka_tables.sql
│   │       ├── 003_raw_tables.sql
│   │       ├── 004_materialized_views.sql
│   │       ├── 005_core_tables.sql
│   │       └── 006_monitoring_views.sql
│   │
│   ├── superset/
│   │   ├── config/
│   │   └── dashboards/
│   │
│   ├── grafana/
│   │   ├── provisioning/
│   │   │   ├── datasources/
│   │   │   └── dashboards/
│   │   └── dashboards/
│   │
│   └── prometheus/
│       ├── prometheus.yml
│       └── alerts.yml
│
├── dbt/
│   └── payflow_analytics/
│
├── tests/
│   ├── integration/
│   ├── end-to-end/
│   ├── data-quality/
│   └── performance/
│
├── scripts/
│   ├── register-connector.sh
│   ├── create-topics.sh
│   ├── check-pipeline.sh
│   └── reset-local.sh
│
├── docs/
│   ├── architecture.md
│   ├── data-flow.md
│   ├── data-model.md
│   ├── kafka-topics.md
│   ├── clickhouse-modeling.md
│   ├── failure-scenarios.md
│   ├── runbook.md
│   ├── benchmark.md
│   └── adr/
│
├── docker-compose.yml
├── Makefile
├── .env.example
└── README.md
```

# 14. Makefile commands

```makefile
up-core:
	docker compose --profile core up -d

up-bi:
	docker compose --profile bi up -d

up-monitoring:
	docker compose --profile monitoring up -d

register-connector:
	./scripts/register-connector.sh

dbt-build:
	docker compose run --rm dbt build

dbt-test:
	docker compose run --rm dbt test

test-pipeline:
	./scripts/check-pipeline.sh

logs:
	docker compose logs -f

down:
	docker compose down

reset:
	./scripts/reset-local.sh
```

# 15. Tahapan implementasi

## Fase 1 — PostgreSQL dan Java generator

Implementasikan:

* Flyway migrations;
* merchants;
* payment methods;
* payments;
* status history;
* refunds;
* settlement tables;
* Java schedulers;
* scenario API;
* Actuator metrics.

Selesai apabila:

* payment baru terus dibuat;
* status berubah otomatis;
* refund dapat dibuat;
* settlement batch dapat dihasilkan;
* data konsisten dalam PostgreSQL.

## Fase 2 — Debezium dan Kafka

Implementasikan:

* PostgreSQL logical replication;
* replication user;
* publication;
* Kafka broker;
* Kafka Connect;
* Debezium connector;
* topic creation;
* unwrap transformation.

Selesai apabila:

* insert muncul di Kafka;
* update status muncul di Kafka;
* refund muncul di topic;
* connector restart dapat melanjutkan pemrosesan;
* snapshot awal berhasil.

## Fase 3 — ClickHouse ingestion

Implementasikan:

* Kafka engine tables;
* raw tables;
* materialized views;
* current-state tables;
* event-history tables;
* real-time aggregate tables.

Selesai apabila:

* data Kafka masuk ClickHouse;
* current state sesuai PostgreSQL;
* semua status history tersimpan;
* duplicate tidak merusak current state;
* pipeline latency dapat dihitung.

## Fase 4 — dbt modeling

Implementasikan:

* source definitions;
* staging models;
* intermediate models;
* marts;
* generic tests;
* singular tests;
* dbt documentation.

Selesai apabila:

```bash
dbt build
```

lulus dan menghasilkan:

* payment performance mart;
* merchant daily mart;
* settlement reconciliation mart;
* failure analysis mart.

## Fase 5 — Superset

Implementasikan:

* ClickHouse connection;
* datasets;
* four business dashboards;
* dashboard filters;
* dashboard export.

Selesai apabila:

* data dashboard sesuai SQL ClickHouse;
* filter merchant dan tanggal bekerja;
* settlement mismatch terlihat;
* screenshot dashboard tersedia untuk README.

## Fase 6 — Grafana dan Prometheus

Implementasikan:

* Grafana ClickHouse datasource;
* Prometheus;
* Java metrics;
* Kafka metrics;
* PostgreSQL metrics;
* ClickHouse metrics;
* alert rules.

Selesai apabila:

* throughput terlihat;
* pipeline latency terlihat;
* Kafka lag terlihat;
* connector failure dapat dideteksi;
* alert muncul ketika pipeline dihentikan.

## Fase 7 — Reliability testing

Uji skenario:

### Kafka berhenti

```text
Generator tetap menulis ke PostgreSQL
→ WAL tertahan
→ Kafka hidup kembali
→ pipeline melanjutkan data
```

### ClickHouse berhenti

```text
Kafka mempertahankan message
→ ClickHouse hidup kembali
→ consumer mengejar backlog
```

### Debezium restart

```text
Connector berhenti
→ restart
→ melanjutkan dari stored offset
```

### Duplicate event

Pastikan:

```text
raw layer menyimpan event
current-state tetap satu versi terbaru
mart tidak menghitung transaksi dua kali
```

### Out-of-order version

Simulasikan:

```text
version 4 masuk
version 3 datang terlambat
```

Current state harus tetap version 4.

### Settlement mismatch

Simulasikan:

```text
expected: 980,000
actual:   970,000
difference: -10,000
```

Mismatch harus terlihat di:

* dbt mart;
* Superset;
* Grafana alert.

## Fase 8 — Benchmark dan dokumentasi

Uji:

```text
5 payments/second
20 payments/second
50 payments/second
```

Catat:

* generated records;
* Kafka throughput;
* p50 pipeline latency;
* p95 pipeline latency;
* ClickHouse insert rate;
* dashboard query duration;
* duplicate count;
* failed event count.

Jangan mencantumkan klaim performa sebelum angka benar-benar diukur.

# 16. Test strategy

## Java unit tests

* amount calculation;
* fee calculation;
* payment transition validation;
* refund limit;
* settlement calculation;
* scenario probability.

## PostgreSQL integration tests

* payment dan status history tersimpan atomik;
* settlement batch dan items konsisten;
* invalid transition ditolak.

## Pipeline integration tests

```text
Insert payment PostgreSQL
→ event Kafka ditemukan
→ row ClickHouse ditemukan
```

## dbt tests

* uniqueness;
* not-null;
* accepted values;
* relationship;
* financial reconciliation;
* lifecycle consistency.

## Dashboard validation

Untuk setiap KPI penting, simpan SQL pembanding:

```text
dashboard total transaction
=
query manual ClickHouse
```

# 17. Prioritas implementasi

Urutan yang paling aman:

```text
1. Java + PostgreSQL
2. Debezium + Kafka
3. ClickHouse raw ingestion
4. ClickHouse current state dan event history
5. Real-time aggregate
6. dbt staging dan marts
7. Superset
8. Grafana direct ClickHouse
9. Prometheus infrastructure monitoring
10. Reliability tests
11. Benchmark
12. Documentation
```

Jangan memulai Superset atau Grafana sebelum alur berikut stabil:

```text
Java
→ PostgreSQL
→ Debezium
→ Kafka
→ ClickHouse
```

# 18. Komponen yang tidak perlu ditambahkan

Untuk scope ini, jangan tambahkan dulu:

* Airflow;
* Spark;
* Flink;
* Cassandra;
* Kubernetes;
* MinIO;
* machine-learning fraud detection;
* banyak microservice;
* Schema Registry.

Stack yang sekarang sudah cukup untuk menunjukkan:

* OLTP modeling;
* CDC;
* event streaming;
* real-time OLAP;
* ClickHouse modeling;
* dbt transformation;
* data quality;
* BI dashboard;
* operational monitoring;
* failure recovery.

**Keputusan final yang saya sarankan:** gunakan dbt Core tanpa Airflow. Materialized view ClickHouse menangani ingestion dan real-time aggregation, dbt menangani model bisnis dan data mart, Superset membaca business marts, sedangkan Grafana membaca real-time pipeline metrics dan Prometheus.

[1]: https://debezium.io/documentation/reference/stable/connectors/postgresql.html "Debezium connector for PostgreSQL :: Debezium Documentation"
[2]: https://github.com/ClickHouse/dbt-clickhouse/blob/main/README.md "dbt-clickhouse/README.md at main · ClickHouse/dbt-clickhouse · GitHub"
[3]: https://clickhouse.com/clickhouse?utm_source=chatgpt.com "Real-Time Data Analytics Platform | ClickHouse"
[4]: https://superset.apache.org/user-docs/databases/supported/clickhouse/ "ClickHouse | Superset"
[5]: https://clickhouse.com/docs/integrations/grafana "ClickHouse data source plugin for Grafana - ClickHouse Documentation"
[6]: https://clickhouse.com/docs/use-cases/observability/oss-monitoring "Self-managed monitoring - ClickHouse Documentation"
