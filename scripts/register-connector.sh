#!/bin/bash
set -e

CONNECT_URL=${CONNECT_URL:-http://localhost:8083}
CONNECTOR_CONFIG_FILE="$(dirname "$0")/../infrastructure/kafka-connect/connectors/postgres-source.json"

echo "► Checking Kafka Connect availability at ${CONNECT_URL}..."
until curl -s "${CONNECT_URL}/" > /dev/null; do
  echo "  Waiting for Kafka Connect to be ready..."
  sleep 3
done

if [ ! -f "${CONNECTOR_CONFIG_FILE}" ]; then
  echo "❌ Error: Connector config file not found at ${CONNECTOR_CONFIG_FILE}"
  exit 1
fi

CONNECTOR_NAME=$(jq -r '.name' "${CONNECTOR_CONFIG_FILE}")

echo "► Registering connector '${CONNECTOR_NAME}'..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${CONNECT_URL}/connectors" \
  -H "Content-Type: application/json" \
  -d @"${CONNECTOR_CONFIG_FILE}")

if [ "$RESPONSE" -eq 201 ]; then
  echo "✅ Connector '${CONNECTOR_NAME}' registered successfully!"
elif [ "$RESPONSE" -eq 409 ]; then
  echo "ℹ️ Connector '${CONNECTOR_NAME}' already exists. Updating configuration..."
  CONNECTOR_CONFIG=$(jq '.config' "${CONNECTOR_CONFIG_FILE}")
  curl -s -X PUT "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config" \
    -H "Content-Type: application/json" \
    -d "${CONNECTOR_CONFIG}" > /dev/null
  echo "✅ Connector '${CONNECTOR_NAME}' updated successfully!"
else
  echo "❌ Failed to register connector '${CONNECTOR_NAME}'. HTTP status: ${RESPONSE}"
  curl -s "${CONNECT_URL}/connectors" | jq .
  exit 1
fi

echo "► Checking connector status..."
curl -s "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" | jq .
