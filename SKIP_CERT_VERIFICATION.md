# Skipping Certificate Verification for Local Registry

This guide explains how to configure your environment to skip TLS certificate verification when working with the local Docker registry at `localhost:5001`.

## Why This Is Needed

The local registry at `localhost:5001` runs over HTTP (not HTTPS) and doesn't have valid TLS certificates. To use it, you need to configure:

1. **Docker daemon** - to allow insecure connections to `localhost:5001`
2. **Kind cluster** - to skip TLS verification when pulling images
3. **containerd** (in Kind nodes) - to trust the insecure registry

## Quick Setup

### Option 1: Automated Configuration (Recommended)

Run the configuration script:

```bash
./configure-insecure-registry.sh
```

This script will:
- Update or create `~/.docker/daemon.json`
- Add `localhost:5001` to `insecure-registries`
- Backup existing configuration

**Then restart Docker:**
```bash
# macOS with Docker Desktop
# -> Restart from Docker Desktop menu

# Or use the restart script
./restart-docker.sh
```

### Option 2: Manual Configuration

#### 1. Configure Docker Daemon

Edit `~/.docker/daemon.json` (create if doesn't exist):

```json
{
  "insecure-registries": [
    "localhost:5001"
  ]
}
```

**Restart Docker after making changes.**

#### 2. Verify Configuration

```bash
# Check daemon config
cat ~/.docker/daemon.json

# Test registry access
curl http://localhost:5001/v2/_catalog

# Test docker pull
docker pull localhost:5001/provectuslabs/kafka-ui:latest
```

## Kind Cluster Configuration

The Kind cluster is already configured to skip TLS verification via [`config/cluster.yaml`](file:///Users/bmscomp/production/klster/config/cluster.yaml):

```yaml
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5001"]
    endpoint = ["http://localhost:5001"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs."localhost:5001".tls]
    insecure_skip_verify = true
```

This configures containerd (the container runtime in Kind) to:
- Use HTTP (not HTTPS) for `localhost:5001`
- Skip TLS certificate verification
- Trust the insecure registry

## Using Images from Kind (No Registry Verification Needed)

Since all configurations now use `imagePullPolicy: Never`, Kubernetes doesn't pull from any registry:

```yaml
# Example from config/kafka-ui.yaml
containers:
- name: kafka-ui
  image: provectuslabs/kafka-ui:latest
  imagePullPolicy: Never  # Uses image already in Kind, no registry access
```

**No certificate verification happens** because images are used directly from Kind nodes!

## Workflow with Insecure Registry

### 1. Setup Registry (One Time)
```bash
./setup-registry.sh
```

### 2. Configure Insecure Access (One Time)
```bash
./configure-insecure-registry.sh
# Then restart Docker
```

### 3. Populate Registry from Remote
```bash
./pull-images.sh
```
- Pulls from public registries (quay.io, docker.io, etc.)
- Pushes to local `localhost:5001` (HTTP, no TLS)

### 4. Load Images into Kind
```bash
./load-images-to-kind.sh
```
- Pulls from local registry `localhost:5001` (HTTP, insecure)
- Loads into Kind cluster nodes
- Skips images already in Kind

### 5. Deploy Services
```bash
./deploy-all-from-kind.sh
```
- Uses images from Kind nodes only (`imagePullPolicy: Never`)
- **No registry access or certificate verification**

## Troubleshooting

### Error: "x509: certificate has expired" or "certificate signed by unknown authority"

**Cause**: Docker trying to use HTTPS for localhost:5001  
**Solution**:
```bash
# 1. Configure insecure registry
./configure-insecure-registry.sh

# 2. Restart Docker
./restart-docker.sh

# 3. Verify
docker info | grep -A 5 "Insecure Registries"
```

### Error: "http: server gave HTTP response to HTTPS client"

**Cause**: Docker/containerd trying HTTPS for HTTP registry  
**Solution**: Already configured in `cluster.yaml` with `insecure_skip_verify = true`

### Error: "ErrImagePull" in Kubernetes

**Cause**: Image not loaded in Kind  
**Solution**:
```bash
# Load missing image
./load-images-to-kind.sh

# Or manually
docker pull localhost:5001/<image>
kind load docker-image <image> --name panda
```

### Verify Registry is Insecure

```bash
# Check Docker daemon config
docker info | grep -A 5 "Insecure Registries"

# Should show:
#  Insecure Registries:
#   localhost:5001
#   127.0.0.0/8
```

### Verify Kind Cluster Config

```bash
# Check containerd config in Kind node
docker exec panda-control-plane cat /etc/containerd/config.toml | grep -A 5 localhost:5001

# Should show insecure_skip_verify = true
```

## Security Notes

⚠️ **Local Development Only**

These configurations are **ONLY** safe for local development:
- Registry is on localhost (not exposed to network)
- Used for development/testing, not production
- Images are from trusted sources (pulled from official registries first)

✅ **Safe because:**
- Registry accessible only on localhost
- Images verified when pulled from original sources
- Local network only, no external exposure

❌ **Do NOT use in production:**
- Never disable TLS verification for external registries
- Never expose insecure registry to network
- Never use in production Kubernetes clusters

## Files Modified

1. **[`configure-insecure-registry.sh`](file:///Users/bmscomp/production/klster/configure-insecure-registry.sh)** - NEW: Configure Docker for insecure registry
2. **[`config/cluster.yaml`](file:///Users/bmscomp/production/klster/config/cluster.yaml)** - Containerd config for insecure registry
3. **`~/.docker/daemon.json`** - Docker daemon insecure registries config

## Complete Workflow Summary

```bash
# 1. Setup (one time)
./configure-insecure-registry.sh
# -> Restart Docker Desktop

# 2. Start registry and populate
./setup-registry.sh
./pull-images.sh

# 3. Load to Kind
./load-images-to-kind.sh

# 4. Deploy (uses images from Kind, no registry access)
./deploy-all-from-kind.sh
```

After step 3, **no certificate verification is needed** because all deployments use `imagePullPolicy: Never` to use images already in Kind! 🎉
