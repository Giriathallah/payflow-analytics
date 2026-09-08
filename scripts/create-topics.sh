#!/bin/bash
set -e

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

KAFKA_CONTAINER=${KAFKA_CONTAINER:-payflow-kafka}
BOOTSTRAP_SERVER=${BOOTSTRAP_SERVER:-kafka:9092}

TOPIC_PREFIX=${KAFKA_TOPIC_PREFIX:-payflow}
TOPICS=(
  "${TOPIC_PREFIX}.public.merchants"
  "${TOPIC_PREFIX}.public.payment_methods"
  "${TOPIC_PREFIX}.public.payments"
  "${TOPIC_PREFIX}.public.payment_status_history"
  "${TOPIC_PREFIX}.public.refunds"
  "${TOPIC_PREFIX}.public.settlement_batches"
  "${TOPIC_PREFIX}.public.settlement_items"
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
