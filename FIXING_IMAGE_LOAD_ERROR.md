# Fixing Image Load Error: Content Digest Not Found

## Error Message
```
ERROR: failed to load image
ctr: content digest sha256:8d938a1c52b018c60cb3583657e038054387aa18a74f09a865c99a522481f7ac: not found
```

## Root Cause

This error occurs when an image has corrupted or missing layer data in local Docker. This typically happens when:
- Image was partially pulled
- Docker cache is corrupted
- Multi-arch image manifest issues

## Quick Fix Options

### Option 1: Run the Fix Script (Recommended)

```bash
./fix-corrupted-images.sh
```

This script will:
1. Remove all images from local Docker
2. Pull fresh copies from remote registries
3. Load them into Kind with retry logic

### Option 2: Manual Fix for Specific Image

If you know which image is causing the issue:

```bash
# 1. Remove the corrupted image
docker rmi -f <image-name>

# 2. Pull fresh copy
docker pull <image-name>

# 3. Load into Kind
kind load docker-image <image-name> --name panda
```

### Option 3: Clean Everything and Start Fresh

```bash
# 1. Remove ALL images from local Docker
docker image prune -a -f

# 2. Pull fresh copies of all required images
./pull-images.sh

# 3. Load into Kind
./load-images-to-kind.sh
```

## Prevention

To prevent this in the future:

1. **Always pull with --platform flag** for multi-arch images:
   ```bash
   docker pull --platform linux/amd64 <image>
   ```

2. **Check Docker disk space**:
   ```bash
   docker system df
   docker system prune -a  # Clean up if needed
   ```

3. **Use the fix scripts** which have retry logic built-in

## Verification

After fixing, verify images loaded correctly:

```bash
# Check images in Kind
docker exec panda-control-plane crictl images

# Count images
docker exec panda-control-plane crictl images | wc -l
```

Should show 24+ images loaded.

## Related Files

- [`fix-corrupted-images.sh`](file:///Users/bmscomp/production/klster/fix-corrupted-images.sh) - Automated fix script
- [`load-images-to-kind.sh`](file:///Users/bmscomp/production/klster/load-images-to-kind.sh) - Normal image loading
- [`pull-images.sh`](file:///Users/bmscomp/production/klster/pull-images.sh) - Pull from remote registries
