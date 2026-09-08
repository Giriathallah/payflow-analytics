#!/usr/bin/env bash
set -e

echo "=== Initializing Apache Superset for PayFlow Analytics ==="

# Check container status
if ! docker compose ps --services --filter "status=running" | grep -q "superset"; then
    echo "[INFO] Starting Superset profile containers..."
    docker compose --profile bi up -d
fi

echo "[INFO] Waiting for Superset container to be ready..."
until curl -sf http://localhost:8088/health >/dev/null 2>&1; do
    echo "[WAIT] Superset is starting..."
    sleep 5
done

echo "[INFO] Executing Superset DB migrations and admin user creation..."
docker compose exec -T superset superset db upgrade
docker compose exec -T superset superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@payflow.local \
    --password admin || true
docker compose exec -T superset superset init

echo "[INFO] Running ClickHouse connection & dashboard initialization script..."
docker compose exec -T superset python /app/init-superset.py

echo "=== Superset setup completed successfully ==="
echo "Access Superset UI at http://localhost:8088 (admin / admin)"
