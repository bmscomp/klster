#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying LitmusChaos...${NC}"

# Create namespace
kubectl create namespace litmus --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repository
echo -e "${GREEN}Adding LitmusChaos Helm repository...${NC}"
helm repo remove litmuschaos 2>/dev/null || true
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm repo update

# Install LitmusChaos
echo -e "${GREEN}Installing LitmusChaos Operator...${NC}"
helm upgrade --install chaos litmuschaos/litmus \
  --namespace litmus \
  --version 3.23.0 \
  --values config/litmus-values.yaml \
  --wait

# Wait for operator to be ready
echo -e "${GREEN}Waiting for LitmusChaos operator to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s \
  deployment/chaos-operator-ce -n litmus

# Create ServiceMonitor for Prometheus integration
echo -e "${GREEN}Creating ServiceMonitor for Prometheus integration...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: litmus-chaos-exporter
  namespace: litmus
  labels:
    app: chaos-exporter
    release: monitoring
spec:
  selector:
    matchLabels:
      app: chaos-exporter
  namespaceSelector:
    matchNames:
      - litmus
  endpoints:
  - port: tcp-metrics
    path: /metrics
    interval: 30s
EOF

echo ""
echo -e "${GREEN}LitmusChaos deployment complete!${NC}"
echo ""
echo "LitmusChaos chaos engineering platform is now installed."
echo ""
echo "Next steps:"
echo "  1. Deploy sample experiments: kubectl apply -f config/litmus-experiments/"
echo "  2. View chaos metrics in Grafana"
echo "  3. Check operator logs: kubectl logs -n litmus -l app.kubernetes.io/component=operator"
echo ""
echo "To run a quick test:"
echo "  kubectl apply -f config/litmus-experiments/pod-delete.yaml"
