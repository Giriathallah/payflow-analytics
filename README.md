# 💳 Payflow Analytics — Real-Time Payment Data Platform

> **End-to-End Real-Time Payment Gateway Analytics Platform**: Streaming OLTP transactions (PostgreSQL) into a Real-Time OLAP Data Warehouse (ClickHouse) using Change Data Capture (Debezium & Kafka), Data Modeling (dbt), Business Intelligence (Apache Superset), and Operational Observability (Grafana & Prometheus).

---

## 📌 Architecture Overview

```text
┌───────────────────────────────────────┐
│ Java Payment Data Generator           │
│ Spring Boot 3 + Scheduled Jobs        │
│                                       │
│ - Automatic transaction generation    │
│ - Dynamic status lifecycle processing │
│ - Refund & Settlement batching        │
│ - REST API for simulation scenarios   │
└──────────────────┬────────────────────┘
                   │ INSERT / UPDATE
                   ▼
┌───────────────────────────────────────┐
│ PostgreSQL 16 OLTP Database           │
│ (merchants, payments, status history, │
│  refunds, settlement_batches)         │
└──────────────────┬────────────────────┘
                   │ Logical Replication (pgoutput)
                   ▼
┌───────────────────────────────────────┐
│ Debezium CDC + Apache Kafka           │
│ Real-time Event Streaming             │
└──────────────────┬────────────────────┘
                   │ Consume Events
                   ▼
┌───────────────────────────────────────┐
│ ClickHouse OLAP Data Warehouse        │
│ Real-Time Materialized Views          │
└────────────┬──────────────────────────┘
             │
             ├───────────────────────────────┐
             ▼                               ▼
┌───────────────────────────┐  ┌────────────────────────────┐
│ dbt Core (dbt-clickhouse) │  │ Real-Time Serving Tables   │
│ Data Transformation       │  │ Analytics & Aggregations   │
└────────────┬──────────────┘  └─────────────┬──────────────┘
             │                               │
             ▼                               ▼
┌───────────────────────────┐  ┌────────────────────────────┐
│ Apache Superset           │  │ Grafana & Prometheus       │
│ Business BI & Dashboards  │  │ Operational Monitoring     │
└───────────────────────────┘  └────────────────────────────┘
```

---

## 🛠️ Technology Stack

| Layer | Component | Technology / Version | Description |
| :--- | :--- | :--- | :--- |
| **Source System** | Payment Generator | Java 21, Spring Boot 3.3 | Transaction simulator & scenario driver |
| **OLTP Database** | PostgreSQL | PostgreSQL 16 | Transactional database & WAL event source |
| **Database Migrations** | Flyway | Flyway 10 | Automated schema migrations & seed data |
| **Change Data Capture** | Debezium | Debezium 2.7 (Kafka Connect) | Log-based CDC from PostgreSQL WAL |
| **Event Streaming** | Apache Kafka | Confluent CP-Kafka 3.7 | Message broker for CDC events |
| **Real-Time OLAP** | ClickHouse | ClickHouse 24.8 | High-performance columnar database |
| **Data Transformation** | dbt Core | dbt-clickhouse 1.8 | Analytics engineering & data modeling |
| **BI & Analytics** | Apache Superset | Apache Superset | Business dashboards & reporting |
| **Observability** | Grafana & Prometheus | Grafana, Prometheus | System health, metrics & alert monitoring |

---

## 📂 Project Structure

```text
payflow-analytics/
├── apps/
│   └── payment-generator/                # Spring Boot transaction simulator
│       ├── src/main/java/                # Java source code (Controllers, Services, Schedulers)
│       └── src/main/resources/           # Flyway migrations & application configs
│
├── infrastructure/                       # Infrastructure configuration & init scripts
│   ├── postgres/                         # Database initialization scripts
│   ├── kafka-connect/                    # Debezium connector configs
│   ├── clickhouse/                       # ClickHouse schemas & views
│   ├── superset/                         # BI dashboards setup
│   └── grafana/ & prometheus/            # Observability & dashboard configs
│
├── dbt/
│   └── payflow_analytics/                # dbt data transformation project
│
├── docker-compose.yml                    # Multi-profile Docker setup
├── Makefile                              # Helper commands
└── .env.example                          # Environment variable template
```

---

## 🚀 How to Run (Cara Running)

From a fresh clone, run the following sequence. Docker Compose does not auto-create Kafka topics, so topic creation and connector registration are explicit steps.

### 1. Clone and prepare environment

```bash
git clone https://github.com/Giriathallah/payflow-analytics.git
cd payflow-analytics
cp .env.example .env
```

The example values are safe local-development credentials. Change them in `.env` for any shared or non-local environment.

### 2. Start core services

```bash
docker compose --profile core up -d
```

Or use the equivalent Make target:

```bash
make up-core
```

### 3. Create Kafka topics

```bash
make create-topics
```

### 4. Register Debezium connector

```bash
make register-connector
```

The registration script loads `.env` and renders the connector template, so PostgreSQL credentials and CDC naming stay consistent with the compose environment.

### 5. Check health and pipeline

```bash
make health
make check-pipeline
```

### 6. Start the payment generator

```bash
make gen-start
```

### 7. Verify events and OLAP data

```bash
make consume-topic TOPIC=payflow.public.payments
make ch-query Q="SELECT count() FROM payflow_raw.payment_cdc_events"
```

Start optional profiles only when needed:

```bash
docker compose --profile bi up -d
docker compose --profile monitoring up -d
docker compose --profile tools up -d
```

### Fastest demo

For a short interviewer demo:

```bash
make demo
make consume-topic TOPIC=payflow.public.payments
make ch-query Q="SELECT count() FROM payflow_raw.payment_cdc_events"
```

The `demo` target starts core services, creates topics, registers Debezium, starts simulation, and prints service health.

## Project Status

Portfolio / learning project implementing an end-to-end real-time payment analytics pipeline.

Current scope:

- Payment transaction simulation
- PostgreSQL OLTP
- Debezium CDC
- Kafka streaming
- ClickHouse OLAP
- dbt transformation
- Superset BI
- Grafana/Prometheus monitoring

Designed for local development and demonstration, not production deployment.

## 🎮 Simulator Control & Scenario API

The **Payment Generator** exposes REST endpoints at `http://localhost:8080` to dynamically control transaction generation and trigger business failure scenarios:

### API Endpoints

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/api/generator/status` | `GET` | View generator state & TPS |
| `/api/generator/start` | `POST` | Start/Resume payment generation |
| `/api/generator/stop` | `POST` | Pause payment generation |
| `/api/scenarios/failure-spike` | `POST` | Trigger spike of payment authorization failures |
| `/api/scenarios/settlement-mismatch` | `POST` | Force settlement amount mismatch for next batch |
| `/api/scenarios/high-traffic` | `POST` | Trigger high-traffic transaction burst |
| `/api/scenarios/reset` | `POST` | Reset all simulation overrides to normal |

### Usage Examples

```bash
# Check generator status
curl http://localhost:8080/api/generator/status

# Trigger 50% failure rate spike for 30 seconds
curl -X POST "http://localhost:8080/api/scenarios/failure-spike?durationSeconds=30&failureRate=0.5"

# Force settlement discrepancy for next batch
curl -X POST "http://localhost:8080/api/scenarios/settlement-mismatch"

# Trigger high traffic (20 TPS for 60s)
curl -X POST "http://localhost:8080/api/scenarios/high-traffic?durationSeconds=60&targetTps=20"
```

---

## 🌐 Dashboard & Service URLs

| Service | Port / URL | Credentials / Notes |
| :--- | :--- | :--- |
| **Payment Generator REST API** | `http://localhost:8080` | Control & Scenario API |
| **Spring Actuator Metrics** | `http://localhost:8081/actuator/prometheus` | Prometheus metrics endpoint |
| **Kafka UI** | `http://localhost:9080` | Manage topics & consumer groups |
| **Grafana** | `http://localhost:3000` | User: `admin` / Password: `admin` |
| **Apache Superset** | `http://localhost:8088` | User: `admin` / Password: `admin` |
| **Prometheus** | `http://localhost:9090` | System & application metrics |

---

## 🧪 Clean-room verification

To repeat the setup from a clean local state:

```bash
docker compose --profile core --profile bi --profile monitoring --profile tools down -v
```

Then follow the setup sequence above from `cp .env.example .env` onward. The `-v` flag removes local Docker volumes and therefore deletes local demo data.

## 📜 License

Distributed under the [MIT License](LICENSE).
