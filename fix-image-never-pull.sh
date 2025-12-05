#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Fixing ErrImageNeverPull Issues${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Load ALL required images into Kind
echo -e "${BLUE}Step 1: Loading all required images into Kind cluster${NC}"
echo ""

KIND_CLUSTER_NAME="panda"
IMAGES=(
    # Kafka Stack
    "provectuslabs/kafka-ui:latest"
    "quay.io/strimzi/operator:0.49.0"
    "quay.io/strimzi/kafka:0.49.0-kafka-4.1.1"
    "quay.io/strimzi/kafka:0.49.0-kafka-4.0.0"
    
    # Prometheus Stack
    "quay.io/prometheus/prometheus:v3.1.0"
    "quay.io/prometheus/alertmanager:v0.28.1"
    "quay.io/prometheus/node-exporter:v1.8.2"
    "quay.io/prometheus-operator/prometheus-operator:v0.79.2"
    "quay.io/prometheus-operator/prometheus-config-reloader:v0.79.2"
    "quay.io/prometheus-operator/admission-webhook:v0.79.2"
    
    # Grafana
    "docker.io/grafana/grafana:11.4.0"
    "quay.io/kiwigrid/k8s-sidecar:1.27.6"
    
    # Kube State Metrics
    "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0"
    
    # Webhook
    "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.5"
    
    # LitmusChaos
    "litmuschaos/chaos-operator:3.23.0"
    "litmuschaos/chaos-runner:3.23.0"
    "litmuschaos/chaos-exporter:3.23.0"
    "litmuschaos/litmusportal-subscriber:3.23.0"
    "litmuschaos/litmusportal-event-tracker:3.23.0"
)

for image in "${IMAGES[@]}"; do
    echo -e "${YELLOW}Checking: ${image}${NC}"
    
    # Check if image exists in Kind
    if docker exec "${KIND_CLUSTER_NAME}-control-plane" crictl images 2>/dev/null | grep -q "${image}"; then
        echo -e "  ${GREEN}✓ Already in Kind${NC}"
        continue
    fi
    
    # Check if image exists locally in Docker
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${image}$"; then
        echo -e "  ${BLUE}Pulling from remote...${NC}"
        docker pull "${image}"
    fi
    
    # Load into Kind
    echo -e "  ${BLUE}Loading into Kind...${NC}"
    kind load docker-image "${image}" --name "${KIND_CLUSTER_NAME}"
    echo -e "  ${GREEN}✓ Loaded${NC}"
done

echo ""
echo -e "${GREEN}All images loaded into Kind!${NC}"
echo ""

# Step 2: Delete and recreate Kafka pods
echo -e "${BLUE}Step 2: Restarting Kafka pods${NC}"
kubectl delete pods -n kafka -l strimzi.io/cluster=krafter || true

echo ""
echo -e "${GREEN}Waiting for Kafka pods to restart...${NC}"
sleep 5

# Step 3: Verify
echo ""
echo -e "${BLUE}Step 3: Verifying pod status${NC}"
kubectl get pods -A | grep -v "Running\|Completed" || echo -e "${GREEN}All pods are running!${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Fix Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Monitor Kafka pod status:"
echo "  kubectl get pods -n kafka -w"
echo ""
echo "Check specific pod details:"
echo "  kubectl describe pod <pod-name> -n kafka"
echo ""
