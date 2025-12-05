#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Fixing Monitoring Stack Image Pulls${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Pull missing images from remote and push to local registry
echo -e "${BLUE}Step 1: Ensuring Grafana sidecar image is in local registry${NC}"
if curl -s http://localhost:5001/v2/_catalog 2>/dev/null >/dev/null; then
    echo "Pulling and pushing Grafana sidecar image..."
    docker pull quay.io/kiwigrid/k8s-sidecar:1.27.6 || echo "Already pulled"
    docker tag quay.io/kiwigrid/k8s-sidecar:1.27.6 localhost:5001/quay.io/kiwigrid/k8s-sidecar:1.27.6
    docker push localhost:5001/quay.io/kiwigrid/k8s-sidecar:1.27.6 || echo "Already pushed"
else
    echo -e "${YELLOW}Local registry not running, skipping push to registry${NC}"
fi

# Step 2: Load missing images into Kind
echo ""
echo -e "${BLUE}Step 2: Loading Grafana sidecar into Kind cluster${NC}"
if docker images | grep -q "k8s-sidecar.*1.27.6"; then
    kind load docker-image quay.io/kiwigrid/k8s-sidecar:1.27.6 --name panda || echo "Already loaded"
else
    echo "Pulling image first..."
    docker pull quay.io/kiwigrid/k8s-sidecar:1.27.6
    kind load docker-image quay.io/kiwigrid/k8s-sidecar:1.27.6 --name panda
fi

# Step 3: Uninstall existing monitoring stack
echo ""
echo -e "${BLUE}Step 3: Uninstalling existing monitoring stack${NC}"
helm uninstall monitoring -n monitoring || echo "No existing release found"

# Wait for cleanup
echo "Waiting for pods to terminate..."
sleep 10

# Step 4: Reinstall with correct configuration
echo ""
echo -e "${BLUE}Step 4: Reinstalling monitoring with imagePullPolicy: Never${NC}"
helm repo update prometheus-community

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 79.11.0 \
  --namespace monitoring \
  --create-namespace \
  --values config/monitoring.yaml \
  --wait

echo ""
echo -e "${GREEN}Applying custom dashboards...${NC}"
kubectl apply -f config/custom-dashboard.yaml

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Monitoring Stack Fixed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Verifying pods are using local images:"
kubectl get pods -n monitoring
echo ""
echo "Check image sources:"
echo "  kubectl get pods -n monitoring -o jsonpath='{range .items[*]}{\"\n\"}{.metadata.name}{\":\n\"}{range .spec.containers[*]}{\"  \"}{.image}{\" (pull: \"}{.imagePullPolicy}{\")\n\"}{end}{end}'"
echo ""
