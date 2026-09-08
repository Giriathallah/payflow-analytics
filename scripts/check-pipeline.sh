#!/bin/bash
set -e

CONNECT_URL=${CONNECT_URL:-http://localhost:8083}
KAFKA_CONTAINER=${KAFKA_CONTAINER:-payflow-kafka}

echo "================================================="
echo " Payflow Analytics — Pipeline Verification"
echo "================================================="

echo "1. Checking Kafka Connect Status..."
if curl -s "${CONNECT_URL}/connectors/payflow-postgres-source/status" | grep -q "RUNNING"; then
  echo "   ✅ Debezium connector 'payflow-postgres-source' is RUNNING"
else
  echo "   ⚠️ Debezium connector is NOT running or not registered."
fi

echo "2. Checking PostgreSQL Replication Slots..."
docker exec payflow-postgres psql -U postgres -d payflow -c "SELECT slot_name, plugin, active FROM pg_replication_slots;" || true

echo "3. Listing Kafka Topics..."
docker exec "${KAFKA_CONTAINER}" kafka-topics --bootstrap-server kafka:9092 --list | grep payflow || true

echo "================================================="
echo " Pipeline check complete."
echo "================================================="
