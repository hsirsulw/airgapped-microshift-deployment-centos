#!/bin/bash
set -euo pipefail

LIST_FILE="/usr/lib/containers/storage/image-list.txt"

if [ ! -f "$LIST_FILE" ]; then
    echo "Image list not found, skipping import."
    exit 0
fi

echo "Starting image import from local storage..."

# Use a more robust loop to handle potential empty lines
while IFS="," read -r img folder || [ -n "$img" ]; do
    # 1. Skip empty lines or comments
    [[ -z "$img" || "$img" =~ ^# ]] && continue

    # 2. Safety Check: Ensure the folder variable isn't empty
    if [ -z "$folder" ]; then
        echo "Warning: No storage folder specified for $img, skipping."
        continue
    fi

    # 3. Safety Check: Ensure the physical directory exists
    if [ ! -d "/usr/lib/containers/storage/$folder" ]; then
        echo "Error: Directory /usr/lib/containers/storage/$folder not found for $img"
        continue
    fi

    echo "Importing $img..."
    # We use || true so one failed image doesn't stop the whole cluster from starting
    skopeo copy --preserve-digests \
        "dir:/usr/lib/containers/storage/${folder}" \
        "containers-storage:${img}" || echo "Failed to import $img"

done < "$LIST_FILE"
