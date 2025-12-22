#!/bin/sh
set -e

echo "⏳ Waiting for Postgres at $POSTGRES_ENDPOINT:5432..."
until nc -z "$POSTGRES_ENDPOINT" 5432; do
  sleep 3
done

echo "✅ Postgres ready, starting Grafana"
exec /run.sh
