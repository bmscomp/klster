#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

KIND_CLUSTER_NAME="panda"

# Temporarily unset proxy for Docker operations to avoid timeout issues
# This ensures direct connection to Docker registries
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

echo -e "${GREEN}Loading images into Kind cluster '${KIND_CLUSTER_NAME}'...${NC}"

# Check if kind cluster exists
if ! kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
    echo -e "${RED}Error: Kind cluster '${KIND_CLUSTER_NAME}' not found${NC}"
    echo "Please run ./launch.sh first to create the cluster"
    exit 1
fi

# Function to pull and load image into kind
load_image_to_kind() {
    local image=$1
    
    echo -e "${YELLOW}Processing $image...${NC}"
    
    # Pull the image from remote registry
    echo "  Pulling from remote registry..."
    docker pull "$image"
    
    # Load into kind cluster
    echo "  Loading into kind cluster..."
    kind load docker-image "$image" --name "${KIND_CLUSTER_NAME}"
    
    echo -e "${GREEN}✓ Loaded $image${NC}"
}

echo ""
echo -e "${GREEN}=== Kafka UI Images ===${NC}"
load_image_to_kind "provectuslabs/kafka-ui:latest"

echo ""
echo -e "${GREEN}=== Strimzi Operator Images ===${NC}"
load_image_to_kind "quay.io/strimzi/operator:0.49.0"

echo ""
echo -e "${GREEN}=== Strimzi Kafka Images ===${NC}"
load_image_to_kind "quay.io/strimzi/kafka:0.49.0-kafka-4.1.1"
load_image_to_kind "quay.io/strimzi/kafka:0.49.0-kafka-4.0.0"

echo ""
echo -e "${GREEN}=== Prometheus Stack Images ===${NC}"
load_image_to_kind "quay.io/prometheus/prometheus:v3.1.0"
load_image_to_kind "quay.io/prometheus/alertmanager:v0.28.1"
load_image_to_kind "quay.io/prometheus/node-exporter:v1.8.2"
load_image_to_kind "quay.io/prometheus-operator/prometheus-operator:v0.79.2"
load_image_to_kind "quay.io/prometheus-operator/prometheus-config-reloader:v0.79.2"
load_image_to_kind "quay.io/prometheus-operator/admission-webhook:v0.79.2"

echo ""
echo -e "${GREEN}=== Grafana Images ===${NC}"
load_image_to_kind "docker.io/grafana/grafana:11.4.0"

echo ""
echo -e "${GREEN}=== Kube State Metrics Images ===${NC}"
load_image_to_kind "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0"

echo ""
echo -e "${GREEN}=== LitmusChaos Images ===${NC}"
load_image_to_kind "litmuschaos/chaos-operator:3.23.0"
load_image_to_kind "litmuschaos/chaos-runner:3.23.0"
load_image_to_kind "litmuschaos/chaos-exporter:3.23.0"

echo ""
echo -e "${GREEN}=== MongoDB Images ===${NC}"
load_image_to_kind "docker.io/bitnami/mongodb:latest"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All images have been loaded into Kind cluster '${KIND_CLUSTER_NAME}'!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "To verify images loaded in kind nodes, you can exec into a node:"
echo "  docker exec -it ${KIND_CLUSTER_NAME}-control-plane crictl images"
echo ""
