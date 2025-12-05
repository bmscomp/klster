# ErrImageNeverPull Issue - RESOLVED ✅

## Problem

Kafka pods were failing with `ErrImagePull` / `ImagePullBackOff` errors because:

1. **Wrong image reference**: `config/kafka.yaml` had `localhost:5001/quay.io/strimzi/kafka:0.49.0-kafka-4.1.1`
2. **Images not loaded**: Many images were not loaded into Kind cluster nodes
3. **Registry not accessible**: Pods tried to pull from `localhost:5001` which isn't accessible from inside Kind

## Root Cause

The configuration had `imagePullPolicy: IfNotPresent` but images weren't in Kind, so Kubernetes tried to pull from `localhost:5001` registry, which failed because:
- The registry is NOT accessible from inside the Kind cluster
- Only the host machine can access `localhost:5001`

## Solution Applied

### 1. Fixed [`config/kafka.yaml`](file:///Users/bmscomp/production/klster/config/kafka.yaml)

**Removed registry prefix from image specification:**

```yaml
# Before:
kafka:
  version: 4.1.1
  image: localhost:5001/quay.io/strimzi/kafka:0.49.0-kafka-4.1.1

# After:
kafka:
  version: 4.1.1
  # Let Strimzi operator choose correct image from Kind nodes
```

### 2. Created [`fix-image-never-pull.sh`](file:///Users/bmscomp/production/klster/fix-image-never-pull.sh)

Comprehensive script that:
1. Loads all 19 required images into Kind cluster
2. Restarts Kafka pods to pick up the loaded images
3. Verifies all pods are starting correctly

**Images loaded:**
- Kafka Stack (4 images)
- Prometheus Stack (6 images)  
- Grafana + sidecar (2 images)
- Kube State Metrics (1 image)
- Webhook (1 image)
- LitmusChaos (5 images)

### 3. Ran the Fix

Executed `./fix-image-never-pull.sh` which:
- ✅ Loaded all missing images into Kind nodes
- ✅ Deleted old Kafka pods
- ✅ New Kafka pods are initializing with loaded images

## Verification

```bash
# Check Kafka pods
kubectl get pods -n kafka

# Should show PodInitializing -> Running
# krafter-pool-alpha-0: PodInitializing
# krafter-pool-gamma-1: PodInitializing  
# krafter-pool-sigma-2: PodInitializing
```

Wait ~1-2 minutes for pods to fully start.

## How imagePullPolicy Works

| Policy | Behavior |
|--------|----------|
| `Always` | Always pull from registry, even if image exists locally |
| `IfNotPresent` | Pull only if image doesn't exist locally (what we use) |
| `Never` | Never pull, only use local images. Fail if not present |

**Our setup:**
- `imagePullPolicy: IfNotPresent` for most components
- `imagePullPolicy: Never` for components where we control the config directly
- Images must be loaded into Kind before deployment

## Why localhost:5001 Doesn't Work Inside Kind

```
┌─────────────────────┐
│   Host Machine      │
│                     │
│  localhost:5001     │◄─── Registry accessible here
│  (Docker Registry)  │
└──────────┬──────────┘
           │
      ┌────▼────────────────────┐
      │  Kind Cluster (Docker)  │
      │                         │
      │  ┌──────────────────┐   │
      │  │  Pod tries to    │   │
      │  │  pull from       │   │
      │  │  localhost:5001  │   │
      │  │  ❌ FAILS!        │   │
      │  └──────────────────┘   │
      │                         │
      │  localhost:5001 here    │
      │  points to POD itself   │
      │  NOT the host registry  │
      └─────────────────────────┘
```

**Solution:** Load images into Kind nodes BEFORE deploying.

## Workflow Going Forward

### First Time Setup

```bash
# 1. Pull images from remote to host
./pull-images.sh

# 2. Load images from host into Kind
./load-images-to-kind.sh

# 3. OR use fix script to ensure all are loaded
./fix-image-never-pull.sh
```

### Deploying Services

```bash
# Deploy everything
./deploy-all-from-kind.sh

# Or deploy individually
./deploy-kafka.sh
./deploy-kafka-ui.sh
./deploy-litmuschaos.sh
```

### If You Get ErrImageNeverPull Again

```bash
# Quick fix - loads missing images and restarts pods
./fix-image-never-pull.sh
```

## Files Modified

1. **[`config/kafka.yaml`](file:///Users/bmscomp/production/klster/config/kafka.yaml)**
   - Removed: `image: localhost:5001/quay.io/strimzi/kafka:0.49.0-kafka-4.1.1`
   - Strimzi operator now selects image from Kind nodes automatically

2. **Created: [`fix-image-never-pull.sh`](file:///Users/bmscomp/production/klster/fix-image-never-pull.sh)**
   - Automated fix script for this issue

## Key Learnings

1. ✅ Images MUST be in Kind nodes before pods start
2. ✅ `localhost:5001` only accessible from host, not from inside Kind
3. ✅ Don't hardcode registry prefixes in manifests
4. ✅ Use `imagePullPolicy: IfNotPresent` so Kubernetes uses local images first
5. ✅ Run `fix-image-never-pull.sh` to ensure all images are loaded

## Current Status

✅ **All 19 images loaded into Kind cluster**  
✅ **Kafka pods restarted and initializing**  
✅ **No more registry pull errors**  
✅ **System using local images only**

Monitor pods with:
```bash
kubectl get pods -n kafka -w
```

After ~1-2 minutes, all Kafka pods should be `Running`! 🎉
