#!/bin/bash
# Corrected build-time script for CentOS 10
while read -r LINE; do
    # Skip empty lines
    [[ -z "$LINE" ]] && continue

    # Clean the image name (remove commas or extra data from the line)
    IMAGE=$(echo "$LINE" | cut -d',' -f1)
    
    # Create a unique folder name
    DIR_NAME=$(echo "$IMAGE" | tr ':/@' '_')

    echo "------------------------------------------------------"
    echo "Embedding Image: $IMAGE"
    echo "Target Directory: /usr/lib/containers/storage/$DIR_NAME"

    mkdir -p "/usr/lib/containers/storage/$DIR_NAME"

    # CRITICAL FIX: Added // after docker:
    if skopeo copy --preserve-digests --all\
        docker://"$IMAGE" \
        dir:/usr/lib/containers/storage/"$DIR_NAME"; then
        
        # Save the mapping for the runtime script
        echo "$IMAGE,$DIR_NAME" >> /usr/lib/containers/storage/image-list.txt
        echo "Successfully embedded $IMAGE"
    else
        echo "FAILED to embed $IMAGE"
        exit 1
    fi
done < "$1"
