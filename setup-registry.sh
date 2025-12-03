#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"
REGISTRY_URL="localhost:${REGISTRY_PORT}"

echo -e "${GREEN}Setting up local Docker registry...${NC}"

# Check if registry container already exists
if [ "$(docker ps -a -q -f name=${REGISTRY_NAME})" ]; then
    if [ "$(docker ps -q -f name=${REGISTRY_NAME})" ]; then
        echo -e "${YELLOW}Registry '${REGISTRY_NAME}' is already running on port ${REGISTRY_PORT}.${NC}"
    else
        echo -e "${YELLOW}Registry '${REGISTRY_NAME}' exists but is stopped. Starting it...${NC}"
        docker start ${REGISTRY_NAME}
    fi
else
    echo "Creating and starting registry container..."
    docker run -d \
      --name ${REGISTRY_NAME} \
      --restart=always \
      -p ${REGISTRY_PORT}:5000 \
      -v kind-registry-data:/var/lib/registry \
      registry:2
    echo -e "${GREEN}Registry started on port ${REGISTRY_PORT}${NC}"
fi

# Connect registry to kind network if it exists
if docker network inspect kind >/dev/null 2>&1; then
    echo "Connecting registry to kind network..."
    docker network connect kind ${REGISTRY_NAME} 2>/dev/null || true
fi

echo -e "${GREEN}Registry setup complete!${NC}"
