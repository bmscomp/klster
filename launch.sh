#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Local Kubernetes Cluster Setup...${NC}"

# Check dependencies
command -v kind >/dev/null 2>&1 || { echo >&2 "kind is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo >&2 "kubectl is required but not installed. Aborting."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo >&2 "helm is required but not installed. Aborting."; exit 1; }

# Source proxy configuration if it exists
if [ -f "proxy/proxy.conf" ]; then
    echo "Loading proxy configuration..."
    set -a
    source proxy/proxy.conf
    set +a
fi

# Setup local Docker registry
echo -e "${GREEN}Setting up local Docker registry...${NC}"
./setup-registry.sh

# Connect registry to kind network (create network if it doesn't exist)
echo -e "${GREEN}Connecting registry to kind network...${NC}"
docker network create kind 2>/dev/null || true
docker network connect kind kind-registry 2>/dev/null || true

# Pull and push images to local registry
echo -e "${GREEN}Populating local registry with required images...${NC}"
./pull-images.sh

# Create Cluster
echo -e "${GREEN}Creating Kind cluster...${NC}"
kind delete cluster --name panda || true
kind create cluster --config config/cluster.yaml --name panda

# Document the local registry in the cluster
echo -e "${GREEN}Configuring cluster to use local registry...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5001"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF


# Install Monitoring
echo -e "${GREEN}Installing Prometheus and Grafana...${NC}"
helm repo remove prometheus-community 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 79.11.0 \
  --namespace monitoring \
  --create-namespace \
  --values config/monitoring.yaml \
  --wait

echo -e "${GREEN}Applying custom dashboards...${NC}"
kubectl apply -f config/custom-dashboard.yaml

echo -e "${GREEN}Cluster setup complete!${NC}"
echo "Grafana is available at http://localhost:30080 (login: admin/admin)"
echo "To access Grafana, you might need to port-forward if NodePort is not directly accessible on Mac with Kind (Docker Desktop handles it usually, but port-forward is safer):"
echo "kubectl port-forward svc/monitoring-grafana 30080:80 -n monitoring"
