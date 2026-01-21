# Airgapped MicroShift Deployment with bootc Embedded Containers

## What is this Lab about?

This Lab demonstrates how to build **self-contained MicroShift appliances** that can run completely offline without any internet connectivity. By embedding MicroShift and all required container images directly into the OS image during build time, you create immutable, bootable systems that start up fully functional Kubernetes clusters instantly.

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
├── Containerfile*          # Main containerfile for building bootc image with Centos9 base image
├── Containerfile.c10       # For CentOS 10 base image (bootc switch demos)
├── image-list.txt          # List of container images to embed CentOs9
├── registry-images.txt          # List of container images to push local registry
├── image-centos10.txt          # List of container images to embed for CentOs 10
├── local-registry.sh       # Script to mirror images to local registry
├── setup-isolate-net.sh    # Script for isolated network setup
├── assets/                 # Network and configuration files
├── manifests/              # Kubernetes manifests for test apps
├── scripts/                # Build and runtime scripts
└── output/                 # Build output directory
```

## Step-by-Step: Building and Deploying

This hands-on lab guide walks you through building and deploying a complete MicroShift cluster in a bootc image.

### Step 1: Prepare Your Build Environment

```bash
# Clone the repository
git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git
cd airgapped-microshift-deployment-centos
```

```bash
# Create directories for different builds
mkdir output  # For CentOS 9 builds
```

---

## Prerequisites: Set Up Local Registry (Required Before Building)

Before proceeding with the build process, you must set up a local registry to store container images. This is essential for air-gapped deployments.

### Prerequisite 1: Create Local Registry and Pull Images

**On your build machine**, run the local registry setup script:

```bash
# Run the local registry script to create registry and populate with images
sudo bash ./local-registry.sh
```

**What this does:**
- Creates a local Docker registry container running on port 5000
- Pulls all required container images from `registry-images.txt`
- Stores them in the local registry for offline use

**Expected output:**
- Registry container should be running
- Images from `registry-images.txt` will be pulled and stored

### Prerequisite 2: Configure Registry in Containerfile

**From the repository root**, run the registry configuration script:

```bash
# Configure the registry IP in the offline configuration
sudo bash ./assets/registry-config.sh
```

**What this does:**
- Updates the `99-offline.conf` file with your local registry IP address
- Modifies the registry source to use the local registry instead of external sources

### Prerequisite 3: Verify Local Registry is Working

Verify that your local registry is accessible:

```bash
# Check registry catalog
curl http://<registry-ip>:5000/v2/_catalog
```

**Expected output:**
- JSON output showing available images in the registry

**Optional: Pull Images Directly (for testing)**

If you want to pull images from the local registry on your host system:

```bash
# Pull an image from the local insecure registry
podman pull http://<registry-ip>:5000/<image-name> --tls-verify false
```

**Note:** The `--tls-verify false` flag is used because the local registry is not configured with TLS certificates (insecure registry).

---

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
time sudo podman build -t microshift-offline:c9 .
```

This creates a container image containing:
- CentOS Stream 9 base OS
- MicroShift 4.21
- All required container images embedded
- Pre-configured services and networking

### Step 4: Generate Bootable QCOW2 Image

```bash
# Use bootc-image-builder to create a bootable disk image
time sudo podman run --rm -it --privileged \
  -v $(pwd)/output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 localhost/microshift-offline:c9
```

This generates a QCOW2 disk image in `./output/qcow2/disk.qcow2` that can be booted directly.

---

## Step 4b: Setup Isolated Network for bootc VM

Before creating the virtual machine, you must set up an isolated network that the bootc VM will use. This ensures the VM operates independently with proper network configuration.

```bash
# Create the isolated network for bootc VMs
sudo bash ./setup-isolate-net.sh
```

**What this does:**
- Creates a libvirt virtual network named `bootc-isolated`
- Configures network isolation for the MicroShift VM
- Sets up necessary network bridges for VM communication

**Expected output:**
- Network `bootc-isolated` is created and active
- Ready for VM deployment

---

### Step 5: Create and Start Virtual Machine

Give execute permissions to your home and code directory for the quemu user to enter your home directory:

```bash
sudo qemu-img resize ./output/qcow2/disk.qcow2 +30G
sudo mv ./output/qcow2/disk.qcow2 /var/lib/libvirt/images/microshift-workshop-4.21.qcow2
```

```bash
# Create VM using virt-install
sudo virt-install \
  --name microshift-workshop-4.21 \
  --vcpus 2 \
  --memory 4096 \
  --disk path=/var/lib/libvirt/images/microshift-workshop-4.21.qcow2,format=qcow2 \
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
# SSH into the running VM (replace <vm-ip> with actual IP from Step 6)
ssh centos@<vm-ip>
#password is bootc
```

### Step 8: Verify MicroShift Services

Once connected to the VM, verify that all services started correctly:

```bash
# Check that MicroShift started successfully
oc get nodes

# Verify systemd services are running
sudo systemctl status microshift-make-rshared.service
sudo systemctl status microshift-embed.service
sudo systemctl status microshift
```

**Expected output:**
- `oc get nodes` should show the node in Ready state
- All three systemd services should show `active (exited)` or `active (running)`

### Step 9: Configure Kubernetes Access

Set up the kubeconfig file to access your MicroShift cluster:

```bash
# Create .kube directory
mkdir -p ~/.kube

# Extract the kubeconfig from MicroShift
sudo cat /var/lib/microshift/resources/kubeadmin/kubeconfig > ~/.kube/config

# Restrict permissions to user only
chmod go-r ~/.kube/config
```

### Step 10: Verify Cluster Status

Confirm that your MicroShift cluster is fully operational:

```bash
# Check nodes
oc get nodes

# Check all pods in all namespaces
oc get pods -A
```

**Expected output:**
- You should see the node in `Ready` state
- Multiple pods should be in `Running` state across various namespaces

### Step 11: Deploy Test Application

Deploy a pre-configured test application:

```bash
# Apply the pre-installed test app manifest
oc apply -f /etc/microshift/manifests.d/001-test-app/test-app.yaml

# Verify the pod is running
oc get pods -A
oc get pods
```

### Step 12: Access the Application

Test the deployed application:

```bash
# Check available routes
oc get route

# Test the application endpoint
curl hello-route-default.apps.example.com
```

**Success indicator:**
You should see an HTTP response from the test application.

---

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

- `Containerfile`: Default CentOS 9 + MicroShift 4.21 (base image)
- `Containerfile.c10`: CentOS 10 base (for bootc switch demos)

---

## Advanced: Bootc Image Switching (CentOS 9 to CentOS 10)

This section demonstrates how to upgrade a running MicroShift system from CentOS 9 to CentOS 10 using bootc's atomic update capability. This shows the power of bootc for managing OS updates in production.

### Building the New Bootc Image (CentOS 10)

**On your build machine**, create the CentOS 10 variant:

```bash
# Build CentOS 10 variant with MicroShift
time sudo podman build -f Containerfile.c10 -t microshift-offline:c10
```

This creates a new container image based on CentOS Stream 10 with the same MicroShift configuration.

---

## Option 1: Offline Image Transfer Using podman save/load

Use this option for air-gapped environments or when direct registry access is not available.

### Step 1a: Export Image as Tar Archive

**On your build machine**, save the image to a tar file:

```bash
# Save the image to a tar archive
sudo podman save -o centos-10-microshift.tar localhost/microshift-offline:c10

# Verify the tar file was created
ls -lh centos-10-microshift.tar
```

**Expected output:**
- Large tar file created (typically 1-5GB depending on embedded images)
- File is ready for transfer

### Step 2a: Transfer Image to VM

**From your build machine**, copy the tar file to the VM:

```bash
# SCP the tar file to VM's /var/tmp directory
scp centos-10-microshift.tar centos@<vm-ip>:/var/tmp/
```

**Expected output:**
- File transfer progress shown
- Transfer completes successfully

### Step 3a: Load Image in VM

**Inside the MicroShift VM**, load the image into local storage:

```bash
# SSH into the VM
ssh centos@<vm-ip>
```

```bash
# Load the image from tar
sudo podman load -i /var/tmp/centos-10-microshift.tar
```

**Expected output:**
- Image is loaded into podman's storage
- Image is now available locally without network

### Step 4a: Switch Using Local Image

**Inside the VM**, perform the bootc switch using the local image:

```bash
# Switch to local image using containers-storage transport
sudo bootc switch --transport containers-storage localhost/microshift-offline:c10
```

**What happens:**
- bootc fetches the image from local storage (not network)
- Stages the image for next boot
- Does NOT reboot automatically

### Step 5a: Verify and Reboot

```bash
# Check bootc status before reboot
sudo bootc status
```

Reboot to apply the changes:

```bash
# Reboot to activate the new system
sudo reboot
```

### Step 6a: Reconnect and Verify

After reboot completes:

```bash
# Reconnect to the VM
ssh centos@<vm-ip>

# Verify OS version changed to CentOS 10
cat /etc/os-release

# Verify bootc shows new image as active
sudo bootc status

# Verify all MicroShift services are running
sudo systemctl status microshift-make-rshared.service
sudo systemctl status microshift-embed.service
sudo systemctl status microshift

# Verify cluster is operational
oc get nodes
oc get pods -A
```

---

## Option 2: Direct Registry-Based Switching (Network Available)

Use this option if your build machine and MicroShift VM are on the same network with registry access.

### Step 1b: Push Image to Local Registry

**On your build machine**, push the newly built image to your local registry:

```bash
# Tag the image with registry destination
sudo podman tag localhost/microshift-offline:c10 <local-registry:port>/microshift-offline:c10
```
# Push image to local registry
```bash
# Push to registry
sudo podman push <local-registry:port>/microshift-offline:c10
```

**Expected output:**
- Successfully pushed image to registry
- Image is now available for pulling from registry

### Step 2b: Switch the Running System

**Inside the MicroShift VM**, execute the bootc switch command:

```bash
# Switch to the new CentOS 10 image from registry
sudo bootc switch <local-registry:port>/microshift-offline:c10
```

**What happens:**
- bootc fetches the new image from the registry
- Stages it for the next boot
- Does NOT reboot automatically

### Step 3b: Verify and Reboot

```bash
# Check the current bootc status
sudo bootc status
```

**Expected output:**
- Current image: `microshift-offline:c10`
- Status shows staged/pending changes

Reboot to apply the changes:

```bash
# Reboot to activate the new system
sudo reboot
```

The system will boot with CentOS 10 and MicroShift running from the new image.

### Step 4b: Reconnect and Verify

After the reboot completes (wait ~2-3 minutes):

```bash
# Reconnect to the VM
ssh centos@<vm-ip>
#password is bootc

```

Verify the upgrade was successful:

```bash
# Check the OS version
cat /etc/os-release
# Should show CentOS Stream 10

# Check bootc status
sudo bootc status
# Should show microshift-offline:c10 as active

# Verify MicroShift services
sudo systemctl status microshift-make-rshared.service
sudo systemctl status microshift-embed.service
sudo systemctl status microshift

# Verify cluster is still operational
oc get nodes
oc get pods -A
```

---

## Comparison: Option 1 vs Option 2

| Aspect | Option 1 (Save/Load) | Option 2 (Registry) |
|--------|---------------------|----------------------|
| **Requires Network** | No | Yes (between VM and registry) |
| **Transfer Method** | Manual copy via tar | Direct pull from registry |
| **Speed** | Slower (file transfer) | Fast (if good network) |
| **Best For** | Air-gapped networks | Connected environments |
| **Complexity** | Higher | Lower |
| **Use Case** | Offline/disconnected labs | Production deployments |

---

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
