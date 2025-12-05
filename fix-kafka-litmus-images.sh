#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Fixing Kafka and Litmus Image Configs${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

KIND_CLUSTER_NAME="panda"

# Define images needed for Kafka and Litmus
IMAGES=(
    # Kafka Stack
    "provectuslabs/kafka-ui:latest"
    "quay.io/strimzi/operator:0.49.0"
    "quay.io/strimzi/kafka:0.49.0-kafka-4.1.1"
    "quay.io/strimzi/kafka:0.49.0-kafka-4.0.0"
    
    # LitmusChaos
    "litmuschaos/chaos-operator:3.23.0"
    "litmuschaos/chaos-runner:3.23.0"
    "litmuschaos/chaos-exporter:3.23.0"
    "litmuschaos/litmusportal-subscriber:3.23.0"
    "litmuschaos/litmusportal-event-tracker:3.23.0"
    "docker.io/bitnami/mongodb:latest"
)

echo -e "${BLUE}Step 1: Ensuring images are loaded in Kind...${NC}"

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

# Step 2: Redeploy Kafka
echo -e "${BLUE}Step 2: Redeploying Kafka (forcing imagePullPolicy: Never)...${NC}"
./deploy-kafka.sh

echo ""
echo -e "${BLUE}Restarting Kafka pods to pick up changes...${NC}"
kubectl delete pods -n kafka -l strimzi.io/cluster=krafter || true

# Step 3: Redeploy Litmus
echo -e "${BLUE}Step 3: Redeploying LitmusChaos (forcing imagePullPolicy: Never)...${NC}"
./deploy-litmuschaos.sh

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Kafka and Litmus Fixed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Verify pod status:"
echo "  kubectl get pods -n kafka"
echo "  kubectl get pods -n litmus"
echo ""
echo "Verify image pull policy:"
echo "  kubectl get deployment strimzi-cluster-operator -n kafka -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'"
echo "  kubectl get deployment chaos-operator-ce -n litmus -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'"
echo ""
