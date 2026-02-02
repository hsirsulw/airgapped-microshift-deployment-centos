#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Setting up Local Registry for MicroShift...${NC}"
echo "=================================================="

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root or with sudo${NC}"
   exit 1
fi

# Step 1: Create registry storage directory
echo -e "${YELLOW}📁 Step 1: Creating registry storage directory...${NC}"
mkdir -p /opt/registry/data
chmod 755 /opt/registry/data
echo -e "${GREEN}✅ Registry storage directory created at /opt/registry/data${NC}"

# Step 2: Check if registry container already exists
echo -e "${YELLOW}📦 Step 2: Checking for existing registry container...${NC}"
if podman ps -a --format "{{.Names}}" | grep -q "^registry$"; then
    echo -e "${YELLOW}⚠️  Registry container already exists${NC}"
    if podman ps --format "{{.Names}}" | grep -q "^registry$"; then
        echo -e "${GREEN}✅ Registry container is already running${NC}"
    else
        echo -e "${YELLOW}Starting existing registry container...${NC}"
        podman start registry
        echo -e "${GREEN}✅ Registry container started${NC}"
    fi
else
    # Step 3: Launch the Registry container
    echo -e "${YELLOW}🐳 Step 3: Launching registry container...${NC}"
    podman run -d --name registry \
        -p 5000:5000 \
        -v /opt/registry/data:/var/lib/registry:z \
        --restart always \
        docker.io/library/registry:2
    
    echo -e "${GREEN}✅ Registry container launched on localhost:5000${NC}"
    
    # Give the registry a moment to start
    sleep 2
fi

# Step 4: Configure podman to trust local registry
echo -e "${YELLOW}🔐 Step 4: Configuring podman to trust local insecure registry...${NC}"
mkdir -p /etc/containers/registries.conf.d/
tee /etc/containers/registries.conf.d/insecure-registry.conf > /dev/null <<'EOF'
[[registry]]
location = "localhost:5000"
insecure = true
EOF
echo -e "${GREEN}✅ Registry trust configuration applied${NC}"

# Step 5: Verify registry is running
echo -e "${YELLOW}🔍 Step 5: Verifying registry is running...${NC}"
if podman ps | grep -q registry; then
    echo -e "${GREEN}✅ Registry container is running${NC}"
else
    echo -e "${RED}❌ Registry container is not running${NC}"
    exit 1
fi

# Step 6: Test registry connectivity
echo -e "${YELLOW}🧪 Step 6: Testing registry connectivity...${NC}"
if curl -s http://localhost:5000/v2/_catalog > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Registry is responding to requests${NC}"
    CATALOG=$(curl -s http://localhost:5000/v2/_catalog)
    echo -e "${GREEN}   Current catalog: $CATALOG${NC}"
else
    echo -e "${RED}❌ Registry is not responding${NC}"
    exit 1
fi

# Step 7: Run image mirroring script if it exists
echo -e "${YELLOW}📥 Step 7: Populating registry with images...${NC}"
if [ -f "local-registry.sh" ]; then
    echo -e "${YELLOW}Running local-registry.sh to mirror images...${NC}"
    bash ./local-registry.sh
    echo -e "${GREEN}✅ Image mirroring complete${NC}"
else
    echo -e "${YELLOW}⚠️  local-registry.sh not found in current directory${NC}"
    echo -e "${YELLOW}   Please run './local-registry.sh' manually after this setup${NC}"
fi

echo ""
echo "=================================================="
echo -e "${GREEN}🎉 Local registry setup complete!${NC}"
echo ""
echo "Registry Information:"
echo "  - Location: localhost:5000"
echo "  - Storage: /opt/registry/data"
echo "  - Type: Insecure (HTTP)"
echo ""
echo "Useful commands:"
echo "  - View registry catalog: curl http://localhost:5000/v2/_catalog"
echo "  - Push image: podman push <image> localhost:5000/<image>"
echo "  - Pull image: podman pull localhost:5000/<image>"
echo "  - Stop registry: sudo podman stop registry"
echo "  - Start registry: sudo podman start registry"
echo "  - View logs: sudo podman logs registry"
echo ""
