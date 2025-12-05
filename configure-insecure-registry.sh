#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REGISTRY="localhost:5001"
DAEMON_JSON="$HOME/.docker/daemon.json"

echo -e "${GREEN}Configuring Docker to skip certificate verification for local registry...${NC}"

# Backup existing daemon.json if it exists
if [ -f "$DAEMON_JSON" ]; then
    echo -e "${YELLOW}Backing up existing daemon.json...${NC}"
    cp "$DAEMON_JSON" "${DAEMON_JSON}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create or update daemon.json
if [ -f "$DAEMON_JSON" ]; then
    # Update existing file
    echo -e "${YELLOW}Updating existing daemon.json...${NC}"
    
    # Check if insecure-registries already exists
    if grep -q "insecure-registries" "$DAEMON_JSON"; then
        echo -e "${YELLOW}insecure-registries already configured, verifying ${REGISTRY} is included...${NC}"
        
        # Use jq to add registry if not present
        if command -v jq &> /dev/null; then
            TMP_FILE=$(mktemp)
            jq --arg registry "$REGISTRY" '.["insecure-registries"] += [$registry] | .["insecure-registries"] |= unique' "$DAEMON_JSON" > "$TMP_FILE"
            mv "$TMP_FILE" "$DAEMON_JSON"
        else
            echo -e "${RED}jq not found. Please manually add '$REGISTRY' to insecure-registries in $DAEMON_JSON${NC}"
        fi
    else
        # Add insecure-registries
        if command -v jq &> /dev/null; then
            TMP_FILE=$(mktemp)
            jq --arg registry "$REGISTRY" '. + {"insecure-registries": [$registry]}' "$DAEMON_JSON" > "$TMP_FILE"
            mv "$TMP_FILE" "$DAEMON_JSON"
        else
            echo -e "${RED}jq not found. Please manually add insecure-registries to $DAEMON_JSON${NC}"
        fi
    fi
else
    # Create new daemon.json
    echo -e "${GREEN}Creating new daemon.json...${NC}"
    mkdir -p "$(dirname "$DAEMON_JSON")"
    cat > "$DAEMON_JSON" <<EOF
{
  "insecure-registries": [
    "$REGISTRY"
  ]
}
EOF
fi

echo -e "${GREEN}✓ Docker daemon.json configured${NC}"
echo ""
cat "$DAEMON_JSON"
echo ""

echo -e "${YELLOW}⚠️  Docker needs to be restarted for changes to take effect${NC}"
echo ""
echo "Options to restart Docker:"
echo "  - macOS: Restart Docker Desktop from menu bar"
echo "  - Linux: sudo systemctl restart docker"
echo "  - Or run: ./restart-docker.sh"
echo ""
