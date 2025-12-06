#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying LitmusChaos...${NC}"

# Create namespace
kubectl create namespace litmus --dry-run=client -o yaml | kubectl apply -f -

# Note: Images are loaded via pull-images.sh which is run during setup
# No need for separate image loading here

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

# Wait for operator or portal to be ready (best-effort)
echo -e "${GREEN}Waiting for LitmusChaos control plane to be ready...${NC}"
if kubectl get deploy chaos-operator-ce -n litmus >/dev/null 2>&1; then
  kubectl wait --for=condition=available --timeout=300s deployment/chaos-operator-ce -n litmus || \
    echo -e "${YELLOW}Warning: chaos-operator-ce did not become Ready within timeout.${NC}"
elif kubectl get deploy chaos-litmus-server -n litmus >/dev/null 2>&1; then
  kubectl wait --for=condition=available --timeout=300s deployment/chaos-litmus-server -n litmus || \
    echo -e "${YELLOW}Warning: chaos-litmus-server did not become Ready within timeout.${NC}"
else
  echo -e "${YELLOW}Warning: No known Litmus operator or portal deployment found; skipping readiness wait.${NC}"
fi

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

echo -e "${GREEN}Checking for Litmus CRDs before applying experiments...${NC}"
if kubectl get crd chaosexperiments.litmuschaos.io >/dev/null 2>&1 \
   && kubectl get crd chaosengines.litmuschaos.io >/dev/null 2>&1; then
  echo -e "${GREEN}Litmus CRDs found. Deploying experiments to Kafka namespace...${NC}"
  kubectl apply -f config/litmus-experiments/
  echo ""
else
  echo -e "${YELLOW}Warning: Litmus CRDs not found (chaosexperiments / chaosengines). Skipping experiment manifests.${NC}"
  echo -e "${YELLOW}Once CRDs are installed, run: kubectl apply -f config/litmus-experiments/${NC}"
fi


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
