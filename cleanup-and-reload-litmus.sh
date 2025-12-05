#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Comprehensive Image Cleanup and Fix${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}Step 1: Cleaning up all local Docker images${NC}"
docker image prune -a -f

echo ""
echo -e "${BLUE}Step 2: Pulling fresh copies of LitmusChaos images${NC}"

# Core LitmusChaos images (from Docker Hub)
docker pull litmuschaos/chaos-operator:3.23.0
docker pull litmuschaos/chaos-runner:3.23.0
docker pull litmuschaos/chaos-exporter:3.23.0

# Portal images (from scarf.sh)
docker pull litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-auth-server:3.23.0
docker pull litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-frontend:3.23.0
docker pull litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-server:3.23.0
docker pull litmuschaos.docker.scarf.sh/litmuschaos/mongo:6

# MongoDB dependency
docker pull docker.io/bitnamilegacy/os-shell:12-debian-12-r51

echo ""
echo -e "${BLUE}Step 3: Loading into Kind (with retry)${NC}"

KIND_CLUSTER_NAME="panda"
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
    echo -e "${YELLOW}Loading: ${image}${NC}"
    
    # Try loading with retries
    for attempt in 1 2 3; do
        if kind load docker-image "${image}" --name "${KIND_CLUSTER_NAME}" 2>&1; then
            echo -e "  ${GREEN}✓ Loaded${NC}"
            break
        else
            if [ $attempt -lt 3 ]; then
                echo -e "  ${YELLOW}Attempt $attempt failed, retrying after cleanup...${NC}"
                # Remove from Docker and re-pull
                docker rmi -f "${image}" 2>/dev/null || true
                docker pull "${image}"
                sleep 2
            else
                echo -e "  ${RED}✗ Failed after 3 attempts${NC}"
            fi
        fi
    done
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Cleanup and Reload Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Now redeploy LitmusChaos:"
echo "  ./deploy-litmuschaos.sh"
echo ""
