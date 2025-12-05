#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying Kafka Strimzi Cluster...${NC}"

# Create namespace
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

# Install Strimzi Operator
echo -e "${GREEN}Installing Strimzi Operator...${NC}"
helm repo remove strimzi 2>/dev/null || true
helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --version 0.49.0 \
  --namespace kafka \
  --set watchAnyNamespace=true \
  --set imagePullPolicy=Never \
  --set imageRegistry="" \
  --set imageRepository="" \
  --wait

# Apply Metrics Config
echo -e "${GREEN}Applying Metrics Configuration...${NC}"
kubectl apply -f config/kafka-metrics.yaml

# Apply Kafka Cluster
echo -e "${GREEN}Deploying Kafka Cluster (KRaft)...${NC}"
kubectl apply -f config/kafka.yaml

# Apply Dashboard
echo -e "${GREEN}Applying Kafka Dashboards...${NC}"
kubectl apply -f config/kafka-dashboard.yaml
kubectl apply -f config/kafka-performance-dashboard.yaml
kubectl apply -f config/kafka-jvm-dashboard.yaml
kubectl apply -f config/kafka-perf-test-dashboard.yaml
kubectl apply -f config/kafka-working-dashboard.yaml
kubectl apply -f config/kafka-comprehensive-dashboard.yaml
kubectl apply -f config/kafka-all-metrics-dashboard.yaml

# Cleanup old cluster if exists
kubectl delete kafka my-cluster -n kafka --ignore-not-found
# Cleanup old NodePool
kubectl delete kafkanodepool dual-role -n kafka --ignore-not-found
# Cleanup PVCs for fresh start (since we changed topology)
kubectl delete pvc -l strimzi.io/cluster=krafter -n kafka --ignore-not-found
kubectl delete pvc -l strimzi.io/cluster=my-cluster -n kafka --ignore-not-found

echo -e "${GREEN}Waiting for Kafka cluster to be ready (this may take a few minutes)...${NC}"
kubectl wait kafka/krafter --for=condition=Ready --timeout=300s -n kafka 

echo -e "${GREEN}Kafka deployment complete!${NC}"
echo "Check the 'Kafka Cluster Health' dashboard in Grafana."
