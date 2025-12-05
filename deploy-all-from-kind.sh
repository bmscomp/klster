#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Full Stack with Local Images${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Load images into kind
echo -e "${BLUE}Step 1: Loading images from local registry into Kind cluster${NC}"
./load-images-to-kind.sh

echo ""
echo -e "${BLUE}Step 2: Deploying Monitoring Stack (Prometheus & Grafana)${NC}"
echo -e "${GREEN}Installing Prometheus and Grafana...${NC}"
helm repo remove prometheus-community 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 79.11.0 \
  --namespace monitoring \
  --create-namespace \
  --set global.imagePullPolicy=IfNotPresent \
  --set prometheus.prometheusSpec.image.registry=localhost:5001 \
  --set prometheus.prometheusSpec.image.repository=quay.io/prometheus/prometheus \
  --set prometheus.prometheusSpec.image.tag=v3.1.0 \
  --set prometheusOperator.image.registry=localhost:5001 \
  --set prometheusOperator.image.repository=quay.io/prometheus-operator/prometheus-operator \
  --set prometheusOperator.image.tag=v0.79.2 \
  --set prometheusOperator.imagePullPolicy=IfNotPresent \
  --set alertmanager.alertmanagerSpec.image.registry=localhost:5001 \
  --set alertmanager.alertmanagerSpec.image.repository=quay.io/prometheus/alertmanager \
  --set alertmanager.alertmanagerSpec.image.tag=v0.28.1 \
  --set kube-state-metrics.image.registry=localhost:5001 \
  --set kube-state-metrics.image.repository=registry.k8s.io/kube-state-metrics/kube-state-metrics \
  --set kube-state-metrics.image.tag=v2.14.0 \
  --set kube-state-metrics.imagePullPolicy=IfNotPresent \
  --set prometheus-node-exporter.image.registry=localhost:5001 \
  --set prometheus-node-exporter.image.repository=quay.io/prometheus/node-exporter \
  --set prometheus-node-exporter.image.tag=v1.8.2 \
  --set prometheus-node-exporter.imagePullPolicy=IfNotPresent \
  --set admissionWebhooks.deployment.image.registry=localhost:5001 \
  --set admissionWebhooks.deployment.image.repository=quay.io/prometheus-operator/admission-webhook \
  --set admissionWebhooks.deployment.image.tag=v0.79.2 \
  --set admissionWebhooks.patch.image.registry=localhost:5001 \
  --set admissionWebhooks.patch.image.repository=registry.k8s.io/ingress-nginx/kube-webhook-certgen \
  --set admissionWebhooks.patch.image.tag=v1.6.5 \
  --set grafana.adminPassword=admin \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30080 \
  --wait

echo -e "${GREEN}Applying custom dashboards...${NC}"
kubectl apply -f config/custom-dashboard.yaml

echo ""
echo -e "${BLUE}Step 3: Deploying Kafka (Strimzi)${NC}"
./deploy-kafka.sh

echo ""
echo -e "${BLUE}Step 4: Deploying Kafka UI${NC}"
./deploy-kafka-ui.sh

echo ""
echo -e "${BLUE}Step 5: Deploying LitmusChaos${NC}"
./deploy-litmuschaos.sh

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Full Stack Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Services deployed:"
echo "  ✓ Prometheus & Grafana (Monitoring)"
echo "  ✓ Kafka Cluster (Strimzi KRaft mode)"
echo "  ✓ Kafka UI"
echo "  ✓ LitmusChaos"
echo ""
echo "Access points:"
echo "  - Grafana: http://localhost:30080 (admin/admin)"
echo "  - Kafka UI: http://localhost:30081"
echo ""
echo "Verify deployments:"
echo "  kubectl get pods -A"
echo ""
