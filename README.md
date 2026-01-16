# Airgapped MicroShift Deployment with bootc Embedded Containers

## What is this project about?

This project demonstrates how to build **self-contained MicroShift appliances** that can run completely offline without any internet connectivity. By embedding MicroShift and all required container images directly into the OS image during build time, you create immutable, bootable systems that start up fully functional Kubernetes clusters instantly.

## Why do we need this? (The Disconnected Environment Challenge)

Traditional Kubernetes deployments require pulling container images from registries on first boot. In disconnected, remote, or bandwidth-restricted environments like:

- **Ships at sea** - No internet connectivity
- **Remote mines** - Limited bandwidth and connectivity
- **Military deployments** - Air-gapped networks
- **Industrial edge systems** - Isolated networks
- **Rural deployments** - Unreliable internet

This creates significant challenges:
- **Boot failures** when images can't be pulled
- **Long startup times** waiting for image downloads
- **Dependency on external registries** that may be unavailable
- **Security concerns** with pulling from untrusted registries

**Solution**: Embed everything needed directly into the OS image during build time.

## How it works (Architecture Overview)

The build process creates a "physically-bound" bootc image containing:

1. **Base OS** (CentOS Stream 9)
2. **MicroShift** (lightweight Kubernetes)
3. **All container images** pre-downloaded and embedded
4. **Application manifests** ready to deploy
5. **Network and storage configuration**

When the system boots:
- MicroShift starts automatically
- Embedded images are imported to local storage
- Applications deploy instantly
- **No network calls required**

## Repository Structure

```
.
├── Containerfile*          # Main containerfile for building bootc image
├── Containerfile.4.20      # Specific to MicroShift 4.20
├── Containerfile.bcp       # Base containerfile variant
├── Containerfile.c10       # For CentOS 10 base image (bootc switch demos)
├── image-list.txt          # List of container images to embed
├── local-registry.sh       # Script to mirror images to local registry
├── setup-isolate-net.sh    # Script for isolated network setup
├── assets/                 # Network and configuration files
├── manifests/              # Kubernetes manifests for test apps
├── microshift-rpms-4.20x86_64/  # MicroShift RPM packages
├── rpms/                   # Additional RPM packages
├── scripts/                # Build and runtime scripts
└── output/                 # Build output directory
```

## Step-by-Step: Building and Deploying

### Step 1: Prepare Your Build Environment

```bash
# Clone the repository
git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git
cd airgapped-microshift-deployment-centos

# Create directories for different builds
mkdir 9centos  # For CentOS 9 builds
```

### Step 2: Examine the Containerfile

The Containerfile defines how the bootc image is built:

```bash
cat Containerfile
```

Key components in the Containerfile:
- **Base image**: `quay.io/centos-bootc/centos-bootc:stream9`
- **MicroShift installation** from local RPMs
- **Image embedding** using `embed_image.sh`
- **Systemd services** for runtime setup
- **Network and firewall configuration**

### Step 3: Build the Bootc Image

```bash
# Build the container image
sudo podman build -t microshift-bootc9:4.21 .
```

This creates a container image containing:
- CentOS Stream 9 base OS
- MicroShift 4.21
- All required container images embedded
- Pre-configured services and networking

### Step 4: Generate Bootable QCOW2 Image

```bash
# Use bootc-image-builder to create a bootable disk image
sudo podman run --rm -it --privileged \
  -v $(pwd)/9centos:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 localhost/microshift-bootc9:4.21
```

This generates a QCOW2 disk image in `./9centos/qcow2/disk.qcow2` that can be booted directly.

### Step 5: Create and Start Virtual Machine

```bash
# Create VM using virt-install
sudo virt-install \
  --name microshift-workshop-4.21 \
  --vcpus 2 \
  --memory 4096 \
  --disk path=./9centos/qcow2/disk.qcow2,format=qcow2 \
  --network network=bootc-isolated,model=virtio \
  --import \
  --os-variant centos-stream9 \
  --graphics none \
  --noautoconsole
```

### Step 6: Verify VM is Running

```bash
# Check VM status
sudo virsh list --all
sudo virsh domifaddr microshift-workshop-4.21
```

### Step 7: Connect to the MicroShift VM

```bash
# SSH into the running VM (IP will vary)
ssh hrushabh@192.168.100.151
```

## Step-by-Step: Using MicroShift in the VM

### Configure Kubernetes Access

```bash
# Set up kubeconfig
mkdir -p ~/.kube
sudo cat /var/lib/microshift/resources/kubeadmin/kubeconfig > ~/.kube/config
chmod go-r ~/.kube/config
```

### Verify MicroShift Services

```bash
# Check that MicroShift started successfully
oc get nodes

# Verify systemd services
sudo systemctl status microshift-make-rshared.service
sudo systemctl status microshift-embed.service
sudo systemctl status microshift
```

### Deploy Test Application

```bash
# Apply the pre-installed test app
oc apply -f /etc/microshift/manifests.d/001-test-app/test-app.yaml

# Check pod status
oc get pods
```

### Access the Application

```bash
# Check routes
oc get route

# Add hostname to /etc/hosts if needed
sudo vi /etc/hosts
# Add: 127.0.0.1 hello-route-default.apps.example.com

# Test the application
curl hello-route-default.apps.example.com
```

## Understanding the Key Components

### Containerfile Breakdown

The Containerfile performs these critical steps:

1. **Setup repositories** for MicroShift RPMs
2. **Install MicroShift** and dependencies
3. **Embed container images** using `embed_image.sh`
4. **Configure networking** and firewall rules
5. **Set up systemd services** for automatic startup

### Image Embedding Process

**Build Time:**
- `embed_image.sh` downloads images from `image-list.txt`
- Stores them in `/usr/lib/containers/storage/`
- Creates mapping file for runtime import

**Runtime:**
- `microshift-embed.service` runs before MicroShift
- `copy_embed.sh` imports images to podman's storage
- MicroShift can pull images locally without network

### Systemd Services

- `microshift-embed.service`: Imports embedded images
- `microshift-storage-setup.service`: Configures storage
- `fix-network.service`: Sets up networking
- `microshift-make-rshared.service`: Mount configuration

## Variants and Use Cases

### Containerfile Variants

- `Containerfile`: Default CentOS 9 + MicroShift 4.21
- `Containerfile.4.20`: CentOS 9 + MicroShift 4.20
- `Containerfile.c10`: CentOS 10 base (for bootc switch demos)

### Bootc Switch Demonstration

Please exit the virtual machine and come back onto your build machine.

```bash
# Build CentOS 10 variant
sudo podman build -f Containerfile.c10 -t microshift-bootc:c10

# Switch running system
sudo bootc switch localhost/microshift-bootc:c10
sudo bootc upgrade --apply
```

## Troubleshooting

### Common Issues

**Build fails:**
- Ensure you have sufficient disk space (20GB+)
- Check network connectivity for initial image pulls
- Verify RPM packages are present in local directories

**VM won't start:**
- Check QCOW2 image was generated correctly
- Verify libvirt network exists
- Ensure sufficient RAM/CPU allocated

**MicroShift won't start:**
- Check `sudo journalctl -u microshift` for logs
- Verify embedded images were imported
- Check storage and network configuration

**Application won't deploy:**
- Ensure kubeconfig is set up correctly
- Check pod logs: `oc logs <pod-name>`
- Verify routes and services

### Useful Commands

```bash
# Check MicroShift status
sudo systemctl status microshift

# View MicroShift logs
sudo journalctl -u microshift -f

# Check embedded image import
sudo journalctl -u microshift-embed.service

# Verify container images
sudo podman images
```

## References

- [MicroShift Documentation](https://microshift.io/)
- [Bootc Documentation](https://docs.fedoraproject.org/en-US/bootc/)
- [Red Hat Image Mode](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/composing_installing_and_managing_rhel_for_the_edge/getting-started-with-bootc_composing-rhel-for-the-edge)

## License

Apache License 2.0
