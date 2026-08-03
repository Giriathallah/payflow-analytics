# 💳 Payflow Analytics — Real-Time Payment Data Platform

> **End-to-End Real-Time Payment Gateway Analytics Platform**: From OLTP (PostgreSQL) to Real-Time OLAP (ClickHouse) using Change Data Capture (Debezium, Kafka), dbt Modeling, Apache Superset, and Grafana / Prometheus Observability.

---

## 📌 Architecture Overview

```text
┌───────────────────────────────────────┐
│ Java Payment Data Generator           │
│ Spring Boot 3 + Scheduled Jobs        │
│                                       │
│ - Generate payments (INITIATED)       │
│ - Automate lifecycle transitions      │
│ - Generate refunds & settlements      │
│ - Simulate failure spikes & mismatches│
└──────────────────┬────────────────────┘
                   │ INSERT / UPDATE
                   ▼
┌───────────────────────────────────────┐
│ PostgreSQL 16 OLTP Database           │
│                                       │
│ merchants                             │
│ payments                              │
│ payment_status_history (append-only)  │
│ refunds                               │
│ settlement_batches & items            │
└──────────────────┬────────────────────┘
                   │ PostgreSQL WAL (pgoutput)
                   ▼
┌───────────────────────────────────────┐
│ Debezium PostgreSQL Connector         │
│ running on Kafka Connect              │
└──────────────────┬────────────────────┘
                   │ Change events (CDC)
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
│ ClickHouse OLAP                       │
│                                       │
│ kafka_* tables                        │
│        ↓                              │
│ Materialized Views                    │
│        ↓                              │
│ raw → core → mart                     │
└────────────┬──────────────────────────┘
             │
             ├───────────────────────────────┐
             ▼                               ▼
┌───────────────────────────┐  ┌────────────────────────────┐
│ dbt Core (dbt-clickhouse) │  │ Real-Time Serving Tables   │
│                           │  │                            │
│ staging → intermediate    │  │ minute metrics             │
│ → marts (business models) │  │ payment events             │
│ data quality tests        │  │ current payment state      │
└────────────┬──────────────┘  └─────────────┬──────────────┘
             │                               │
             ▼                               ▼
┌───────────────────────────┐  ┌────────────────────────────┐
│ Apache Superset           │  │ Grafana                    │
│ Business Analytics & BI   │  │ Operational Monitoring     │
└───────────────────────────┘  └─────────────┬──────────────┘
                                             │
                                       Prometheus metrics
```

---

## 🛠️ Technology Stack

| Layer | Component | Technology / Version | Description |
| :--- | :--- | :--- | :--- |
| **Source System** | Payment Generator | Java 21, Spring Boot 3.3 | Transaction simulator & scenario driver |
| **OLTP Database** | PostgreSQL | PostgreSQL 16 (Logical Replication) | Transactional database & WAL event source |
| **DB Migrations** | Flyway | Flyway 10 | Schema evolution & master seed data |
| **Change Data Capture** | Debezium | Debezium 2.7 (Kafka Connect) | Real-time CDC log miner from WAL |
| **Event Streaming** | Apache Kafka | Confluent CP-Kafka 3.7 | Message broker for CDC events |
| **Real-Time OLAP** | ClickHouse | ClickHouse 24.8 | Columnar data warehouse & real-time views |
| **Data Modeling** | dbt Core | dbt-clickhouse 1.8 | Staging, intermediate, & mart transformations |
| **BI & Analytics** | Apache Superset | Apache Superset Latest | Executive & operational BI dashboards |
| **Observability** | Grafana & Prometheus | Grafana Latest, Prometheus | Pipeline health, latency, & infrastructure metrics |

---

## 📂 Project Structure

```text
payflow-analytics/
├── apps/
│   └── payment-generator/                # Java Spring Boot transaction generator
│       ├── src/main/java/com/payflow/generator/
│       │   ├── config/                   # Generator properties & scheduling config
│       │   ├── controller/               # REST API & Scenario endpoints
│       │   ├── domain/                   # JPA entities (Payment, Merchant, etc.)
│       │   ├── repository/               # Spring Data JPA repositories
│       │   ├── scheduler/                # Scheduled job triggers
│       │   └── service/                  # Core simulation logic & scenario drivers
│       └── src/main/resources/
│           ├── db/migration/             # Flyway SQL migrations (V1 schema, V2 seed)
│           └── application.yml           # App configuration & metrics settings
│
├── infrastructure/
│   ├── postgres/                         # Init scripts & configuration
│   ├── kafka/                            # Kafka topic initialization scripts
│   ├── kafka-connect/                    # Debezium connector registration configs
│   ├── clickhouse/                       # Users, databases, & SQL migrations
│   ├── superset/                         # BI configurations & dashboards
│   ├── grafana/                          # Dashboards & datasource provisioning
│   └── prometheus/                       # Prometheus target configs & alert rules
│
├── dbt/
│   └── payflow_analytics/                # dbt data modeling project for ClickHouse
│
├── scripts/                              # Pipeline orchestration & check scripts
├── docker-compose.yml                    # Multi-profile container setup
├── Makefile                              # Command shortcuts
└── .env.example                          # Environment variables template
```

---

## ⚡ Quickstart & Setup Guide

### 1. Prerequisites

Ensure you have installed:
- [Docker Engine & Docker Compose](https://docs.docker.com/engine/install/) (v2.20+)
- Java 21 JDK (Optional, for local Java execution)

### 2. Environment Configuration

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

### 3. Running Services with Docker Profiles

Because running the entire pipeline requires ~6-8 GB RAM, services are organized into Docker Compose profiles:

* **Core Pipeline** (`postgres`, `kafka`, `kafka-connect`, `clickhouse`, `payment-generator`):
  ```bash
  docker compose --profile core up -d
  ```

* **Business Intelligence** (`superset`, `superset-db`):
  ```bash
  docker compose --profile bi up -d
  ```

* **Monitoring & Observability** (`prometheus`, `grafana`, Exporters):
  ```bash
  docker compose --profile monitoring up -d
  ```

* **Tools** (`kafka-ui`):
  ```bash
  docker compose --profile tools up -d
  ```

---

## 🎮 Simulator Control & Scenario APIs

The **Java Payment Generator** exposes control and scenario endpoints at `http://localhost:8080`:

| Endpoint | Method | Parameters | Description |
| :--- | :--- | :--- | :--- |
| `/api/generator/status` | `GET` | — | Check generator running state & TPS |
| `/api/generator/start` | `POST` | — | Resume payment generation |
| `/api/generator/stop` | `POST` | — | Pause payment generation |
| `/api/generator/config` | `GET` / `PUT` | Config JSON | View or update simulation properties |
| `/api/scenarios/failure-spike` | `POST` | `durationSeconds=60`, `failureRate=0.4` | Inject authorization failure spike |
| `/api/scenarios/settlement-mismatch` | `POST` | — | Force net discrepancy in next settlement batch |
| `/api/scenarios/high-traffic` | `POST` | `durationSeconds=60`, `targetTps=20` | Trigger high-volume payment burst |
| `/api/scenarios/reset` | `POST` | — | Reset scenario overrides back to default |

### Example Scenario Commands

```bash
# Check generator status
curl http://localhost:8080/api/generator/status

# Inject 50% failure spike for 30 seconds
curl -X POST "http://localhost:8080/api/scenarios/failure-spike?durationSeconds=30&failureRate=0.5"

# Trigger settlement net mismatch for next batch
curl -X POST "http://localhost:8080/api/scenarios/settlement-mismatch"

# Trigger high traffic (20 TPS for 60s)
curl -X POST "http://localhost:8080/api/scenarios/high-traffic?durationSeconds=60&targetTps=20"
```

---

## 🗺️ Implementation Roadmap

- [x] **Fase 1 — PostgreSQL & Java Generator**: Flyway schema migrations, Spring Boot transaction engine, schedulers, scenario API, Actuator metrics.
- [ ] **Fase 2 — Debezium & Kafka CDC**: Logical replication, replication slot, Publication setup, Debezium connector registration, topic unwrapping.
- [ ] **Fase 3 — ClickHouse Ingestion**: Kafka engine tables, raw tables, materialized views for real-time deduplication and status history.
- [ ] **Fase 4 — dbt Data Modeling**: Staging models, intermediate lifecycle/financial models, data marts (`mart_payment_performance`, `mart_merchant_daily_performance`, `mart_settlement_reconciliation`), data quality tests.
- [ ] **Fase 5 — Apache Superset BI**: Superset ClickHouse connection, datasets, Executive Overview, Payment Operations, Merchant Analytics, and Settlement Reconciliation dashboards.
- [ ] **Fase 6 — Grafana & Prometheus Observability**: ClickHouse Grafana plugin, Prometheus metrics scraping for Java, Kafka, PostgreSQL, ClickHouse, and pipeline health alert rules.
- [ ] **Fase 7 — Reliability & Failure Scenarios**: Out-of-order event handling, Kafka disconnect recovery, CDC lag monitoring, duplicate event handling.
- [ ] **Fase 8 — Benchmark & Documentation**: Throughput benchmarks (5 TPS $\rightarrow$ 50 TPS), p50/p95 latency measurement, final architecture documentation.

---

## 📊 Useful Service URLs

- **Payment Generator API**: `http://localhost:8080`
- **Actuator & Prometheus Metrics**: `http://localhost:8081/actuator/prometheus`
- **Kafka UI**: `http://localhost:9080`
- **Grafana Dashboards**: `http://localhost:3000` *(User: `admin` / Pass: `admin`)*
- **Apache Superset**: `http://localhost:8088` *(User: `admin` / Pass: `admin`)*
- **Prometheus UI**: `http://localhost:9090`

---

## 📜 License

This project is open-source and available under the [MIT License](LICENSE).
