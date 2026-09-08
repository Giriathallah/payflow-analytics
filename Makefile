# ─────────────────────────────────────────────
# Payflow Analytics — Makefile
# ─────────────────────────────────────────────

.DEFAULT_GOAL := help
SHELL := /bin/bash
COMPOSE := docker compose

.PHONY: help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	    awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ─── Docker Compose lifecycle ───────────────

up-core: ## Start core services (postgres, kafka, connect, clickhouse, generator)
	$(COMPOSE) --profile core up -d

up-bi: ## Start BI stack (superset)
	$(COMPOSE) --profile bi up -d

setup-superset: ## Initialize Superset connection, datasets, and dashboards
	./scripts/setup-superset.sh


up-monitoring: ## Start monitoring stack (prometheus, grafana, exporters)
	$(COMPOSE) --profile monitoring up -d

up-tools: ## Start tooling (kafka-ui)
	$(COMPOSE) --profile tools up -d

up-all: up-core up-bi up-monitoring up-tools ## Start everything

down: ## Stop all services
	$(COMPOSE) --profile core --profile bi --profile monitoring --profile tools down

down-core: ## Stop core services
	$(COMPOSE) --profile core down

down-bi: ## Stop BI services
	$(COMPOSE) --profile bi down

down-monitoring: ## Stop monitoring services
	$(COMPOSE) --profile monitoring down

down-tools: ## Stop tooling
	$(COMPOSE) --profile tools down

ps: ## Show running containers
	$(COMPOSE) ps

logs: ## Tail logs of all services
	$(COMPOSE) logs -f --tail=100

logs-%: ## Tail logs of specific service (make logs-kafka)
	$(COMPOSE) logs -f --tail=100 $*

# ─── Build & rebuild ────────────────────────

build: ## Build all custom images
	$(COMPOSE) --profile core build

build-generator: ## Build payment-generator image
	$(COMPOSE) build payment-generator

rebuild-generator: ## Rebuild payment-generator without cache
	$(COMPOSE) build --no-cache payment-generator

# ─── Kafka ──────────────────────────────────

create-topics: ## Create Kafka topics
	./scripts/create-topics.sh

list-topics: ## List Kafka topics
	docker exec payflow-kafka kafka-topics --bootstrap-server kafka:9092 --list

describe-topic: ## Describe a topic (make describe-topic TOPIC=payflow.public.payments)
	docker exec payflow-kafka kafka-topics --bootstrap-server kafka:9092 --describe --topic $(TOPIC)

consume-topic: ## Consume a topic (make consume-topic TOPIC=payflow.public.payments)
	docker exec payflow-kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic $(TOPIC) --from-beginning --property print.key=true

# ─── Kafka Connect / Debezium ───────────────

register-connector: ## Register Debezium PostgreSQL connector
	./scripts/register-connector.sh

list-connectors: ## List registered connectors
	curl -s http://localhost:8083/connectors | jq .

connector-status: ## Status of all connectors
	curl -s http://localhost:8083/connectors | jq '.[]' | xargs -I{} sh -c 'echo "--- {} ---"; curl -s http://localhost:8083/connectors/{}/status | jq .'

delete-connector: ## Delete connector (make delete-connector NAME=payflow-postgres-source)
	curl -X DELETE http://localhost:8083/connectors/$(NAME)

restart-connector: ## Restart connector tasks
	curl -X POST http://localhost:8083/connectors/$(NAME)/restart?includeTasks=true

# ─── PostgreSQL ─────────────────────────────

psql: ## Open psql shell
	docker exec -it payflow-postgres psql -U postgres -d payflow

psql-app: ## Open psql shell as app user
	docker exec -it payflow-postgres psql -U payflow_app -d payflow

replication-slots: ## Show replication slots
	docker exec payflow-postgres psql -U postgres -d payflow -c "SELECT slot_name, plugin, slot_type, active, restart_lsn FROM pg_replication_slots;"

publications: ## Show publications
	docker exec payflow-postgres psql -U postgres -d payflow -c "SELECT * FROM pg_publication;"

# ─── ClickHouse ─────────────────────────────

ch-client: ## Open clickhouse-client shell
	docker exec -it payflow-clickhouse clickhouse-client --user clickhouse_admin --password clickhouse_admin_pass

ch-query: ## Run a query (make ch-query Q="SELECT count() FROM payflow_raw.payment_cdc_events")
	docker exec payflow-clickhouse clickhouse-client --user clickhouse_admin --password clickhouse_admin_pass -q "$(Q)"

ch-migrations: ## Run all ClickHouse migrations manually
	@for f in infrastructure/clickhouse/migrations/*.sql; do \
	    echo "▶ Running $$f"; \
	    docker exec -i payflow-clickhouse clickhouse-client --user clickhouse_admin --password clickhouse_admin_pass < $$f; \
	done

# ─── dbt ────────────────────────────────────

dbt-debug: ## dbt debug
	$(COMPOSE) run --rm dbt debug

dbt-build: ## dbt build
	$(COMPOSE) run --rm dbt build

dbt-test: ## dbt test
	$(COMPOSE) run --rm dbt test

dbt-run: ## dbt run
	$(COMPOSE) run --rm dbt run

dbt-run-marts: ## dbt run only marts
	$(COMPOSE) run --rm dbt run --select marts

dbt-docs: ## dbt docs generate and serve
	$(COMPOSE) run --rm dbt docs generate
	$(COMPOSE) run --rm dbt docs serve --host 0.0.0.0 --port 8081-dbt

dbt-clean: ## dbt clean
	$(COMPOSE) run --rm dbt clean

dbt-deps: ## dbt deps
	$(COMPOSE) run --rm dbt deps

# ─── Java Generator ─────────────────────────

gen-start: ## Start simulation
	curl -X POST http://localhost:8080/api/generator/start

gen-stop: ## Stop simulation
	curl -X POST http://localhost:8080/api/generator/stop

gen-status: ## Get generator status
	curl -s http://localhost:8080/api/generator/status | jq .

gen-config: ## Get generator config
	curl -s http://localhost:8080/api/generator/config | jq .

gen-scenario-failure: ## Trigger failure spike scenario
	curl -X POST http://localhost:8080/api/scenarios/failure-spike \
	    -H 'Content-Type: application/json' \
	    -d '{"durationSeconds":60,"failureRate":0.4}'

gen-scenario-high-traffic: ## Trigger high traffic scenario
	curl -X POST http://localhost:8080/api/scenarios/high-traffic \
	    -H 'Content-Type: application/json' \
	    -d '{"durationSeconds":60,"tps":50}'

# ─── Pipeline validation ────────────────────

check-pipeline: ## Validate end-to-end pipeline
	./scripts/check-pipeline.sh

health: ## Show health of all services
	@echo "PostgreSQL:"; docker exec payflow-postgres pg_isready -U postgres 2>/dev/null || echo "❌ down"
	@echo "Kafka:"; docker exec payflow-kafka kafka-broker-api-versions --bootstrap-server localhost:9092 >/dev/null 2>&1 && echo "✅ ok" || echo "❌ down"
	@echo "Kafka Connect:"; curl -sf http://localhost:8083/ >/dev/null && echo "✅ ok" || echo "❌ down"
	@echo "ClickHouse:"; curl -sf http://localhost:8123/ping >/dev/null && echo "✅ ok" || echo "❌ down"
	@echo "Generator:"; curl -sf http://localhost:8080/actuator/health >/dev/null 2>&1 && echo "✅ ok" || echo "❌ down"
	@echo "Prometheus:"; curl -sf http://localhost:9090/-/healthy >/dev/null && echo "✅ ok" || echo "❌ down"
	@echo "Grafana:"; curl -sf http://localhost:3000/api/health >/dev/null && echo "✅ ok" || echo "❌ down"
	@echo "Superset:"; curl -sf http://localhost:8088/health >/dev/null && echo "✅ ok" || echo "❌ down"

# ─── Reset & cleanup ────────────────────────

reset: ## Full reset: stop, remove volumes, restart core
	./scripts/reset-local.sh

prune-volumes: ## Remove all volumes (destructive)
	$(COMPOSE) down -v

prune-images: ## Remove unused images
	docker image prune -f

# ─── Utilities ──────────────────────────────

shell-%: ## Open shell in service (make shell-clickhouse)
	docker exec -it payflow-$* /bin/sh || docker exec -it payflow-$* /bin/bash

env: ## Show .env loaded
	@test -f .env && echo ".env exists" || (cp .env.example .env && echo "✅ .env created from .env.example")

init: env ## Initialize project: create .env and scaffold
	@test -d apps/payment-generator/src && echo "✅ Already scaffolded" || ./scripts/scaffold.sh