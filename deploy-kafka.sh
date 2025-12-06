#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MODE="${1:-all}" # all | kafka | ui
FORCE_STRIMZI_REDEPLOY="${FORCE_STRIMZI_REDEPLOY:-false}"
FORCE_KAFKA_REDEPLOY="${FORCE_KAFKA_REDEPLOY:-false}"

helm_repo_exists() {
  helm repo list | awk '{print $1}' | grep -qx "$1"
}

ensure_strimzi_repo() {
  if ! helm_repo_exists "strimzi"; then
    helm repo add strimzi https://strimzi.io/charts/
  fi
  if [[ "${SKIP_STRIMZI_REPO_UPDATE:-false}" != "true" ]]; then
    if ! helm repo update strimzi >/dev/null; then
      echo -e "${YELLOW}Warning:${NC} Unable to update Strimzi Helm repo (offline?). Using cached charts."
    fi
  else
    echo -e "${YELLOW}Skipping strimzi repo update (SKIP_STRIMZI_REPO_UPDATE=true).${NC}"
  fi
}

strimzi_release_exists() {
  helm status strimzi-kafka-operator -n kafka >/dev/null 2>&1
}

install_strimzi_operator() {
  if strimzi_release_exists && [[ "${FORCE_STRIMZI_REDEPLOY}" != "true" ]]; then
    echo -e "${GREEN}Strimzi operator already installed. Skipping Helm upgrade (set FORCE_STRIMZI_REDEPLOY=true to force).${NC}"
    return
  fi

  ensure_strimzi_repo

  echo -e "${GREEN}Installing/Upgrading Strimzi Operator...${NC}"
  helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
    --namespace kafka \
    --set watchAnyNamespace=true \
    --wait
}

kafka_ready() {
  kubectl get kafka krafter -n kafka -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -qx "True"
}

deploy_kafka() {
  echo -e "${GREEN}Deploying Kafka Strimzi Cluster...${NC}"

  kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

  install_strimzi_operator

  echo -e "${GREEN}Applying Metrics Configuration...${NC}"
  kubectl apply -f config/kafka-metrics.yaml

  if kafka_ready && [[ "${FORCE_KAFKA_REDEPLOY}" != "true" ]]; then
    echo -e "${GREEN}Kafka cluster 'krafter' already Ready. Skipping redeploy (set FORCE_KAFKA_REDEPLOY=true to force).${NC}"
  else
    echo -e "${GREEN}Deploying Kafka Cluster (KRaft)...${NC}"
    kubectl apply -f config/kafka.yaml

    echo -e "${GREEN}Cleaning up stale Strimzi resources...${NC}"
    kubectl delete kafkanodepool dual-role -n kafka --ignore-not-found
    kubectl delete pvc -l strimzi.io/cluster=krafter -n kafka --ignore-not-found

    echo -e "${GREEN}Waiting for Kafka cluster to be Ready...${NC}"
    kubectl wait kafka/krafter --for=condition=Ready --timeout=300s -n kafka
  fi

  echo -e "${GREEN}Applying Kafka Dashboard...${NC}"
  kubectl apply -f config/kafka-dashboard-merged.yaml

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
