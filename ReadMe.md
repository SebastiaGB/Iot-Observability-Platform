# IoT Server Room Monitoring

## 1. Descripción del proyecto

**IoT Server Room Monitoring** es una arquitectura completa que simula una sala de servidores equipada con sensores IoT (temperatura, humedad y energía). Un script genera eventos simulados que representan distintos escenarios ambientales. Estos datos son recibidos por **API Gateway**, decodificados por funciones **Lambda**, almacenados en una base de datos **RDS**, y expuestos como métricas mediante **Prometheus** y **Grafana**, ofreciendo monitorización en tiempo real del entorno simulado. Todos los servicios persistentes (IoT Gateway, Prometheus y Grafana) se ejecutan como contenedores en **ECS Fargate**, dentro de una **VPC privada** junto con RDS.

---

## 2. Problema que resuelve

Las salas de servidores requieren monitorización continua de parámetros críticos para evitar fallos ambientales. Este proyecto recrea un entorno realista sin necesidad de hardware físico y permite validar flujos de ingesta IoT, decodificación de datos, almacenamiento, monitorización y alertado, aplicando buenas prácticas de arquitectura en AWS.

---

## 3. Endpoints clave y funcionalidades mínimas

### API Gateway

**POST `/data`**  
Recibe los datos enviados por el gateway IoT y los reenvía a la función Lambda `decode_payload`.

### Funcionalidades principales

- Simulación de sensores ambientales (temperatura, humedad, energía).  
- Gateway IoT enviando datos periódicos.  
- Lambda para decodificación de payloads.  
- Lambda para insertar datos en RDS (`sensor_data`).  
- Exportador de métricas integrado dentro del gateway.  
- Prometheus scrappeando el endpoint del gateway.  
- Grafana para dashboards:
  - Estado del Server Room  
  - Métricas internas del Gateway  
  - Alertas vía SNS  

---

## 4. Tecnologías y lenguajes utilizados

### Lenguaje principal

- Python

### Containerización / Orquestación

- Docker  
- Amazon ECS (Fargate)  

### AWS Services

- AWS Lambda  
- Amazon API Gateway  
- Amazon RDS (PostgreSQL)  
- VPC con subredes públicas, privadas con NAT y privadas sin NAT  
- Application Load Balancer (ALB)  
- CloudWatch Logs  
- SNS (alertas)  
- IAM Roles  

### Monitorización

- Prometheus  
- Grafana  

### Infraestructura como código (opcional)

- Terraform o AWS CDK  

---

## 5. Estructura de carpetas sugerida

iot-project/
│
├── gateway/ # Código del IoT Gateway
│ ├── gateway.py
│ ├── config.py
│ ├── utils.py
│ ├── requirements.txt
│ └── Dockerfile
│
├── lambdas/
│ ├── decode_payload/
│ │ ├── app.py
│ │ └── requirements.txt
│ ├── proces_payload/
│ │ ├── app.py
│ │ └── requirements.txt
│
├── monitoring/
│ ├── prometheus/
│ │ ├── prometheus.yml
│ │ └── Dockerfile
│ └── grafana/
│ ├── dashboards/
│ ├── provisioning/
│ └── Dockerfile
│
├── infra/ # Terraform / IaC
│
└── README.md

yaml
Copy code

---

## 6. Notas de despliegue

1. Construir las imágenes Docker de **gateway**, **Prometheus** y **Grafana**.  
2. Subir las imágenes a **ECR** (si quieres) o usar imágenes locales.  
3. Crear **Task Definitions** en ECS Fargate con los puertos correspondientes:  
   - Gateway: 3000  
   - Prometheus: 9090  
   - Grafana: 3000  
4. Crear un **Cluster ECS** y desplegar los servicios.  
5. Configurar **ALB** para exponer Grafana y/o Gateway a internet.  
6. Configurar API Gateway y Lambdas con roles e integraciones necesarias.  
7. Configurar Prometheus para scrappear el Gateway y Grafana para mostrar dashboards y alertas.

---

## 7. Requisitos

- Cuenta AWS con permisos para ECS, Lambda, API Gateway, RDS, IAM, VPC y ALB.  
- Docker instalado localmente para construir imágenes.  
- Terraform / CDK si se quiere automatizar infraestructura.  
- Python 3.x y librerías especificadas en `requirements.txt`. 