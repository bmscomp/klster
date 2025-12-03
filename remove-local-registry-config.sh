#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DOCKER_SETTINGS="$HOME/Library/Group Containers/group.com.docker/settings.json"

echo -e "${YELLOW}Reverting Docker Desktop Proxy Settings...${NC}"
echo ""

# Check if Docker Desktop settings file exists
if [ ! -f "$DOCKER_SETTINGS" ]; then
    echo -e "${RED}Error: Docker Desktop settings file not found at:${NC}"
    echo "$DOCKER_SETTINGS"
    exit 1
fi

# Backup the current settings
BACKUP_FILE="${DOCKER_SETTINGS}.backup.revert.$(date +%Y%m%d_%H%M%S)"
echo "Creating backup: $BACKUP_FILE"
cp "$DOCKER_SETTINGS" "$BACKUP_FILE"

# Default NO_PROXY (usually just hubproxy)
DEFAULT_NO_PROXY="hubproxy.docker.internal"

echo ""
echo "Restoring default proxy settings..."
echo "  - NO_PROXY: $DEFAULT_NO_PROXY"
echo ""

# Use jq to update the settings
if command -v jq >/dev/null 2>&1; then
    # Update using jq
    jq --arg noproxy "$DEFAULT_NO_PROXY" \
       '.proxies.exclude = $noproxy' \
       "$DOCKER_SETTINGS" > "${DOCKER_SETTINGS}.tmp" && \
       mv "${DOCKER_SETTINGS}.tmp" "$DOCKER_SETTINGS"
    
    echo -e "${GREEN}✓ Docker Desktop settings reverted successfully${NC}"
else
    # Fallback: use sed
    echo -e "${YELLOW}Note: jq not found, using fallback method${NC}"
    
    if grep -q '"proxies"' "$DOCKER_SETTINGS"; then
        sed -i.tmp 's/"exclude"[[:space:]]*:[[:space:]]*"[^"]*"/"exclude": "'"$DEFAULT_NO_PROXY"'"/' "$DOCKER_SETTINGS"
        rm -f "${DOCKER_SETTINGS}.tmp"
        echo -e "${GREEN}✓ Reverted NO_PROXY settings${NC}"
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
