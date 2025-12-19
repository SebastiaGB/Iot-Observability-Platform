import os
import json
import time
import threading
import random
import requests
import psutil
from flask import Flask, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from utils import encode_to_hex

# -------------------------------
# Configuración desde variables de entorno
# -------------------------------
API_URL = os.environ.get("API_URL")
INTERVAL = int(os.environ.get("INTERVAL"))
SENSORS = [
    {"device_id": os.environ.get("TEMP_SENSOR_ID", "temp_sensor_1"), "type": "temperature"},
    {"device_id": os.environ.get("HUMIDITY_SENSOR_ID", "humidity_sensor_1"), "type": "humidity"},
    {"device_id": os.environ.get("POWER_SENSOR_ID", "power_sensor_1"), "type": "power"},
]


# -------------------------------
# Prometheus metrics
# -------------------------------
metric_sent = Counter("gateway_messages_sent_total", "Mensajes enviados", ["sensor"])
metric_errors = Counter("gateway_errors_total", "Errores de envío", ["sensor"])
metric_latency = Histogram("gateway_request_latency_seconds", "Tiempo de envío a Lambda", ["sensor"])
metric_cpu = Gauge("gateway_cpu_percent", "CPU usage percent del gateway")
metric_mem = Gauge("gateway_memory_mb", "Memoria usada en MB del gateway")

# -------------------------------
# Flask app para Prometheus
# -------------------------------
app = Flask(__name__)

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain")

@app.route("/health")
def health():
    return {"status": "ok"}, 200

# -------------------------------
# Sistema: CPU y memoria
# -------------------------------
def track_system_metrics(interval=5):
    process = psutil.Process()
    while True:
        metric_cpu.set(process.cpu_percent(interval=None))
        metric_mem.set(process.memory_info().rss / (1024 * 1024))
        time.sleep(interval)

threading.Thread(target=track_system_metrics, daemon=True).start()

# -------------------------------
# Sensor simulation
# -------------------------------
def simulate_sensor(sensor):
    device_id = sensor["device_id"]
    sensor_type = sensor["type"]

    while True:
        # Generar valor con anomalías
        if sensor_type == "temperature":
            value = random.uniform(18, 27) if random.random() > 0.05 else random.choice([random.uniform(10, 17.99), random.uniform(27.01, 35)])
        elif sensor_type == "humidity":
            value = random.uniform(40, 60) if random.random() > 0.05 else random.choice([random.uniform(20, 39.99), random.uniform(60.01, 70)])
        elif sensor_type == "power":
            value = random.uniform(630, 850) if random.random() > 0.05 else random.uniform(851, 1050)
        else:
            print(f"[WARN] Unknown sensor type {sensor_type}")
            time.sleep(INTERVAL)
            continue

        # Codificar valor
        hex_payload = encode_to_hex(value, sensor_type)
        payload = {
            "device_id": device_id,
            "sensor_type": sensor_type,
            "payload": hex_payload,
            "timestamp": time.time()
        }

        # Enviar a Lambda
        start = time.time()
        try:
            r = requests.post(API_URL, json=payload, timeout=5)
            metric_sent.labels(sensor=sensor_type).inc()
            metric_latency.labels(sensor=sensor_type).observe(time.time() - start)
            print(f"[{device_id}] Sent value={value:.2f}, hex={hex_payload} → {r.status_code}")
        except Exception as e:
            metric_errors.labels(sensor=sensor_type).inc()
            print(f"[{device_id}] Error sending data: {e}")

        time.sleep(INTERVAL)

# -------------------------------
# Iniciar un thread por sensor
# -------------------------------
for sensor in SENSORS:
    threading.Thread(target=simulate_sensor, args=(sensor,), daemon=True).start()

# -------------------------------
# Iniciar servidor Flask
# -------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
