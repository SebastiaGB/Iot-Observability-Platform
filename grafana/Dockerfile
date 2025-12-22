FROM grafana/grafana:latest

# Cambiar a root para instalar utilidades
USER root

# Instalar netcat y postgresql client para la espera
RUN apk add --no-cache netcat-openbsd postgresql-client bash

# Copiar scripts y provisioning
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY provisioning/ /etc/grafana/provisioning/
COPY dashboards/ /var/lib/grafana/dashboards/

# Dashboard por defecto
ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/SensorMonitoring.json

# Puerto de Grafana
EXPOSE 3000

# Entry point del contenedor
ENTRYPOINT ["/entrypoint.sh"]
