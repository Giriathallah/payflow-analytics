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

### 1. Prepare Environment Variables

Copy `.env.example` to `.env` and fill in your desired environment variables:

```bash
cp .env.example .env
```

### 2. Start Services with Docker Compose Profiles

The services are split into Docker Compose profiles so you can run what you need:

* **Core Services** (PostgreSQL, Kafka, Kafka Connect, ClickHouse, Payment Generator):
  ```bash
  docker compose --profile core up -d
  ```

* **BI Dashboard** (Apache Superset):
  ```bash
  docker compose --profile bi up -d
  ```

* **Monitoring & Observability** (Prometheus & Grafana):
  ```bash
  docker compose --profile monitoring up -d
  ```

* **Developer Tools** (Kafka UI):
  ```bash
  docker compose --profile tools up -d
  ```

---

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

## 📜 License

Distributed under the [MIT License](LICENSE).
