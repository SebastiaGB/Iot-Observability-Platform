# IoT Sensor Gateway & Monitoring Platform

> Este proyecto tiene como objetivo migrar un sistema de monitorización de apartamentos telemáticos 
> originalmente desarrollado en IBdigital hacia un entorno cloud moderno, utilizando servicios de AWS 
> como ECS, RDS, Lambda, ECR y API Gateway.

Solución completa para simular sensores IoT, procesar datos en tiempo real, almacenarlos en RDS, y monitorizar el sistema con Prometheus + Grafana, desplegada íntegramente en AWS usando CloudFormation y ECS Fargate.

El proyecto cubre el flujo completo IoT → API → Lambda → Base de datos → Observabilidad, aplicando buenas prácticas de seguridad, secrets management y despliegue reproducible.

---

## Estructura de Carpetas

```

iot-sensor-platform/
├── backend/
│   ├── app/
│   │   ├── gateway.py
│   │   └── utils.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── grafana/
│   ├── dashboards/
│   │   └── SensorMonitoring.json
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasource.yaml
│   │   ├── dashboards/
│   │   │   └── dashboard.yaml
│   │   └── alerting/
│   │       ├── alerting.yaml
│   │       ├── contactpoints.yaml
│   │       └── notification-policies.yaml
│   ├── entrypoint.sh
│   └── Dockerfile
│
├── cloudformation/
│   ├── network.yaml
│   ├── security.yaml
│   ├── rds.yaml
│   ├── db-init.yaml
│   ├── lambdas.yaml
│   ├── api-gateway.yaml
│   ├── ecr-gateway.yaml
│   ├── ecr-grafana.yaml
│   ├── ecs-cluster.yaml
│   ├── ecs-gateway-service.yaml
│   ├── ecs-grafana-service.yaml
│   └── alb-grafana.yaml
│
│
├── deploy-iot.sh
└── README.md

```

## Cómo funciona

1. **IoT Gateway (ECS Fargate)**
   - Simula sensores de **temperatura, humedad y consumo eléctrico** en una sala de servidores.
   - Genera lecturas periódicas con anomalías controladas.
   - Codifica los valores en **hexadecimal**.
   - Envía los datos vía **HTTP POST** a API Gateway.
   - Expone `/health` y métricas Prometheus (`/metrics`).
   - Se ejecuta como **servicio ECS Fargate** a partir de una imagen en ECR.

2. **API Gateway + Lambdas**
   - API Gateway expone el endpoint `POST /data`.
   - **Lambda Decode**:
     - Decodifica el payload hexadecimal.
     - Normaliza y valida los valores.
     - Invoca de forma síncrona a la Lambda de procesamiento.
   - **Lambda Process**:
     - Inserta las mediciones en **Amazon RDS PostgreSQL**.
     - Se ejecuta en subnets privadas dentro de la VPC.

3. **Base de datos (Amazon RDS – PostgreSQL)**
   - Desplegada en **subnets privadas**, sin acceso público.
   - Almacena:
     - Device ID
     - Tipo de sensor
     - Valor
     - Timestamp
   - Inicializada automáticamente mediante una **Lambda de creación de tablas**.

4. **Observabilidad (Grafana)**
   - Grafana se ejecuta como **servicio ECS Fargate**.
   - Conecta directamente a PostgreSQL como datasource.
   - Muestra:
     - Estado actual de los sensores
     - Series temporales
     - Histogramas de valores
   - Incluye **alertas configuradas**, con notificaciones vía **Amazon SNS**.
   - Es el único componente accesible públicamente mediante un **Application Load Balancer**.

5. **Infraestructura (AWS)**
   - **VPC privada** con separación de subnets:
     - Públicas: ALB, NAT Gateway
     - Privadas App: ECS, Lambdas
     - Privadas DB: RDS
   - **ECS Cluster** dedicado para Gateway y Grafana.
   - **ECR** para imágenes Docker.
   - **IAM** con permisos mínimos por componente.
   - **Secrets Manager** para credenciales.
   - Despliegue completamente automatizado con **CloudFormation**.

---

## Configuración previa

1. Crear **Bucket S3** y añadir los siguientes archivos: 
   - `decode_payload.zip`
   - `lambda-package.zip`
   - `process_payload.zip`  
   > Se pueden encontrar en la carpeta `ZiPS`

2. Crear **Secrets Manager**:  

```bash
aws secretsmanager create-secret \
  --name iot/grafana/credentials \
  --secret-string '{
    "grafana_admin_password":"<grafana_password>",
    "postgres_password":"<db_password>"
  }'

```
3. Modificar los siguientes archivos antes de desplegar:

- `cloudformation/db-init.yaml` (línea 56) → indicar nombre de bucket S3 creado.

- `grafana/alerting/contactpoints.yaml` (línea 10) → indicar tu AWS Account ID.

## Despliegue

```bash

./deploy-local.sh

```

Usar la url proporcionada por el alb para acceder a grafana.


## Health Checks

### Grafana

```
http://<ALB_GRAFANA>
```

### API

```
https://<API_GATEWAY_URL>/data
```

### Requisitos

- AWS CLI configurado (`aws configure`)  
- Docker  

---

