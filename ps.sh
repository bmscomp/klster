#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}=== Kubernetes Cluster Status ===${NC}"
echo ""

# Get all nodes with resource usage
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                                    NODE STATUS                                          │${NC}"
echo -e "${CYAN}├──────────────────────┬────────────┬────────────────────┬────────────────────────────────┤${NC}"
printf "${CYAN}│${NC} %-20s ${CYAN}│${NC} %-10s ${CYAN}│${NC} %-18s ${CYAN}│${NC} %-30s ${CYAN}│${NC}\n" "NODE" "STATUS" "MEMORY USAGE" "CPU USAGE"
echo -e "${CYAN}├──────────────────────┼────────────┼────────────────────┼────────────────────────────────┤${NC}"

# Get node metrics
kubectl get nodes -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].status' --no-headers | while read -r node status; do
    if [[ "$status" == "True" ]]; then
        status_display="${GREEN}Ready${NC}"
    else
        status_display="${YELLOW}NotReady${NC}"
    fi
    
    # Get memory and CPU from kubectl top (if metrics-server available)
    if metrics=$(kubectl top node "$node" --no-headers 2>/dev/null); then
        cpu=$(echo "$metrics" | awk '{print $2}')
        mem=$(echo "$metrics" | awk '{print $4}')
    else
        cpu="N/A"
        mem="N/A"
    fi
    
    printf "${CYAN}│${NC} %-20s ${CYAN}│${NC} %-21b ${CYAN}│${NC} %-18s ${CYAN}│${NC} %-30s ${CYAN}│${NC}\n" "$node" "$status_display" "$mem" "$cpu"
done

echo -e "${CYAN}└──────────────────────┴────────────┴────────────────────┴────────────────────────────────┘${NC}"
echo ""

# Cache pod metrics to temp file (if metrics-server available)
POD_METRICS_FILE=$(mktemp)
trap "rm -f $POD_METRICS_FILE" EXIT
kubectl top pods --all-namespaces --no-headers 2>/dev/null > "$POD_METRICS_FILE" || true

# Function to get pod metrics from cache
get_pod_metrics() {
    local ns="$1"
    local pod="$2"
    grep -E "^${ns}\s+${pod}\s+" "$POD_METRICS_FILE" 2>/dev/null | awk '{print $3, $4}' || echo "N/A N/A"
}

# Get pods per node
echo -e "${CYAN}┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                                              PODS BY NODE                                                         │${NC}"
echo -e "${CYAN}├──────────────────────┬──────────────────────────────────────┬────────────┬──────────────┬──────────┬──────────────┤${NC}"
printf "${CYAN}│${NC} %-20s ${CYAN}│${NC} %-36s ${CYAN}│${NC} %-10s ${CYAN}│${NC} %-12s ${CYAN}│${NC} %-8s ${CYAN}│${NC} %-12s ${CYAN}│${NC}\n" "NODE" "POD" "NAMESPACE" "STATUS" "CPU" "MEMORY"
echo -e "${CYAN}├──────────────────────┼──────────────────────────────────────┼────────────┼──────────────┼──────────┼──────────────┤${NC}"

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
    
    # Get pod metrics from cache
    metrics=$(get_pod_metrics "$namespace" "$pod")
    cpu=$(echo "$metrics" | awk '{print $1}')
    mem=$(echo "$metrics" | awk '{print $2}')
    
    # Truncate long names
    pod_short="${pod:0:36}"
    node_short="${node:0:20}"
    ns_short="${namespace:0:10}"
    
    printf "${CYAN}│${NC} %-20s ${CYAN}│${NC} %-36s ${CYAN}│${NC} %-10s ${CYAN}│${NC} %-23b ${CYAN}│${NC} %-8s ${CYAN}│${NC} %-12s ${CYAN}│${NC}\n" "$node_short" "$pod_short" "$ns_short" "$status_display" "$cpu" "$mem"
done

echo -e "${CYAN}└──────────────────────┴──────────────────────────────────────┴────────────┴──────────────┴──────────┴──────────────┘${NC}"
echo ""

# Summary
echo -e "${GREEN}=== Summary ===${NC}"
total_nodes=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
total_pods=$(kubectl get pods --all-namespaces --no-headers | wc -l | tr -d ' ')
running_pods=$(kubectl get pods --all-namespaces --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')

echo -e "Total Nodes: ${BLUE}${total_nodes}${NC}"
echo -e "Total Pods:  ${BLUE}${total_pods}${NC} (Running: ${GREEN}${running_pods}${NC})"
echo ""
