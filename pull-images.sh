#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REGISTRY="localhost:5001"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-panda}"

KIND_PRESENT=false
KIND_NODES=()
KIND_MISSING_NODES=()
IMAGE_REPO=""
IMAGE_TAG=""
if kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER_NAME}"; then
    KIND_PRESENT=true
    echo -e "${GREEN}Kind cluster '${KIND_CLUSTER_NAME}' detected. Images will also be loaded into the cluster.${NC}"
    # Populate KIND_NODES array from kind get nodes output
    while IFS= read -r node; do
        [[ -n "$node" ]] && KIND_NODES+=("$node")
    done < <(kind get nodes --name "${KIND_CLUSTER_NAME}" 2>/dev/null)
    if [[ ${#KIND_NODES[@]} -gt 0 ]]; then
        echo "Kind nodes: ${KIND_NODES[*]}"
    else
        echo -e "${YELLOW}Warning:${NC} Unable to list Kind nodes for verification."
    fi
else
    echo -e "${YELLOW}Kind cluster '${KIND_CLUSTER_NAME}' not found. Images will NOT be auto-loaded into Kind.${NC}"
fi

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

# Retry wrapper for docker pull with exponential backoff
pull_with_retry() {
    local image="$1"
    local max_attempts=3
    local attempt=1
    local wait_time=5

    while [[ $attempt -le $max_attempts ]]; do
        if docker pull "$image"; then
            return 0
        fi
        if [[ $attempt -lt $max_attempts ]]; then
            echo -e "${YELLOW}  Pull attempt $attempt failed. Retrying in ${wait_time}s...${NC}"
            sleep $wait_time
            wait_time=$((wait_time * 2))
        fi
        ((attempt++))
    done
    return 1
}

# Function to pull, tag, and push image
push_to_local_registry() {
    local image=$1
    local local_image="${REGISTRY}/${image}"
    
    echo "Processing $image..."

    # Skip entirely if image already verified in Kind
    if ${KIND_PRESENT} && image_present_in_kind "$local_image"; then
        if verify_image_in_kind "$local_image"; then
            echo -e "${GREEN}✓ $image already in Kind. Skipping.${NC}"
            return
        fi
    fi

    # Check if image exists in local Docker cache
    if docker image inspect "$local_image" >/dev/null 2>&1; then
        echo -e "${GREEN}  Image found in local Docker cache.${NC}"
    # Check if image exists in local registry
    elif docker pull "$local_image" >/dev/null 2>&1; then
        echo -e "${GREEN}  Image found in local registry.${NC}"
    else
        # Pull from remote as last resort
        if ! pull_with_retry "$image"; then
            echo -e "${RED}✗ Failed to pull $image after retries${NC}"
            exit 1
        fi
        docker tag "$image" "$local_image"
        # Push to local registry only for newly pulled images
        if ! docker push "$local_image"; then
            echo -e "${RED}✗ Failed to push $local_image to local registry${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}✓ $image ready${NC}"

    if ${KIND_PRESENT}; then
        if image_present_in_kind "$local_image"; then
            if verify_image_in_kind "$local_image"; then
                echo -e "${GREEN}  ✓ Image already present across Kind nodes. Skipping reload.${NC}"
            else
                echo -e "${YELLOW}  Verification failed. Removing and reloading image...${NC}"
                remove_image_from_kind "$local_image"
                load_and_verify_image "$local_image"
            fi
        else
            load_and_verify_image "$local_image"
        fi
    fi
}

remove_image_from_kind() {
    local image="$1"
    normalize_image_ref "$image"
    for node in "${KIND_NODES[@]}"; do
        docker exec "$node" crictl rmi "${IMAGE_REPO}:${IMAGE_TAG}" >/dev/null 2>&1 || true
    done
}

load_and_verify_image() {
    local image="$1"
    echo "Loading ${image} into Kind (${KIND_CLUSTER_NAME})..."
    if kind load docker-image "$image" --name "${KIND_CLUSTER_NAME}"; then
        if ! verify_image_in_kind "$image"; then
            echo -e "${RED}  ✗ Verification still failed after reload for ${image}${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}  ⚠️  Failed to load ${image} into Kind${NC}"
    fi
}

normalize_image_ref() {
    local image="$1"
    IMAGE_REPO="${image%:*}"
    IMAGE_TAG="${image##*:}"

    if [[ "$IMAGE_REPO" == "$IMAGE_TAG" ]]; then
        IMAGE_REPO="$image"
        IMAGE_TAG="latest"
    fi
}

gather_missing_kind_nodes() {
    local image="$1"
    KIND_MISSING_NODES=()

    if [[ ${#KIND_NODES[@]} -eq 0 ]]; then
        return 1
    fi

    normalize_image_ref "$image"

    for node in "${KIND_NODES[@]}"; do
        if ! docker exec "$node" crictl inspecti "${IMAGE_REPO}:${IMAGE_TAG}" >/dev/null 2>&1; then
            KIND_MISSING_NODES+=("$node")
        fi
    done

    return 0
}

image_present_in_kind() {
    if ! gather_missing_kind_nodes "$1"; then
        return 1
    fi

    [[ ${#KIND_MISSING_NODES[@]} -eq 0 ]]
}

verify_image_in_kind() {
    local image="$1"

    if ! gather_missing_kind_nodes "$image"; then
        echo -e "${YELLOW}  ⚠️ Unable to verify ${image} in Kind nodes (node list empty).${NC}"
        return 1
    fi

    if [[ ${#KIND_MISSING_NODES[@]} -eq 0 ]]; then
        echo -e "${GREEN}  ✓ Loaded and verified on Kind nodes: ${KIND_NODES[*]}${NC}"
        return 0
    fi

    echo -e "${YELLOW}  ⚠️ Loaded but missing on nodes: ${KIND_MISSING_NODES[*]}. Consider rerunning kind load for ${image}.${NC}"
    return 1
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
