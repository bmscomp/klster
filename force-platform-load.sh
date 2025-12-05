#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Force Platform-Specific Image Load${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

KIND_CLUSTER_NAME="panda"
PLATFORM="linux/amd64"  # Explicit platform to avoid multi-arch corruption

# LitmusChaos images that need platform-specific pull
IMAGES=(
    "litmuschaos/chaos-operator:3.23.0"
    "litmuschaos/chaos-runner:3.23.0"
    "litmuschaos/chaos-exporter:3.23.0"
    "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-auth-server:3.23.0"
    "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-frontend:3.23.0"
    "litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-server:3.23.0"
    "litmuschaos.docker.scarf.sh/litmuschaos/mongo:6"
    "docker.io/bitnamilegacy/os-shell:12-debian-12-r51"
)

for image in "${IMAGES[@]}"; do
    echo -e "${YELLOW}Processing: ${image}${NC}"
    
    # Force remove from Docker
    docker rmi -f "${image}" 2>/dev/null || true
    
    # Pull with explicit platform
    echo "  Pulling for platform: ${PLATFORM}..."
    if docker pull --platform "${PLATFORM}" "${image}"; then
        echo -e "  ${GREEN}✓ Pulled${NC}"
    else
        echo -e "  ${RED}✗ Failed to pull, skipping${NC}"
        continue
    fi
    
    # Simple load without retry - if it fails, we'll see the error
    echo "  Loading into Kind..."
    if kind load docker-image "${image}" --name "${KIND_CLUSTER_NAME}"; then
        echo -e "  ${GREEN}✓ Loaded${NC}"
    else
        echo -e "  ${RED}✗ Load failed - digest corruption${NC}"
    fi
    
    echo ""
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Platform-Specific Load Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "If you still see digest errors, the issue is with containerd in Kind."
echo "You may need to recreate the Kind cluster:"
echo "  kind delete cluster --name panda"
echo "  ./launch.sh"
echo ""
