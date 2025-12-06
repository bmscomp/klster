#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${1:-all}" # all | kafka | ui

deploy_kafka() {
  echo -e "${GREEN}Deploying Kafka Strimzi Cluster...${NC}"

  kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

  echo -e "${GREEN}Installing Strimzi Operator...${NC}"
  helm repo remove strimzi 2>/dev/null || true
  helm repo add strimzi https://strimzi.io/charts/
  if ! helm repo update strimzi; then
    echo -e "${YELLOW}Warning:${NC} Unable to update Strimzi Helm repo (network or upstream issue). Using cached charts."
  fi
  helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
    --namespace kafka \
    --set watchAnyNamespace=true \
    --wait

  echo -e "${GREEN}Applying Metrics Configuration...${NC}"
  kubectl apply -f config/kafka-metrics.yaml

  echo -e "${GREEN}Deploying Kafka Cluster (KRaft)...${NC}"
  kubectl apply -f config/kafka.yaml

  echo -e "${GREEN}Applying Kafka Dashboards...${NC}"
  kubectl apply -f config/kafka-dashboard.yaml
  kubectl apply -f config/kafka-performance-dashboard.yaml
  kubectl apply -f config/kafka-jvm-dashboard.yaml
  kubectl apply -f config/kafka-perf-test-dashboard.yaml
  kubectl apply -f config/kafka-working-dashboard.yaml
  kubectl apply -f config/kafka-comprehensive-dashboard.yaml
  kubectl apply -f config/kafka-all-metrics-dashboard.yaml

  echo -e "${GREEN}Cleaning up stale Strimzi resources...${NC}"
  kubectl delete kafkanodepool dual-role -n kafka --ignore-not-found
  kubectl delete pvc -l strimzi.io/cluster=krafter -n kafka --ignore-not-found

  echo -e "${GREEN}Waiting for Kafka cluster to be Ready...${NC}"
  kubectl wait kafka/krafter --for=condition=Ready --timeout=300s -n kafka

  echo -e "${GREEN}Kafka deployment complete!${NC}"
}

deploy_kafka_ui() {
  echo -e "${GREEN}Deploying Kafka UI...${NC}"
  kubectl apply -f config/kafka-ui.yaml

  echo -e "${GREEN}Waiting for Kafka UI to be ready...${NC}"
  kubectl wait --for=condition=available --timeout=120s deployment/kafka-ui -n kafka

  echo -e "${GREEN}Kafka UI deployment complete!${NC}"
  echo "Setting up port-forwarding (required for Kind on macOS)..."
  pkill -f "port-forward.*kafka-ui" 2>/dev/null || true
  kubectl port-forward -n kafka svc/kafka-ui 30081:8080 > /dev/null 2>&1 &
  sleep 2
  echo "Kafka UI available at http://localhost:30081"
}

case "${MODE}" in
  kafka)
    deploy_kafka
    ;;
  ui)
    deploy_kafka_ui
    ;;
  all)
    deploy_kafka
    deploy_kafka_ui
    ;;
  *)
    echo "Usage: $0 [all|kafka|ui]"
    exit 1
    ;;
esac
