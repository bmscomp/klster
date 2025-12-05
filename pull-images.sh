#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REGISTRY="localhost:5001"

# Temporarily unset proxy for Docker operations to avoid timeout issues
# This ensures direct connection to Docker registries
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy

echo -e "${GREEN}Pulling and pushing images to local registry...${NC}"

# Check if registry is running
if ! curl -s http://localhost:5001/v2/ >/dev/null; then
    echo -e "${RED}Error: Local registry is not reachable at localhost:5001${NC}"
    echo "Please run ./setup-registry.sh first"
    exit 1
fi

# Function to pull, tag, and push image
push_to_local_registry() {
    local image=$1
    local local_image="${REGISTRY}/${image}"
    
    echo "Processing $image..."
    
    # Check if image already exists in local registry to save time
    # Extract repo and tag
    # This is a simple check, usually we just pull/push to be safe/up-to-date
    
    docker pull "$image"
    docker tag "$image" "$local_image"
    docker push "$local_image"
    echo -e "${GREEN}✓ Pushed $image${NC}"
}

# List of images to cache
# Kafka UI
push_to_local_registry "provectuslabs/kafka-ui:latest"

# Strimzi Operator
push_to_local_registry "quay.io/strimzi/operator:0.49.0"

# Strimzi Kafka Images
push_to_local_registry "quay.io/strimzi/kafka:0.49.0-kafka-4.1.1"
push_to_local_registry "quay.io/strimzi/kafka:0.49.0-kafka-4.0.0"

# Prometheus Stack Images
push_to_local_registry "quay.io/prometheus/prometheus:v3.1.0"
push_to_local_registry "quay.io/prometheus/alertmanager:v0.28.1"
push_to_local_registry "quay.io/prometheus/node-exporter:v1.8.2"
push_to_local_registry "quay.io/prometheus-operator/prometheus-operator:v0.79.2"
push_to_local_registry "quay.io/prometheus-operator/prometheus-config-reloader:v0.79.2"
push_to_local_registry "docker.io/grafana/grafana:11.4.0"
push_to_local_registry "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0"

# Admission webhook
push_to_local_registry "quay.io/prometheus-operator/admission-webhook:v0.79.2"

# LitmusChaos Core
push_to_local_registry "litmuschaos/chaos-operator:3.23.0"
push_to_local_registry "litmuschaos/chaos-runner:3.23.0"
push_to_local_registry "litmuschaos/chaos-exporter:3.23.0"
push_to_local_registry "litmuschaos/litmusportal-subscriber:3.23.0"
push_to_local_registry "litmuschaos/litmusportal-event-tracker:3.23.0"

# LitmusChaos Portal (scarf registry)
push_to_local_registry "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-auth-server:3.23.0"
push_to_local_registry "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-frontend:3.23.0"
push_to_local_registry "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-server:3.23.0"
push_to_local_registry "litmuschaos.docker.scarf.sh/litmuschaos/mongo:6"

# Litmus dependencies
push_to_local_registry "docker.io/bitnami/mongodb:latest"
push_to_local_registry "docker.io/bitnamilegacy/os-shell:12-debian-12-r51"

echo ""
echo -e "${GREEN}All images have been pushed to local registry!${NC}"
echo ""
echo "To view all images in the registry:"
echo "  curl -s http://localhost:5001/v2/_catalog | jq"
