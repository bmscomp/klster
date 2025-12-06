#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-panda}"

echo -e "${GREEN}Loading Argo Workflows images into Kind cluster '${KIND_CLUSTER_NAME}'...${NC}"

# Argo Workflows images
ARGO_IMAGES=(
  "quay.io/argoproj/workflow-controller:v3.5.5"
  "quay.io/argoproj/argocli:v3.5.5"
  "quay.io/argoproj/argoexec:v3.5.5"
)

for image in "${ARGO_IMAGES[@]}"; do
  echo "Processing: $image"
  
  # Check if image exists locally
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "  Pulling $image..."
    docker pull --platform linux/amd64 "$image"
  else
    echo "  Image already present locally."
  fi
  
  # Load into Kind
  echo "  Loading into Kind..."
  kind load docker-image "$image" --name "${KIND_CLUSTER_NAME}"
  echo "  ✓ Loaded"
done

echo ""
echo -e "${GREEN}All Argo Workflows images are now available inside Kind cluster '${KIND_CLUSTER_NAME}'.${NC}"
