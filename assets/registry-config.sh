#!/bin/bash

# 1. Detect the Bridge IP (where the Bootc VM looks for the Bastion)
# We prioritize 'virbr-bootc'. If not found, we grab the primary host IP.
NEW_IP=$(ip -4 addr show virbr-bootc | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || ip route get 1 | awk '{print $7;exit}')

if [ -z "$NEW_IP" ]; then
    echo "❌ Error: Could not detect a valid Bastion IP."
    exit 1
fi

echo "🚀 Detected Bastion/Bridge IP: $NEW_IP"

# 2. Define files to update
CONFIG_FILE="assets/99-offline.conf"
IMAGE_LIST="image-list.txt"

# 3. The "Magic" Regex to match any IPv4 address or 'localhost'
# This matches: X.X.X.X or 'localhost'
IP_REGEX='([0-9]{1,3}\.){3}[0-9]{1,3}|localhost'

echo "🔧 Updating registry configurations..."

for FILE in "$CONFIG_FILE" "$IMAGE_LIST"; do
    if [ -f "$FILE" ]; then
        # Using sed with the regex to replace whatever is there with the NEW_IP
        # We use a different delimiter '|' because the IP doesn't contain it
        sed -i -E "s/$IP_REGEX/$NEW_IP/g" "$FILE"
        echo "✅ Updated $FILE"
    else
        echo "⚠️  Skipping $FILE (not found)"
    fi
done

echo "🏁 Environment is now configured for IP: $NEW_IP"
