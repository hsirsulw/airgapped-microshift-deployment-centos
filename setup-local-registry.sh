#!/bin/bash
set -e

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Starting Bastion Registry Setup (192.168.100.1)...${NC}"

# 1. Hostname Mapping
echo -e "${YELLOW}🔗 Mapping registry.local to 192.168.100.1...${NC}"
sed -i '/registry.local/d' /etc/hosts
echo "192.168.100.1 registry.local" >> /etc/hosts

# 2. Storage Setup
mkdir -p /opt/registry/data
chmod 755 /opt/registry/data

# 3. Launch Registry Container
if ! podman ps -a --format "{{.Names}}" | grep -q "^registry$"; then
    echo -e "${YELLOW}📦 Deploying registry container...${NC}"
    podman run -d --name registry \
        -p 5000:5000 \
        -v /opt/registry/data:/var/lib/registry:z \
        --restart always \
        docker.io/library/registry:2
else
    echo -e "${GREEN}✅ Registry container exists, ensuring it is started...${NC}"
    podman start registry 2>/dev/null || true
fi

# 4. Insecure Registry Config (Critical for Podman Push)
echo -e "${YELLOW}🔐 Configuring Podman to trust registry.local and IP...${NC}"
mkdir -p /etc/containers/registries.conf.d/
cat <<EOF > /etc/containers/registries.conf.d/insecure-registry.conf
[[registry]]
location = "registry.local:5000"
insecure = true

[[registry]]
location = "192.168.100.1:5000"
insecure = true
EOF

# 5. Verification
echo -e "${YELLOW}🧪 Verifying connectivity...${NC}"
sleep 2
if curl -s http://192.168.100.1:5000/v2/ > /dev/null; then
    echo -e "${GREEN}✅ Registry is alive at http://registry.local:5000${NC}"
else
    echo -e "${RED}❌ Registry not responding. Check 'podman logs registry'${NC}"
    exit 1
fi

echo -e "\n${GREEN}🎉 Setup Complete!${NC}"
echo -e "You can now push your image with:"
echo -e "${YELLOW}sudo podman push 192.168.100.1:5000/microshift-offiline:c9${NC}"
