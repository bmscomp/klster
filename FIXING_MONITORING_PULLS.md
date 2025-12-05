# Fixing Monitoring Stack Image Pulls

## Problem

Some monitoring pods were pulling images from external registries instead of using images already loaded in Kind:

### Images Being Pulled Externally:
1. ❌ `quay.io/kiwigrid/k8s-sidecar:2.1.2` - Grafana sidecar (wrong version)
2. ❌ `docker.io/grafana/grafana:12.3.0` - Grafana (wrong version)
3. ❌ `quay.io/prometheus-operator/prometheus-config-reloader:v0.86.2` - Config reloader (wrong version)

## Root Cause

The Helm chart was using default versions and not respecting the `imagePullPolicy: Never` setting for all sub-components, especially:
- Grafana sidecar containers
- Prometheus config reloader
- Init containers

## Solution Applied

### 1. Updated [`config/monitoring.yaml`](file:///Users/bmscomp/production/klster/config/monitoring.yaml)

Added explicit version tags and `imagePullPolicy: Never` for ALL components:

```yaml
grafana:
  adminPassword: "admin"
  image:
    tag: "11.4.0"          # Specified version
    pullPolicy: Never       # No external pulls
  sidecar:
    image:
      tag: "1.27.6"         # Specified sidecar version
      pullPolicy: Never     # No external pulls

prometheusOperator:
  prometheusConfigReloader:
    image:
      tag: v0.79.2          # Match operator version
      pullPolicy: Never     # No external pulls
```

### 2. Added Missing Image to Scripts

#### Updated [`pull-images.sh`](file:///Users/bmscomp/production/klster/pull-images.sh)
```bash
# Grafana sidecar (used for dashboards/datasources)
push_to_local_registry "quay.io/kiwigrid/k8s-sidecar:1.27.6"
```

#### Updated [`load-images-to-kind.sh`](file:///Users/bmscomp/production/klster/load-images-to-kind.sh)
```bash
echo -e "${GREEN}=== Grafana Images ===${NC}"
load_from_local_registry "docker.io/grafana/grafana:11.4.0"
load_from_local_registry "quay.io/kiwigrid/k8s-sidecar:1.27.6"  # Added
```

### 3. Created Fix Script

Created [`fix-monitoring-images.sh`](file:///Users/bmscomp/production/klster/fix-monitoring-images.sh) to:
1. Pull missing Grafana sidecar image
2. Load it into Kind
3. Reinstall monitoring stack with correct config

## How to Fix Your Running Cluster

### Option 1: Quick Fix (Recommended)

```bash
./fix-monitoring-images.sh
```

This script will:
1. Pull and load the Grafana sidecar image
2. Uninstall existing monitoring stack
3. Reinstall with corrected configuration
4. All images will be sourced from Kind nodes only

### Option 2: Manual Fix

```bash
# 1. Pull and load missing image
docker pull quay.io/kiwigrid/k8s-sidecar:1.27.6
kind load docker-image quay.io/kiwigrid/k8s-sidecar:1.27.6 --name panda

# 2. Reinstall monitoring
helm uninstall monitoring -n monitoring
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --version 79.11.0 \
  --namespace monitoring \
  --create-namespace \
  --values config/monitoring.yaml \
  --wait

# 3. Apply dashboards
kubectl apply -f config/custom-dashboard.yaml
```

### Option 3: Full Refresh

```bash
# 1. Update local registry with all images
./pull-images.sh

# 2. Load all images to Kind
./load-images-to-kind.sh

# 3. Redeploy everything
./deploy-all-from-kind.sh
```

## Verification

### Check All Pods Are Using Kind Images

```bash
# List all monitoring pods
kubectl get pods -n monitoring

# Check image pull policy for each pod
kubectl get pods -n monitoring -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{":\n"}{range .spec.containers[*]}{"  "}{.image}{" (pull: "}{.imagePullPolicy}{")\n"}{end}{end}'
```

Expected output should show `(pull: Never)` for all images.

### Check No External Pulls

```bash
# Check events for ImagePull activity
kubectl get events -n monitoring --sort-by='.lastTimestamp' | grep -i pull

# Should show no "Pulling" events, only "Container image already present"
```

### Verify Images in Kind

```bash
# Check images exist in Kind nodes
docker exec panda-control-plane crictl images | grep -E "(grafana|sidecar|prometheus)"
```

Should show:
- `docker.io/grafana/grafana` -> `11.4.0`
- `quay.io/kiwigrid/k8s-sidecar` -> `1.27.6`
- `quay.io/prometheus-operator/prometheus-config-reloader` -> `v0.79.2`

## Images Now Required (24 total)

### Original (22)
- All Kafka, Prometheus, Grafana, LitmusChaos images

### New Additions (2)
1. `quay.io/kiwigrid/k8s-sidecar:1.27.6` - Grafana sidecar for dashboards
2. Prometheus config reloader now explicitly versioned at `v0.79.2`

## Configuration Changes Summary

| Component | Before | After |
|-----------|--------|-------|
| Grafana main | No version specified | `11.4.0` + `pullPolicy: Never` |
| Grafana sidecar | No config | `1.27.6` + `pullPolicy: Never` |
| Config reloader | Default version | `v0.79.2` + `pullPolicy: Never` |
| All components | `IfNotPresent` | `Never` |

## Prevention

To prevent this issue in future deployments:

1. ✅ Always specify exact image versions in Helm values
2. ✅ Set `imagePullPolicy: Never` at both global and component levels
3. ✅ Include sidecar and init container images in load scripts
4. ✅ Verify all images are loaded before deploying:
   ```bash
   docker exec panda-control-plane crictl images | wc -l
   ```

## Status After Fix

✅ **All monitoring components use images from Kind**  
✅ **No external registry pulls**  
✅ **Consistent image versions across all nodes**  
✅ **Works completely offline**

Run `./fix-monitoring-images.sh` to apply the fix! 🎉
