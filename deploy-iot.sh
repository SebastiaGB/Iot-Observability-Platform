#!/bin/bash
set -e

############################################
# 0️⃣ CARGAR ENV
############################################
ENV_FILE="./env/iot-db.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Archivo $ENV_FILE no encontrado"
  exit 1
fi

echo "🔐 Cargando variables desde $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

if [ -z "$DB_PASSWORD" ]; then
  echo "❌ DB_PASSWORD no está definido en $ENV_FILE"
  exit 1
fi

############################################
# VARIABLES GENERALES
############################################
REGION=${AWS_REGION:-us-east-1}
CF_DIR="cloudformation"

echo "🚀 Deploy iniciando en región $REGION"

############################################
# 1️⃣ NETWORK
############################################
echo "🛜 Deploy Network stack..."
aws cloudformation deploy \
  --stack-name iot-network \
  --template-file $CF_DIR/network.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name iot-network \
  --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
  --output text)

PRIVATE_APP_SUBNETS=$(aws cloudformation describe-stacks \
  --stack-name iot-network \
  --query "Stacks[0].Outputs[?OutputKey=='PrivateAppSubnets'].OutputValue" \
  --output text)

PRIVATE_DB_SUBNETS=$(aws cloudformation describe-stacks \
  --stack-name iot-network \
  --query "Stacks[0].Outputs[?OutputKey=='PrivateDbSubnets'].OutputValue" \
  --output text)

PUBLIC_SUBNETS=$(aws cloudformation describe-stacks \
  --stack-name iot-network \
  --query "Stacks[0].Outputs[?OutputKey=='PublicSubnets'].OutputValue" \
  --output text)

############################################
# 2️⃣ SECURITY GROUPS
############################################
echo "🔐 Deploy Security Groups..."
aws cloudformation deploy \
  --stack-name iot-security \
  --template-file $CF_DIR/security.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides VpcId=$VPC_ID \
  --region $REGION

LAMBDA_SG=$(aws cloudformation describe-stacks \
  --stack-name iot-security \
  --query "Stacks[0].Outputs[?OutputKey=='LambdaSG'].OutputValue" \
  --output text)

GATEWAY_IOT_SG=$(aws cloudformation describe-stacks \
  --stack-name iot-security \
  --query "Stacks[0].Outputs[?OutputKey=='GatewayIotSG'].OutputValue" \
  --output text)

RDS_SG=$(aws cloudformation describe-stacks \
  --stack-name iot-security \
  --query "Stacks[0].Outputs[?OutputKey=='RDSSG'].OutputValue" \
  --output text)

GRAFANA_SG=$(aws cloudformation describe-stacks \
  --stack-name iot-security \
  --query "Stacks[0].Outputs[?OutputKey=='GrafanaSG'].OutputValue" \
  --output text)

ALB_SG=$(aws cloudformation describe-stacks \
  --stack-name iot-security \
  --query "Stacks[0].Outputs[?OutputKey=='AlbSG'].OutputValue" \
  --output text)

############################################
# 3️⃣ RDS
############################################
echo "🗄 Deploy RDS..."
aws cloudformation deploy \
  --stack-name iot-rds \
  --template-file $CF_DIR/rds.yaml \
  --parameter-overrides \
    VpcId=$VPC_ID \
    PrivateDbSubnets=$PRIVATE_DB_SUBNETS \
    RDSSG=$RDS_SG \
    DBPassword=$DB_PASSWORD \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

DB_HOST=$(aws cloudformation describe-stacks \
  --stack-name iot-rds \
  --query "Stacks[0].Outputs[?OutputKey=='DBEndpoint'].OutputValue" \
  --output text)

############################################
# 4️⃣ DB INIT LAMBDA
############################################
echo "🗃 Deploy Lambda de inicialización de DB..."
aws cloudformation deploy \
  --stack-name iot-db-init \
  --template-file $CF_DIR/db-init.yaml \
  --parameter-overrides \
    DBHost=$DB_HOST \
    DBUser=iotadmin \
    DBPassword=$DB_PASSWORD \
    DBName=iotrds \
    LambdaSG=$LAMBDA_SG \
    PrivateSubnets=$PRIVATE_DB_SUBNETS \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

aws lambda invoke \
  --function-name init_sensor_db \
  /tmp/init_db_output.json

############################################
# 5️⃣ LAMBDAS
############################################
echo "🧠 Deploy Lambdas..."
aws cloudformation deploy \
  --stack-name iot-lambdas \
  --template-file $CF_DIR/lambdas.yaml \
  --parameter-overrides \
    PrivateAppSubnets=$PRIVATE_APP_SUBNETS \
    LambdaSG=$LAMBDA_SG \
    DBHost=$DB_HOST \
    DBPassword=$DB_PASSWORD \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

DECODE_LAMBDA_ARN=$(aws cloudformation describe-stacks \
  --stack-name iot-lambdas \
  --query "Stacks[0].Outputs[?OutputKey=='DecodeLambdaArn'].OutputValue" \
  --output text)

############################################
# 6️⃣ API GATEWAY
############################################
echo "🌐 Deploy API Gateway..."
aws cloudformation deploy \
  --stack-name iot-api \
  --template-file $CF_DIR/api-gateway.yaml \
  --parameter-overrides DecodeLambdaArn=$DECODE_LAMBDA_ARN \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name iot-api \
  --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
  --output text)

############################################
# 7️⃣ ECR
############################################
echo "📦 Deploy ECR Gateway..."
aws cloudformation deploy \
  --stack-name iot-ecr \
  --template-file $CF_DIR/ecr-gateway.yaml \
  --region $REGION

ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name iot-ecr \
  --query "Stacks[0].Outputs[?OutputKey=='EcrRepositoryUri'].OutputValue" \
  --output text)

echo "📦 Deploy ECR Grafana..."
aws cloudformation deploy \
  --stack-name iot-ecr-grafana \
  --template-file $CF_DIR/ecr-grafana.yaml \
  --region $REGION

GRAFANA_ECR_URI=$(aws cloudformation describe-stacks \
  --stack-name iot-ecr-grafana \
  --query "Stacks[0].Outputs[?OutputKey=='GrafanaEcrUri'].OutputValue" \
  --output text)

############################################
# 8️⃣ BUILD & PUSH IMAGES
############################################
echo "🐳 Build & Push Docker images..."
aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin ${ECR_URI%/*}

docker build -t iot-gateway -f backend/Dockerfile backend
docker tag iot-gateway:latest $ECR_URI:latest
docker push $ECR_URI:latest

docker build -t grafana -f grafana/Dockerfile grafana
docker tag grafana:latest $GRAFANA_ECR_URI:latest
docker push $GRAFANA_ECR_URI:latest

############################################
# 9️⃣ ECS CLUSTER & TASK DEFINITIONS
############################################
echo "🚢 Deploy ECS Cluster & Task Definition..."
aws cloudformation deploy \
  --stack-name iot-ecs-cluster \
  --template-file $CF_DIR/ecs-cluster.yaml \
  --parameter-overrides \
    EcrImageUri=$ECR_URI:latest \
    GrafanaEcrUri=$GRAFANA_ECR_URI:latest \
    ApiEndpoint=$API_ENDPOINT \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

CLUSTER_ARN=$(aws cloudformation describe-stacks \
  --stack-name iot-ecs-cluster \
  --query "Stacks[0].Outputs[?OutputKey=='ClusterArn'].OutputValue" \
  --output text)

GRAFANA_TASK_DEFINITION_ARN=$(aws cloudformation describe-stacks \
  --stack-name iot-ecs-cluster \
  --query "Stacks[0].Outputs[?OutputKey=='GrafanaTaskDefinitionArn'].OutputValue" \
  --output text)

GATEWAY_TASK_DEFINITION_ARN=$(aws cloudformation describe-stacks \
  --stack-name iot-ecs-cluster \
  --query "Stacks[0].Outputs[?OutputKey=='GatewayTaskDefinitionArn'].OutputValue" \
  --output text)

############################################
# 🔟 ALB + TARGET GROUP GRAFANA
############################################
echo "🛣 Deploy ALB Grafana..."
aws cloudformation deploy \
  --stack-name iot-alb-grafana \
  --template-file $CF_DIR/alb-grafana.yaml \
  --parameter-overrides \
    VpcId=$VPC_ID \
    PublicSubnets=$PUBLIC_SUBNETS \
    AlbSG=$ALB_SG \
  --region $REGION

ALB_TARGET_GROUP_ARN=$(aws cloudformation describe-stacks \
  --stack-name iot-alb-grafana \
  --query "Stacks[0].Outputs[?OutputKey=='TargetGroupArn'].OutputValue" \
  --output text)

ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name iot-alb-grafana \
  --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" \
  --output text)

if [ -z "$ALB_TARGET_GROUP_ARN" ]; then
  echo "❌ ERROR: No se pudo obtener TargetGroupArn"
  exit 1
fi

############################################
# 🔟 ECS SERVICE Gateway 
############################################
echo "🚀 Deploy ECS Service Gateway..."
aws cloudformation deploy \
  --stack-name iot-ecs-service \
  --template-file $CF_DIR/ecs-gateway-service.yaml \
  --parameter-overrides \
    ClusterArn=$CLUSTER_ARN \
    TaskDefinitionArn=$GATEWAY_TASK_DEFINITION_ARN \
    PrivateAppSubnets=$PRIVATE_APP_SUBNETS \
    GatewaySG=$GATEWAY_IOT_SG \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

############################################
# 1️⃣1️⃣ ECS SERVICE Grafana
############################################
echo "🚀 Deploy ECS Service Grafana..."
aws cloudformation deploy \
  --stack-name iot-ecs-grafana-service \
  --template-file $CF_DIR/ecs-grafana-service.yaml \
  --parameter-overrides \
    ClusterArn=$CLUSTER_ARN \
    TaskDefinitionArn=$GRAFANA_TASK_DEFINITION_ARN \
    PrivateAppSubnets=$PRIVATE_APP_SUBNETS \
    GrafanaSG=$GRAFANA_SG \
    TargetGroupArn=$ALB_TARGET_GROUP_ARN \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

############################################
# FINAL
############################################
echo "✅ DEPLOY COMPLETADO"
echo "🌍 API: $API_ENDPOINT"
echo "🗄 RDS: $DB_HOST"
echo "📊 Grafana URL: http://$ALB_DNS"
