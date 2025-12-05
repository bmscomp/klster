#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

KIND_CLUSTER_NAME="panda"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Full Cluster Rebuild and Redeploy${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}This will:${NC}"
echo "  1. Delete existing Kind cluster '${KIND_CLUSTER_NAME}'"
echo "  2. Create fresh Kind cluster"
echo "  3. Load all Docker images (~5-10 minutes)"
echo "  4. Deploy full stack (Monitoring, Kafka, Kafka UI, LitmusChaos)"
echo ""
echo -e "${RED}Warning: All data in the cluster will be lost!${NC}"
echo ""
read -p "Continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Delete existing cluster
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 1/4: Deleting existing cluster${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
    echo "Deleting cluster '${KIND_CLUSTER_NAME}'..."
    kind delete cluster --name "${KIND_CLUSTER_NAME}"
    echo -e "${GREEN}✓ Cluster deleted${NC}"
else
    echo -e "${YELLOW}Cluster '${KIND_CLUSTER_NAME}' not found, skipping deletion${NC}"
fi

echo ""

# Step 2: Create fresh cluster
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 2/4: Creating fresh Kind cluster${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -x "./launch.sh" ]; then
    ./launch.sh
    echo -e "${GREEN}✓ Cluster created${NC}"
else
    echo -e "${RED}Error: launch.sh not found or not executable${NC}"
    exit 1
fi

echo ""

# Step 3: Load all images
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 3/4: Loading all Docker images${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}This step takes 5-10 minutes...${NC}"
echo ""

if [ -x "./load-images-to-kind.sh" ]; then
    ./load-images-to-kind.sh
    echo -e "${GREEN}✓ All images loaded${NC}"
else
    echo -e "${RED}Error: load-images-to-kind.sh not found or not executable${NC}"
    exit 1
fi

echo ""

# Step 4: Deploy everything
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 4/4: Deploying full stack${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ -x "./deploy-all-from-kind.sh" ]; then
    ./deploy-all-from-kind.sh
    echo -e "${GREEN}✓ Full stack deployed${NC}"
else
    echo -e "${RED}Error: deploy-all-from-kind.sh not found or not executable${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Rebuild Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your fresh cluster is ready with:"
echo "  ✓ Prometheus & Grafana (Monitoring)"
echo "  ✓ Kafka Cluster (Strimzi KRaft mode)"
echo "  ✓ Kafka UI"
echo "  ✓ LitmusChaos"
echo ""
echo "Access points:"
echo "  - Grafana: http://localhost:30080 (admin/admin)"
echo "  - Kafka UI: http://localhost:30081"
echo ""
echo "Verify all pods:"
echo "  kubectl get pods -A"
echo ""
echo "Check images in Kind:"
echo "  docker exec ${KIND_CLUSTER_NAME}-control-plane crictl images | wc -l"
echo ""
