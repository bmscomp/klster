#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Local Docker Registry Status ===${NC}"
echo ""

# Check if registry container is running
if [ "$(docker ps -q -f name=kind-registry)" ]; then
    echo -e "${GREEN}✓ Registry is running${NC}"
    echo "  Container: kind-registry"
    echo "  URL: http://localhost:5001"
    
    # Check connectivity
    if curl -s http://localhost:5001/v2/ >/dev/null; then
        echo ""
        echo -e "${GREEN}✓ Registry is accessible${NC}"
        
        echo ""
        echo "=== Registry Contents ==="
        
        # Get list of repositories
        REPOS=$(curl -s http://localhost:5001/v2/_catalog | jq -r '.repositories[]' 2>/dev/null)
        
        if [ -z "$REPOS" ]; then
            # Fallback if jq is not installed
            RAW_REPOS=$(curl -s http://localhost:5001/v2/_catalog)
            echo "Raw output: $RAW_REPOS"
        else
            COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')
            echo "Total images: $COUNT"
            echo ""
            echo "Images in registry:"
            
            for repo in $REPOS; do
                TAGS=$(curl -s http://localhost:5001/v2/${repo}/tags/list | jq -r '.tags[]' 2>/dev/null)
                for tag in $TAGS; do
                    echo "  - ${repo}:${tag}"
                done
            done
        fi
    else
        echo -e "${RED}✗ Registry is running but not accessible at localhost:5001${NC}"
    fi
else
    echo -e "${RED}✗ Registry container is NOT running${NC}"
    echo "Run 'make registry-setup' to start it."
fi
