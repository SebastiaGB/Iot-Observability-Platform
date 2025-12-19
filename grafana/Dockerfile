FROM grafana/grafana:latest

# Copiar provisioning
COPY provisioning/ /etc/grafana/provisioning/

# Copiar dashboards JSON
COPY dashboards/ /var/lib/grafana/dashboards/

# Definir dashboard por defecto
ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/SensorMonitoring.json

EXPOSE 3000
