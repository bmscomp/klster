#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOCKER_SETTINGS="$HOME/Library/Group Containers/group.com.docker/settings.json"

echo -e "${YELLOW}Fixing Docker Internet Access...${NC}"
echo ""
echo "The current Docker proxy configuration is blocking access to public registries."
echo "We need to bypass the proxy for Docker Hub and other registries."

# Check if Docker Desktop settings file exists
if [ ! -f "$DOCKER_SETTINGS" ]; then
    echo -e "${RED}Error: Docker Desktop settings file not found at:${NC}"
    echo "$DOCKER_SETTINGS"
    exit 1
fi

# Backup the current settings
BACKUP_FILE="${DOCKER_SETTINGS}.backup.fix.$(date +%Y%m%d_%H%M%S)"
echo "Creating backup: $BACKUP_FILE"
cp "$DOCKER_SETTINGS" "$BACKUP_FILE"

# NO_PROXY entries for public registries (excluding local registry specific entries if desired, but localhost is safe)
# We MUST include docker.io etc to bypass the broken proxy
NO_PROXY_ENTRIES="localhost,127.0.0.1,docker.io,*.docker.io,quay.io,*.quay.io,gcr.io,*.gcr.io,registry.k8s.io,*.registry.k8s.io,hubproxy.docker.internal"

echo ""
echo "Updating proxy settings..."
echo "  - NO_PROXY: $NO_PROXY_ENTRIES"
echo ""

# Use jq to update the settings
if command -v jq >/dev/null 2>&1; then
    # Update using jq
    jq --arg noproxy "$NO_PROXY_ENTRIES" \
       '.proxies.exclude = $noproxy' \
       "$DOCKER_SETTINGS" > "${DOCKER_SETTINGS}.tmp" && \
       mv "${DOCKER_SETTINGS}.tmp" "$DOCKER_SETTINGS"
    
    echo -e "${GREEN}✓ Docker Desktop settings updated successfully${NC}"
else
    # Fallback: use sed
    echo -e "${YELLOW}Note: jq not found, using fallback method${NC}"
    
    if grep -q '"proxies"' "$DOCKER_SETTINGS"; then
        sed -i.tmp 's/"exclude"[[:space:]]*:[[:space:]]*"[^"]*"/"exclude": "'"$NO_PROXY_ENTRIES"'"/' "$DOCKER_SETTINGS"
        rm -f "${DOCKER_SETTINGS}.tmp"
        echo -e "${GREEN}✓ Updated NO_PROXY settings${NC}"
    else
        echo -e "${RED}Error: Could not update settings automatically${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${YELLOW}Restarting Docker Desktop to apply changes...${NC}"

# Restart Docker Desktop
osascript -e 'quit app "Docker"' 2>/dev/null || true
sleep 5
open -a Docker

echo "Waiting for Docker to restart..."
echo "Please wait for the Docker whale icon to stop animating."
