#!/bin/bash

# Configuration
REGISTRY="localhost:5000"
IMAGE_LIST="image-list.txt"

# 1. Check if image list exists
if [ ! -f "$IMAGE_LIST" ]; then
    echo "Error: $IMAGE_LIST not found!"
    exit 1
fi

# 2. Check if local registry is reachable
if ! curl -s "http://$REGISTRY/v2/" > /dev/null; then
    echo "Error: Local registry at $REGISTRY is not reachable."
    echo "Make sure your registry container is running: podman start workshop-registry"
    exit 1
fi

echo "🚀 Starting synchronization to $REGISTRY..."
echo "------------------------------------------"

# 3. Loop through images
while read -r IMAGE; do
    # Skip empty lines or comments
    [[ -z "$IMAGE" || "$IMAGE" =~ ^# ]] && continue

    echo "📦 Mirroring: $IMAGE"
    
    # Strip the original registry part for the destination path
    # e.g., quay.io/okd/scos-content -> okd/scos-content
    DEST_PATH="${IMAGE#*/}"

    # Perform the copy
    # --all: Keep all architectures (Manifest List)
    # --preserve-digests: Ensure the SHA doesn't change
    # --format v2s2: Upgrade old images to modern schema to prevent 500 errors
    skopeo copy --all \
        --preserve-digests \
        --format v2s2 \
        --dest-tls-verify=false \
        docker://"$IMAGE" \
        docker://"$REGISTRY/$DEST_PATH"

    if [ $? -eq 0 ]; then
        echo "✅ Successfully mirrored $IMAGE"
    else
        echo "❌ Failed to mirror $IMAGE"
    fi
    echo "------------------------------------------"

done < "$IMAGE_LIST"

echo "🏁 Mirroring complete!"
