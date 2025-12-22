#!/bin/sh
set -euo pipefail

echo "⏳ Esperando a PostgreSQL en $POSTGRES_ENDPOINT:5432..."

# Espera hasta que PostgreSQL acepte conexiones
until PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_ENDPOINT" -U iotadmin -d iotrds -c '\q' >/dev/null 2>&1; do
  echo "Esperando a que PostgreSQL esté listo..."
  sleep 3
done

echo "✅ PostgreSQL listo, iniciando Grafana..."

# Ejecuta el proceso principal de Grafana
exec /run.sh
