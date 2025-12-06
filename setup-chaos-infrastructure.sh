#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up LitmusChaos Infrastructure...${NC}"
echo ""

# Check if litmus namespace exists
if ! kubectl get namespace litmus >/dev/null 2>&1; then
    echo -e "${RED}Error: Litmus namespace not found. Please run 'make chaos-install' first.${NC}"
    exit 1
fi

# Install Litmus Chaos Infrastructure (Subscriber/Agent)
echo -e "${BLUE}Installing Litmus Chaos Infrastructure...${NC}"

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: litmus-admin
  namespace: litmus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: litmus-admin
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec", "services", "events", "configmaps", "secrets"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: ["litmuschaos.io"]
    resources: ["*"]
    verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: litmus-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: litmus-admin
subjects:
  - kind: ServiceAccount
    name: litmus-admin
    namespace: litmus
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: subscriber
  namespace: litmus
  labels:
    app: subscriber
spec:
  replicas: 1
  selector:
    matchLabels:
      app: subscriber
  template:
    metadata:
      labels:
        app: subscriber
    spec:
      serviceAccountName: litmus-admin
      containers:
        - name: subscriber
          image: litmuschaos/litmusportal-subscriber:3.23.0
          imagePullPolicy: Never
          env:
            - name: AGENT_SCOPE
              value: "cluster"
            - name: AGENT_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: COMPONENTS
              value: "SUBSCRIBER"
            - name: SERVER_ADDR
              value: "http://chaos-litmus-server-service.litmus.svc.cluster.local:9002"
            - name: IS_CLUSTER_CONFIRMED
              value: "true"
            - name: CLUSTER_ID
              value: "local-cluster"
            - name: ACCESS_KEY
              value: "default"
            - name: VERSION
              value: "3.23.0"
            - name: SKIP_SSL_VERIFY
              value: "true"
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chaos-operator-ce
  namespace: litmus
  labels:
    app: chaos-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chaos-operator
  template:
    metadata:
      labels:
        app: chaos-operator
    spec:
      serviceAccountName: litmus-admin
      containers:
        - name: chaos-operator
          image: litmuschaos/chaos-operator:3.23.0
          imagePullPolicy: Never
          command:
            - chaos-operator
          env:
            - name: CHAOS_RUNNER_IMAGE
              value: "litmuschaos/chaos-runner:3.23.0"
            - name: WATCH_NAMESPACE
              value: ""
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: OPERATOR_NAME
              value: "chaos-operator"
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 250m
              memory: 256Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chaos-exporter
  namespace: litmus
  labels:
    app: chaos-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chaos-exporter
  template:
    metadata:
      labels:
        app: chaos-exporter
    spec:
      serviceAccountName: litmus-admin
      containers:
        - name: chaos-exporter
          image: litmuschaos/chaos-exporter:3.23.0
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
              name: metrics
          env:
            - name: TSDB_SCRAPE_INTERVAL
              value: "10"
          resources:
            limits:
              cpu: 250m
              memory: 256Mi
            requests:
              cpu: 125m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: chaos-exporter
  namespace: litmus
  labels:
    app: chaos-exporter
spec:
  selector:
    app: chaos-exporter
  ports:
    - port: 8080
      targetPort: 8080
      name: metrics
EOF

echo ""
echo -e "${GREEN}Waiting for chaos infrastructure to be ready...${NC}"

# Wait for deployments
kubectl wait --for=condition=available --timeout=300s deployment/subscriber -n litmus || \
  echo -e "${YELLOW}Warning: subscriber did not become Ready within timeout.${NC}"

kubectl wait --for=condition=available --timeout=300s deployment/chaos-operator-ce -n litmus || \
  echo -e "${YELLOW}Warning: chaos-operator-ce did not become Ready within timeout.${NC}"

kubectl wait --for=condition=available --timeout=300s deployment/chaos-exporter -n litmus || \
  echo -e "${YELLOW}Warning: chaos-exporter did not become Ready within timeout.${NC}"

echo ""
echo -e "${GREEN}✓ Chaos Infrastructure setup complete!${NC}"
echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo ""
echo "1. Access LitmusChaos Portal:"
echo "   make chaos-ui"
echo "   Open: http://localhost:9091"
echo "   Login: admin / litmus"
echo ""
echo "2. The chaos infrastructure is now enabled for:"
echo "   - Cluster: local-cluster"
echo "   - Namespace: litmus"
echo "   - Scope: cluster-wide"
echo ""
echo "3. Verify infrastructure status:"
echo "   kubectl get pods -n litmus"
echo ""
echo "4. Run chaos experiments:"
echo "   make chaos-workflows-run"
echo ""
echo "5. View available CRDs:"
echo "   kubectl get crd | grep chaos"
echo ""
