#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing Argo Workflows CLI...${NC}"
echo ""

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture names
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${YELLOW}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

VERSION="v3.5.5"
BINARY_NAME="argo-${OS}-${ARCH}"
DOWNLOAD_URL="https://github.com/argoproj/argo-workflows/releases/download/${VERSION}/${BINARY_NAME}.gz"

echo -e "${BLUE}Detected: ${OS}/${ARCH}${NC}"
echo -e "${BLUE}Version: ${VERSION}${NC}"
echo ""

# Download
echo -e "${GREEN}Downloading Argo CLI...${NC}"
curl -sLO "$DOWNLOAD_URL"

# Extract
echo -e "${GREEN}Extracting...${NC}"
gunzip "${BINARY_NAME}.gz"

# Make executable
chmod +x "$BINARY_NAME"

# Move to /usr/local/bin
echo -e "${GREEN}Installing to /usr/local/bin/argo...${NC}"
sudo mv "$BINARY_NAME" /usr/local/bin/argo

# Verify installation
echo ""
echo -e "${GREEN}✓ Argo CLI installed successfully!${NC}"
echo ""
argo version

echo ""
echo -e "${BLUE}Usage:${NC}"
echo "  argo submit <workflow.yaml>"
echo "  argo list"
echo "  argo get <workflow-name>"
echo "  argo logs <workflow-name>"
echo ""
