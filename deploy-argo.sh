#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying Argo Workflows...${NC}"

# Note: Images are loaded via pull-images.sh which is run during setup
# No need for separate image loading here

# Create namespace
echo -e "${GREEN}Creating argo namespace...${NC}"
kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -

# Install Argo Workflows
echo -e "${GREEN}Installing Argo Workflows...${NC}"
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/install.yaml

# Wait for Argo server to be ready
echo -e "${GREEN}Waiting for Argo Workflows to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/argo-server -n argo || \
  echo -e "${YELLOW}Warning: argo-server did not become Ready within timeout.${NC}"

# Patch argo-server to use server auth mode (no auth for local dev)
echo -e "${GREEN}Configuring Argo server for local access...${NC}"
kubectl patch deployment argo-server -n argo --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
  "server",
  "--auth-mode=server"
]}]'

# Wait for patched deployment to roll out
kubectl rollout status deployment/argo-server -n argo --timeout=120s || \
  echo -e "${YELLOW}Warning: argo-server rollout did not complete within timeout.${NC}"

# Create ServiceMonitor for Prometheus integration
echo -e "${GREEN}Creating ServiceMonitor for Prometheus integration...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argo-workflows
  namespace: argo
  labels:
    app: argo-workflows
    release: monitoring
spec:
  selector:
    matchLabels:
      app: argo-server
  namespaceSelector:
    matchNames:
      - argo
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
EOF

echo ""
echo -e "${GREEN}Argo Workflows deployment complete!${NC}"
echo ""
echo "=== Accessing Argo Workflows UI ==="
echo "To access the Argo UI:"
echo "  1. Run port-forward: make argo-ui"
echo "  2. Open browser: https://localhost:2746"
echo "  3. Accept the self-signed certificate warning"
echo "  4. No authentication required (server auth mode)"
echo ""
echo "=== Deploy Litmus Workflows ==="
echo "Now you can deploy Litmus chaos workflows:"
echo "  kubectl apply -f config/litmus-workflows/"
echo ""
echo "=== Useful Commands ==="
echo "  View workflows: kubectl get workflows -n litmus"
echo "  View workflow details: kubectl describe workflow <name> -n litmus"
echo "  View workflow logs: kubectl logs -n litmus -l workflows.argoproj.io/workflow=<name>"
echo ""
