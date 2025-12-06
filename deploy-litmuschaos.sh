#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying LitmusChaos...${NC}"

# Create namespace
kubectl create namespace litmus --dry-run=client -o yaml | kubectl apply -f -

# Detect Apple Silicon (arm64) hosts which need x86_64 Litmus images
ARCH=$(uname -m)
if [[ "${ARCH}" == "arm64" && -z "${SKIP_APPLE_SILICON_LITMUS_FIX}" ]]; then
  echo -e "${GREEN}Apple Silicon detected (arm64). Pre-loading linux/amd64 Litmus images...${NC}"
  ./load-litmus-images.sh
  echo -e "${GREEN}Litmus images for amd64 loaded successfully.${NC}"
fi

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

echo -e "${GREEN}Setting up Litmus project and RBAC...${NC}"
kubectl apply -f config/litmus-project.yaml
echo ""

echo -e "${GREEN}Deploying Litmus experiments to Kafka namespace...${NC}"
kubectl apply -f config/litmus-experiments/
echo ""

echo -e "${GREEN}Deploying Litmus workflows...${NC}"
kubectl apply -f config/litmus-workflows/ 2>/dev/null || echo "Workflows require Argo Workflows to be installed"
echo ""

echo "LitmusChaos chaos engineering platform is now installed with:"
echo "  ✓ Project: kafka-resilience"
echo "  ✓ Experiments: pod-delete, container-kill, node-drain, network-loss, disk-fill"
echo "  ✓ RBAC: kafka-chaos-sa service account in kafka namespace"
echo "  ✓ Workflows: kafka-resilience-workflow (requires Argo)"
echo ""

echo "Next steps:"
echo "  1. View experiments: kubectl get chaosexperiments -n kafka"
echo "  2. Run an experiment: kubectl apply -f config/litmus-experiments/kafka-pod-delete.yaml"
echo "  3. View chaos metrics in Grafana at http://localhost:30080"
echo "  4. Check operator logs: kubectl logs -n litmus -l app.kubernetes.io/component=operator"
echo "  5. Monitor results: kubectl get chaosresults -n kafka"
echo ""
echo "=== Accessing LitmusChaos UI ==="
echo "The UI is enabled. To access it:"
echo "  1. Run port-forward: make chaos-ui"
echo "  2. Open browser: http://localhost:9091"
echo "  3. Default credentials:"
echo "     Username: admin"
echo "     Password: litmus"
echo ""
echo "To run a quick test:"
echo "  kubectl apply -f config/litmus-experiments/pod-delete.yaml"
