#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

KIND_CLUSTER_NAME="panda"
PLATFORM="linux/amd64"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Clean Redeploy of LitmusChaos${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. Uninstall and Clean Namespace
echo -e "${BLUE}Step 1: Cleaning up existing deployment...${NC}"
helm uninstall chaos -n litmus 2>/dev/null || true
echo "Waiting for namespace deletion (this may take a moment)..."
kubectl delete namespace litmus --ignore-not-found=true
echo "Waiting for namespace to verify it's gone..."
while kubectl get namespace litmus >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# 2. Define Images (Full paths to verify)
# Scarf for portal, Bitnami for Mongo, Standard for Core
OS_SHELL_IMG="docker.io/bitnamilegacy/os-shell:12-debian-12-r51"
MONGO_IMG="docker.io/bitnami/mongodb:latest"
AUTH_IMG="litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-auth-server:3.23.0"
FRONTEND_IMG="litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-frontend:3.23.0"
SERVER_IMG="litmuschaos.docker.scarf.sh/litmuschaos/litmusportal-server:3.23.0"
OPERATOR_IMG="litmuschaos/chaos-operator:3.23.0"
RUNNER_IMG="litmuschaos/chaos-runner:3.23.0"
EXPORTER_IMG="litmuschaos/chaos-exporter:3.23.0"

IMAGES=(
    "$OS_SHELL_IMG"
    "$MONGO_IMG"
    "$AUTH_IMG"
    "$FRONTEND_IMG"
    "$SERVER_IMG"
    "$OPERATOR_IMG"
    "$RUNNER_IMG"
    "$EXPORTER_IMG"
)

# 3. Clean and Reload Images
echo -e "${BLUE}Step 2: Refreshing Images (Platform: $PLATFORM)...${NC}"
for image in "${IMAGES[@]}"; do
    echo -e "${YELLOW}Processing: $image${NC}"
    
    # Remove local copy to force fresh pull
    docker rmi -f "$image" 2>/dev/null || true
    
    # Pull with platform flag to avoid corruption
    echo "  Pulling for $PLATFORM..."
    if docker pull --platform "$PLATFORM" "$image"; then
        echo -e "  ${GREEN}✓ Pulled${NC}"
        
        # Load into Kind
        echo "  Loading into Kind..."
        if kind load docker-image "$image" --name "${KIND_CLUSTER_NAME}"; then
            echo -e "  ${GREEN}✓ Loaded${NC}"
        else
            echo -e "  ${RED}✗ Failed to load${NC}"
            # Don't exit on load failure, might be benign if image exists
        fi
    else
        echo -e "  ${RED}✗ Failed to pull (trying without platform flag)...${NC}"
        # Fallback for local testing if cross-platform pull fails
        docker pull "$image"
    fi
    echo ""
done

# 4. Deploy
echo -e "${BLUE}Step 3: Deploying LitmusChaos...${NC}"
./deploy-litmuschaos.sh

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Redeploy Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Monitor pods with:"
echo "  kubectl get pods -n litmus -w"
