#!/bin/bash

# 1. Setup Loopback LVM
BACKING_FILE="/var/lib/topolvm-backing-file"
VG_NAME="myvg1"

if ! vgs $VG_NAME >/dev/null 2>&1; then
    echo "Creating LVM Volume Group $VG_NAME..."
    mkdir -p /var/lib/microshift-storage
    truncate -s 20G $BACKING_FILE
    LOOP_DEV=$(losetup -f --show $BACKING_FILE)
    pvcreate $LOOP_DEV
    vgcreate $VG_NAME $LOOP_DEV
else
    LOOP_EXIST=$(losetup -j $BACKING_FILE | cut -d: -f1)
    if [ -z "$LOOP_EXIST" ]; then
        losetup -f $BACKING_FILE
    fi
    vgchange -ay $VG_NAME
fi

# 2. Setup Local DNS for the Registry
REGISTRY_DOMAIN="registry.local"
REGISTRY_IP="192.168.100.1"

# Clean up old entries and add fresh one
sed -i "/$REGISTRY_DOMAIN/d" /etc/hosts
echo "$REGISTRY_IP  $REGISTRY_DOMAIN" >> /etc/hosts
echo "✅ Added $REGISTRY_DOMAIN to /etc/hosts"

# 3. Setup Insecure Registry for Podman
REG_CONF="/etc/containers/registries.conf"

if [ -f "$REG_CONF" ]; then
    # Check if the registry is already marked as insecure
    if ! grep -q "$REGISTRY_DOMAIN:5000" "$REG_CONF"; then
        echo "Adding $REGISTRY_DOMAIN:5000 to insecure registries in $REG_CONF..."
        
        # Append the configuration to the end of the file
        cat <<EOF >> "$REG_CONF"

[[registry]]
location = "$REGISTRY_DOMAIN:5000"
insecure = true
EOF
    else
        echo "✅ $REGISTRY_DOMAIN:5000 already exists in $REG_CONF"
    fi
else
    echo "❌ Error: $REG_CONF not found. Is Podman installed?"
fi

echo "✅ Podman registry configuration complete."
