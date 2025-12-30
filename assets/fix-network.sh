#!/bin/bash
# Check if a default route already exists to avoid conflicts
if ! ip route | grep -q default; then
    echo "No default route found. Adding gateway for MicroShift..."
    # Attempt to add the .1 gateway on the first active ethernet interface
    INTERFACE=$(ip -4 route show | grep kernel | awk '{print $3}' | head -n1)
    ip route add default via 192.168.100.1 dev "$INTERFACE" || true
else
    echo "Default route already exists. Skipping."
fi
