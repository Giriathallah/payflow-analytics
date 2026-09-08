#!/bin/bash
set -e

echo "► Resetting local environment..."
docker compose --profile core --profile bi --profile monitoring --profile tools down -v
echo "✅ Volumes and containers removed."
echo "► Starting core services..."
docker compose --profile core up -d
echo "✅ Local reset complete."
