#!/bin/bash
set -e

KAFKA_CONTAINER=${KAFKA_CONTAINER:-payflow-kafka}
BOOTSTRAP_SERVER=${BOOTSTRAP_SERVER:-kafka:9092}

TOPICS=(
  "payflow.public.merchants"
  "payflow.public.payment_methods"
  "payflow.public.payments"
  "payflow.public.payment_status_history"
  "payflow.public.refunds"
  "payflow.public.settlement_batches"
  "payflow.public.settlement_items"
)

echo "► Creating Kafka topics..."

for topic in "${TOPICS[@]}"; do
  echo "  Creating topic: ${topic}"
  docker exec "${KAFKA_CONTAINER}" kafka-topics \
    --bootstrap-server "${BOOTSTRAP_SERVER}" \
    --create --if-not-exists \
    --topic "${topic}" \
    --partitions 3 \
    --replication-factor 1 \
    --config retention.ms=604800000
done

echo "✅ All Kafka topics created successfully."
