FROM grafana/grafana:latest

# Necesario para esperar a Postgres
USER root
RUN apk add --no-cache netcat-openbsd

# Copiar provisioning
COPY provisioning/ /etc/grafana/provisioning/

# Copiar dashboards JSON
COPY dashboards/ /var/lib/grafana/dashboards/

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Dashboard por defecto
ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/SensorMonitoring.json

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
