# Configuration Changes Summary: Using Kind-Loaded Images Only

## What Changed

All deployment configurations have been updated to **ONLY** use images already loaded into Kind cluster nodes, without attempting to pull from any registry.

## Key Changes

### Image Pull Policy: `Never`

All components now use `imagePullPolicy: Never`, which means:
- ✅ Will ONLY use images already present in Kind nodes
- ❌ Will NEVER attempt to pull from any registry (local or remote)
- 🛑 Will fail with `ErrImageNeverPull` if image is not already loaded

### Files Modified

#### 1. [`config/kafka-ui.yaml`](file:///Users/bmscomp/production/klster/config/kafka-ui.yaml)
```yaml
# Before:
image: localhost:5001/provectuslabs/kafka-ui:latest
imagePullPolicy: IfNotPresent

# After:
image: provectuslabs/kafka-ui:latest
imagePullPolicy: Never
```

#### 2. [`config/litmus-values.yaml`](file:///Users/bmscomp/production/klster/config/litmus-values.yaml)
```yaml
operator:
  image:
    repository: litmuschaos/chaos-operator
    pullPolicy: Never  # Changed from IfNotPresent

runner:
  image:
    repository: litmuschaos/chaos-runner
    pullPolicy: Never  # Changed from IfNotPresent

exporter:
  image:
    repository: litmuschaos/chaos-exporter
    pullPolicy: Never  # Changed from IfNotPresent
```

#### 3. [`config/monitoring.yaml`](file:///Users/bmscomp/production/klster/config/monitoring.yaml)
```yaml
# Removed all registry overrides (localhost:5001)
# Added global policy:
global:
  imagePullPolicy: Never

# All components now use original image names
prometheus:
  prometheusSpec:
    image:
      tag: v3.1.0  # No registry/repository override

prometheusOperator:
  image:
    tag: v0.79.2
  imagePullPolicy: Never
# ... etc
```

#### 4. [`deploy-kafka.sh`](file:///Users/bmscomp/production/klster/deploy-kafka.sh)
```bash
# Before:
--set defaultImageRegistry=localhost:5001 \

# After:
--set imagePullPolicy=Never \
```

#### 5. [`deploy-all-from-kind.sh`](file:///Users/bmscomp/production/klster/deploy-all-from-kind.sh)
```bash
# Simplified to use monitoring.yaml values file
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 79.11.0 \
  --namespace monitoring \
  --create-namespace \
  --values config/monitoring.yaml \
  --wait
```

#### 6. [`load-images-to-kind.sh`](file:///Users/bmscomp/production/klster/load-images-to-kind.sh)
```bash
# Added check to skip if image already exists in Kind
if docker exec "${KIND_CLUSTER_NAME}-control-plane" crictl images 2>/dev/null | grep -q "${image}"; then
    echo "Image already exists in kind cluster, skipping..."
    return 0
fi
```

## Workflow

### 1. Load Images into Kind (One Time)
```bash
./load-images-to-kind.sh
```
This script:
- Checks if each image already exists in Kind
- Skips images that are already loaded
- Only loads new/missing images

### 2. Deploy Services
```bash
# Option A: Deploy everything
./deploy-all-from-kind.sh

# Option B: Deploy individually
./deploy-kafka.sh
./deploy-kafka-ui.sh
./deploy-litmuschaos.sh
```

All deployments will **ONLY** use images already in Kind nodes.

## Benefits

✅ **No registry dependency** - Works completely offline after images are loaded  
✅ **Faster deployments** - No time wasted checking registries  
✅ **Predictable behavior** - Guaranteed to use exact images in Kind  
✅ **Fail-fast** - Immediately fails if required image is missing  
✅ **No registry authentication** - No credentials needed

## Verification

### Check images in Kind:
```bash
docker exec -it panda-control-plane crictl images
```

### Check if specific image exists:
```bash
docker exec -it panda-control-plane crictl images | grep "kafka-ui"
```

### Check pod image pull status:
```bash
kubectl get pods -A
kubectl describe pod <pod-name> -n <namespace>
```

## Troubleshooting

### Pod stuck in `ErrImageNeverPull`
**Cause**: Image not loaded in Kind nodes  
**Solution**:
```bash
# Re-run image loader
./load-images-to-kind.sh

# Or manually load specific image
docker pull <image-from-registry>
kind load docker-image <image> --name panda
```

### How to update an image
```bash
# 1. Pull new version from registry to local Docker
docker pull provectuslabs/kafka-ui:v2.0

# 2. Load into Kind
kind load docker-image provectuslabs/kafka-ui:v2.0 --name panda

# 3. Update manifest and redeploy
kubectl apply -f config/kafka-ui.yaml
```

## Image List (22 images)

All these images must be loaded in Kind before deployment:

### Kafka Stack (4)
- provectuslabs/kafka-ui:latest
- quay.io/strimzi/operator:0.49.0
- quay.io/strimzi/kafka:0.49.0-kafka-4.1.1
- quay.io/strimzi/kafka:0.49.0-kafka-4.0.0

### Prometheus Stack (6)
- quay.io/prometheus/prometheus:v3.1.0
- quay.io/prometheus/alertmanager:v0.28.1
- quay.io/prometheus/node-exporter:v1.8.2
- quay.io/prometheus-operator/prometheus-operator:v0.79.2
- quay.io/prometheus-operator/prometheus-config-reloader:v0.79.2
- quay.io/prometheus-operator/admission-webhook:v0.79.2

### Monitoring (2)
- docker.io/grafana/grafana:11.4.0
- registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0

### LitmusChaos (5)
- litmuschaos/chaos-operator:3.23.0
- litmuschaos/chaos-runner:3.23.0
- litmuschaos/chaos-exporter:3.23.0
- litmuschaos/litmusportal-subscriber:3.23.0
- litmuschaos/litmusportal-event-tracker:3.23.0

### Utilities (1)
- registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.5

## Important Notes

⚠️ **Before deploying**, ensure all required images are loaded:
```bash
./load-images-to-kind.sh
```

⚠️ **No fallback** - With `imagePullPolicy: Never`, there's no fallback to registry if image is missing

⚠️ **Version must match exactly** - Image tag in manifest must exactly match image in Kind nodes
