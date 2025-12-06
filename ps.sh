#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get terminal width
TERM_WIDTH=$(tput cols 2>/dev/null || echo 120)

echo -e "${GREEN}=== Kubernetes Cluster Status ===${NC}"
echo ""

# Calculate column widths for nodes table (40% / 60% split)
NODE_COL_WIDTH=$((TERM_WIDTH * 40 / 100 - 3))
STATUS_COL_WIDTH=$((TERM_WIDTH * 60 / 100 - 3))

# Build top border
TOP_BORDER="${CYAN}┌$(printf '%*s' $((NODE_COL_WIDTH + 2)) '' | tr ' ' '─')┬$(printf '%*s' $((STATUS_COL_WIDTH + 2)) '' | tr ' ' '─')┐${NC}"
MID_BORDER="${CYAN}├$(printf '%*s' $((NODE_COL_WIDTH + 2)) '' | tr ' ' '─')┼$(printf '%*s' $((STATUS_COL_WIDTH + 2)) '' | tr ' ' '─')┤${NC}"
BOT_BORDER="${CYAN}└$(printf '%*s' $((NODE_COL_WIDTH + 2)) '' | tr ' ' '─')┴$(printf '%*s' $((STATUS_COL_WIDTH + 2)) '' | tr ' ' '─')┘${NC}"

echo -e "$TOP_BORDER"
printf "${CYAN}│${NC}%*s${CYAN}│${NC}%*s${CYAN}│${NC}\n" $(((NODE_COL_WIDTH + STATUS_COL_WIDTH + 4 + 13) / 2)) "NODE STATUS" $(((NODE_COL_WIDTH + STATUS_COL_WIDTH + 4 - 13) / 2)) ""
echo -e "$MID_BORDER"
printf "${CYAN}│${NC} %-${NODE_COL_WIDTH}s ${CYAN}│${NC} %-${STATUS_COL_WIDTH}s ${CYAN}│${NC}\n" "NODE" "STATUS"
echo -e "$MID_BORDER"

# Get node status
kubectl get nodes -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].status' --no-headers | while read -r node status; do
    if [[ "$status" == "True" ]]; then
        status_display="${GREEN}Ready${NC}"
    else
        status_display="${YELLOW}NotReady${NC}"
    fi
    
    printf "${CYAN}│${NC} %-${NODE_COL_WIDTH}s ${CYAN}│${NC} %-$((STATUS_COL_WIDTH + 11))b ${CYAN}│${NC}\n" "$node" "$status_display"
done

echo -e "$BOT_BORDER"
echo ""


# Get pods per node - Calculate column widths (25% / 45% / 15% / 15% split)
POD_NODE_WIDTH=$((TERM_WIDTH * 25 / 100 - 2))
POD_POD_WIDTH=$((TERM_WIDTH * 45 / 100 - 2))
POD_NS_WIDTH=$((TERM_WIDTH * 15 / 100 - 2))
POD_STATUS_WIDTH=$((TERM_WIDTH * 15 / 100 - 2))

# Build borders for pods table
POD_TOP="${CYAN}┌$(printf '%*s' $((POD_NODE_WIDTH + 2)) '' | tr ' ' '─')┬$(printf '%*s' $((POD_POD_WIDTH + 2)) '' | tr ' ' '─')┬$(printf '%*s' $((POD_NS_WIDTH + 2)) '' | tr ' ' '─')┬$(printf '%*s' $((POD_STATUS_WIDTH + 2)) '' | tr ' ' '─')┐${NC}"
POD_MID="${CYAN}├$(printf '%*s' $((POD_NODE_WIDTH + 2)) '' | tr ' ' '─')┼$(printf '%*s' $((POD_POD_WIDTH + 2)) '' | tr ' ' '─')┼$(printf '%*s' $((POD_NS_WIDTH + 2)) '' | tr ' ' '─')┼$(printf '%*s' $((POD_STATUS_WIDTH + 2)) '' | tr ' ' '─')┤${NC}"
POD_BOT="${CYAN}└$(printf '%*s' $((POD_NODE_WIDTH + 2)) '' | tr ' ' '─')┴$(printf '%*s' $((POD_POD_WIDTH + 2)) '' | tr ' ' '─')┴$(printf '%*s' $((POD_NS_WIDTH + 2)) '' | tr ' ' '─')┴$(printf '%*s' $((POD_STATUS_WIDTH + 2)) '' | tr ' ' '─')┘${NC}"

echo -e "$POD_TOP"
printf "${CYAN}│${NC}%*s${CYAN}│${NC}%*s${CYAN}│${NC}\n" $(((TERM_WIDTH + 13) / 2)) "PODS BY NODE" $(((TERM_WIDTH - 13) / 2 - 2)) ""
echo -e "$POD_MID"
printf "${CYAN}│${NC} %-${POD_NODE_WIDTH}s ${CYAN}│${NC} %-${POD_POD_WIDTH}s ${CYAN}│${NC} %-${POD_NS_WIDTH}s ${CYAN}│${NC} %-${POD_STATUS_WIDTH}s ${CYAN}│${NC}\n" "NODE" "POD" "NAMESPACE" "STATUS"
echo -e "$POD_MID"

kubectl get pods --all-namespaces -o custom-columns='NODE:.spec.nodeName,POD:.metadata.name,NAMESPACE:.metadata.namespace,STATUS:.status.phase' --no-headers | sort -k3,3 -k2,2 | while read -r node pod namespace status; do
    # Color status
    case "$status" in
        Running)
            status_display="${GREEN}${status}${NC}"
            ;;
        Pending)
            status_display="${YELLOW}${status}${NC}"
            ;;
        *)
            status_display="${status}"
            ;;
    esac
    
    # Truncate long names to fit columns
    pod_short="${pod:0:$POD_POD_WIDTH}"
    node_short="${node:0:$POD_NODE_WIDTH}"
    ns_short="${namespace:0:$POD_NS_WIDTH}"
    
    printf "${CYAN}│${NC} %-${POD_NODE_WIDTH}s ${CYAN}│${NC} %-${POD_POD_WIDTH}s ${CYAN}│${NC} %-${POD_NS_WIDTH}s ${CYAN}│${NC} %-$((POD_STATUS_WIDTH + 11))b ${CYAN}│${NC}\n" "$node_short" "$pod_short" "$ns_short" "$status_display"
done

echo -e "$POD_BOT"
echo ""

# Summary
echo -e "${GREEN}=== Summary ===${NC}"
total_nodes=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
total_pods=$(kubectl get pods --all-namespaces --no-headers | wc -l | tr -d ' ')
running_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo -e "Total Nodes: ${BLUE}${total_nodes}${NC}"
echo -e "Total Pods:  ${BLUE}${total_pods}${NC} (Running: ${GREEN}${running_pods}${NC})"
echo ""
