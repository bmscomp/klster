#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-panda}"
PLATFORM="linux/amd64"
ARCH="$(uname -m)"
USE_PLATFORM_PULL=false

if [[ "${ARCH}" == "arm64" ]]; then
  USE_PLATFORM_PULL=true
  echo -e "${GREEN}Apple Silicon detected. Pulling Litmus images for ${PLATFORM}.${NC}"
fi

echo -e "${GREEN}Loading LitmusChaos images into Kind cluster '${KIND_CLUSTER_NAME}'...${NC}"

# Ensure cluster exists
if ! kind get clusters | grep -qx "${KIND_CLUSTER_NAME}"; then
  echo -e "${RED}Kind cluster '${KIND_CLUSTER_NAME}' not found. Please run ./launch.sh first.${NC}"
  exit 1
fi

IMAGES=(
  "litmuschaos/chaos-operator:3.23.0"
  "litmuschaos/chaos-runner:3.23.0"
  "litmuschaos/chaos-exporter:3.23.0"
  "litmuschaos/litmusportal-subscriber:3.23.0"
  "litmuschaos/litmusportal-event-tracker:3.23.0"
  "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-auth-server:3.23.0"
  "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-frontend:3.23.0"
  "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-server:3.23.0"
  "litmuschaos.docker.scarf.sh/litmuschaos/mongo:6"
  "docker.io/bitnami/mongodb:latest"
  "docker.io/bitnamilegacy/os-shell:12-debian-12-r51"
)

image_exists_in_kind() {
  docker exec "${KIND_CLUSTER_NAME}-control-plane" crictl images 2>/dev/null | grep -q "$1"
}

pull_image() {
  local image="$1"
  if ${USE_PLATFORM_PULL}; then
    if docker pull --platform "${PLATFORM}" "${image}"; then
      return 0
    fi
    echo -e "${YELLOW}Platform-specific pull failed for ${image}. Retrying without --platform...${NC}"
  fi
  docker pull "${image}"
}

for image in "${IMAGES[@]}"; do
  echo -e "${BLUE}Processing: ${image}${NC}"

  if image_exists_in_kind "${image}"; then
    echo -e "  ${YELLOW}Image already present in Kind. Skipping load.${NC}"
    continue
  fi

  if ! docker image inspect "${image}" >/dev/null 2>&1; then
    echo "  Pulling image..."
    pull_image "${image}"
  else
    echo "  Image already present locally."
  }

  echo "  Loading into Kind..."
  if kind load docker-image "${image}" --name "${KIND_CLUSTER_NAME}"; then
    echo -e "  ${GREEN}✓ Loaded${NC}"
  else
    echo -e "  ${RED}✗ Failed to load ${image}${NC}"
    exit 1
  fi
done

echo ""
echo -e "${GREEN}All LitmusChaos images are now available inside Kind cluster '${KIND_CLUSTER_NAME}'.${NC}"
