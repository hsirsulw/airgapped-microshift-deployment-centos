#!/bin/bash
#
# Script to create an isolated KVM network (no internet access)
# and optionally attach a VM to it
#

set -e

# Configuration
NETWORK_NAME="bootc-isolated"
BRIDGE_NAME="virbr-bootc"
NETWORK_IP="192.168.100.1"
NETWORK_NETMASK="255.255.255.0"
NETWORK_RANGE_START="192.168.100.2"
NETWORK_RANGE_END="192.168.100.254"
NETWORK_XML="/tmp/${NETWORK_NAME}.xml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

# Check if network already exists (defined or active)
if virsh net-info "${NETWORK_NAME}" &>/dev/null || virsh net-list --all --name | grep -q "^${NETWORK_NAME}$"; then
    print_warn "Network '${NETWORK_NAME}' already exists"
    read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Destroying existing network..."
        # Try to destroy if active
        if virsh net-destroy "${NETWORK_NAME}" &>/dev/null; then
            print_info "Network destroyed"
        fi
        # Undefine the network
        if virsh net-undefine "${NETWORK_NAME}" &>/dev/null; then
            print_info "Network undefined"
        fi
    else
        print_info "Exiting without changes"
        exit 0
    fi
fi

# Create network XML file
print_info "Creating isolated network XML definition..."
cat > "${NETWORK_XML}" <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='none'/>
  <bridge name='${BRIDGE_NAME}' stp='on' delay='0'/>
  <ip address='${NETWORK_IP}' netmask='${NETWORK_NETMASK}'>
    <dhcp>
      <range start='${NETWORK_RANGE_START}' end='${NETWORK_RANGE_END}'/>
    </dhcp>
  </ip>
</network>
EOF

print_info "Network XML created at ${NETWORK_XML}"

# Define the network
print_info "Defining network '${NETWORK_NAME}'..."
virsh net-define "${NETWORK_XML}"

# Start the network
print_info "Starting network '${NETWORK_NAME}'..."
virsh net-start "${NETWORK_NAME}"

# Set network to autostart
print_info "Setting network '${NETWORK_NAME}' to autostart..."
virsh net-autostart "${NETWORK_NAME}"

# Verify network is active
if virsh net-info "${NETWORK_NAME}" | grep -q "Active:.*yes"; then
    print_info "Network '${NETWORK_NAME}' is now active and isolated (no internet access)"
    print_info "Network details:"
    virsh net-info "${NETWORK_NAME}"
    echo
    print_info "Network IP range: ${NETWORK_RANGE_START} - ${NETWORK_RANGE_END}"
    print_info "Gateway/DNS: ${NETWORK_IP}"
else
    print_error "Failed to start network"
    exit 1
fi

# Clean up temporary XML file
rm -f "${NETWORK_XML}"

print_info "Isolated network setup complete!"
print_info "To use this network in create-vm.sh, set NETNAME='${NETWORK_NAME}'"
