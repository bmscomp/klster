# Using Pre-loaded Images in Kind Cluster

This guide explains how to use images that are already loaded into the Kind cluster to run all services.

## Overview

Instead of pulling images from remote registries each time, we:
1. Load images into Kind cluster nodes using `kind load docker-image`
2. Configure Kubernetes to use these pre-loaded images with `imagePullPolicy: IfNotPresent`

## Prerequisites

- Images must be loaded from local registry into Kind cluster
- Kind cluster must be running

## Quick Start

### Option 1: Deploy Everything (Recommended)

Run the all-in-one deployment script:

```bash
./deploy-all-from-kind.sh
```

This script will:
1. Load all images from local registry (`localhost:5001`) into Kind cluster
2. Deploy Prometheus & Grafana with local images
3. Deploy Kafka (Strimzi) with local images  
4. Deploy Kafka UI with local images
5. Deploy LitmusChaos with local images

### Option 2: Step-by-Step Deployment

#### Step 1: Load Images into Kind

```bash
./load-images-to-kind.sh
```

This pulls images from your local registry at `localhost:5001` and loads them into all Kind cluster nodes.

#### Step 2: Deploy Services

```bash
# Deploy monitoring (Prometheus & Grafana)
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 79.11.0 \
  --namespace monitoring \
  --create-namespace \
  --set global.imagePullPolicy=IfNotPresent \
  --values config/monitoring.yaml \
  --wait

# Deploy Kafka
./deploy-kafka.sh

# Deploy Kafka UI
./deploy-kafka-ui.sh

# Deploy LitmusChaos
./deploy-litmuschaos.sh
```

## How It Works

### Image Pull Policy

All configurations use `imagePullPolicy: IfNotPresent`, which means:
- If image exists in Kind nodes → use it (fast)
- If image doesn't exist → pull from registry (fallback)

### Configurations Updated

1. **Kafka UI** (`config/kafka-ui.yaml`)
   - Image: `localhost:5001/provectuslabs/kafka-ui:latest`
   - Pull policy: `IfNotPresent`

2. **LitmusChaos** (`config/litmus-values.yaml`)
   - All components use `pullPolicy: IfNotPresent`
   - Operator, Runner, Exporter images

3. **Prometheus Stack** (Helm values)
   - All components configured with local registry and `IfNotPresent` policy

4. **Strimzi Kafka** (`deploy-kafka.sh`)
   - Uses `defaultImageRegistry=localhost:5001`

## Verify Images Loaded in Kind

Check images in Kind cluster nodes:

```bash
# List all images in control-plane node
docker exec -it panda-control-plane crictl images

# Check specific images
docker exec -it panda-control-plane crictl images | grep -E "(kafka|prometheus|grafana|litmus)"
```

## Access Services

After deployment:

- **Grafana**: http://localhost:30080 (admin/admin)
- **Kafka UI**: http://localhost:30081

## Troubleshooting

### Images not found
If pods fail with `ImagePullBackOff`:
1. Verify images are loaded: `docker exec -it panda-control-plane crictl images`
2. Re-run: `./load-images-to-kind.sh`

### Pull from wrong registry
If pods pull from remote instead of using local images:
- Check `imagePullPolicy` is set to `IfNotPresent` in all manifests
- Verify image names match exactly between loaded images and manifests

## Images Loaded (22 total)

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

## Benefits

✅ **Faster deployments** - No remote registry pulls  
✅ **Offline capable** - Works without internet after initial load  
✅ **Consistent versions** - All nodes use same pre-loaded images  
✅ **Reduced bandwidth** - Images pulled once, used many times
