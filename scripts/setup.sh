#!/bin/bash
# 1. Setup Loopback LVM (15GB to satisfy 10GB spare requirement)
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
    # Ensure loop device is attached after reboot
    LOOP_EXIST=$(losetup -j $BACKING_FILE | cut -d: -f1)
    if [ -z "$LOOP_EXIST" ]; then
        losetup -f $BACKING_FILE
    fi
    vgchange -ay $VG_NAME
fi

# 2. Setup Local DNS for the Demo Route
# Wait up to 30 seconds for an IP to be assigned
MAX_RETRIES=30
RETRY_COUNT=0
PRIMARY_IP=""

while [ -z "$PRIMARY_IP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Try getting the IP, ensuring we grab the first non-loopback address
    PRIMARY_IP=$(hostname -I | awk '{print $1}')
    
    if [ -z "$PRIMARY_IP" ]; then
        echo "Waiting for network IP... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 1
        ((RETRY_COUNT++))
    fi
done

if [ -z "$PRIMARY_IP" ]; then
    echo "❌ Error: Could not detect Primary IP after $MAX_RETRIES seconds."
    exit 1
fi

DOMAIN="hello-route-default.apps.example.com"

# Remove any old entries for this domain and add the fresh one
sed -i "/$DOMAIN/d" /etc/hosts
echo "$PRIMARY_IP  $DOMAIN" >> /etc/hosts
