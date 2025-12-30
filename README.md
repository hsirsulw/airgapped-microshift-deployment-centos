# Airgapped MicroShift Deployment with bootc Embedded Containers

This repository provides a hands-on workshop and tooling for building offline-ready MicroShift systems using bootc (Bootable Container) images. By embedding MicroShift community edition and required container images directly into the OS image during build time, systems can start up fully functional without any network access or external registry pulls.

## Overview

Running Kubernetes workloads in disconnected, remote, or bandwidth-restricted environments is challenging—especially when cluster components and application images must be pulled before anything can start. MicroShift, a lightweight upstream-friendly Kubernetes distribution, is ideal for edge deployments but still depends on pulling images from a registry on first boot.

This project demonstrates a community-driven approach using bootc embedded containers to build offline-ready Linux OS images. Participants will learn how to:

- Understand how bootc enables immutable and reproducible Linux OS images
- Embed MicroShift community edition containers and app images inside the OS during build time
- Boot the system and run MicroShift instantly—no external registry required
- Use preloaded images for real workloads on day one
- Apply this workflow to any bootc-compatible Linux OS (Fedora, CentOS Stream, RHEL)
- Design offline-first appliances for ships at sea, mines, rural deployments, air-gapped environments, and industrial edge systems
- Maintain and update embedded-container images efficiently

## Prerequisites

- Linux host with podman or docker installed
- bootc CLI tool
- Access to container registries (for initial image pulls)
- Sufficient disk space for building images (several GB)
- Basic knowledge of containerization and Kubernetes

## Repository Structure

```
.
├── Containerfile*          # Main containerfile for building bootc image
├── Containerfile.4.20      # Specific to MicroShift 4.20
├── Containerfile.bcp       # Base containerfile variant
├── Containerfile.c10       # For CentOS 10 base image (used for bootc switch demos)
├── image-list.txt          # List of container images to embed
├── local-registry.sh       # Script to mirror images to local registry
├── setup-isolate-net.sh    # Script for isolated network setup
├── assets/                 # Network and configuration files
│   ├── 10-kindnet.conflist
│   ├── 13-microshift-kindnet.conf
│   └── 99-offline.conf
├── manifests/              # Kubernetes manifests for test apps
│   └── test-app.yaml
├── microshift-rpms-4.20x86_64/  # MicroShift RPM packages
├── rpms/                   # Additional RPM packages
├── scripts/                # Build and runtime scripts
│   ├── embed_image.sh      # Embeds images into /usr during build
│   ├── copy_embed.sh       # Copies embedded images to runtime storage
│   ├── microshift-embed.service  # Systemd service for image import
│   ├── setup.sh            # Storage and DNS setup
│   └── back_copy_embed.sh  # Backup copy script
└── output/                 # Build output directory
```

## Building the Bootc Image

1. **Clone the repository:**
   ```bash
   git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git
   cd airgapped-microshift-deployment-centos
   ```

2. **Prepare RPM packages:**
   - Ensure `microshift-rpms-4.20x86_64/` or `rpms/` directories contain the required MicroShift RPMs
   - The Containerfile will set up local repositories from these directories

3. **Build the image:**
   ```bash
   podman build -f Containerfile -t microshift-bootc:latest .
   ```

   Or specify a different MicroShift version:
   ```bash
   podman build --build-arg MS_VERSION=4.20 -f Containerfile -t microshift-bootc:4.20 .
   ```

4. **Create bootable disk image:**
   ```bash
   bootc install to-disk --image microshift-bootc:latest /dev/sdX
   ```
   Replace `/dev/sdX` with your target disk.

## Bootc Switch and Upgrade Demos

This repository includes `Containerfile.c10` for demonstrating bootc switch and upgrade capabilities with CentOS 10 as the base image. This showcases how easy it is to transition between different base images and versions:

```bash
# Build CentOS 10 variant
podman build -f Containerfile.c10 -t microshift-bootc:c10 .

# Switch running system to new image
sudo bootc switch localhost/microshift-bootc:c10
sudo bootc upgrade --apply
```

This demonstrates the power of bootc for seamless OS updates and transitions in disconnected environments.

## How Image Embedding Works

The build process embeds container images in two phases:

### Build Time (Containerfile)
- `embed_image.sh` downloads images from registries and stores them in `/usr/lib/containers/storage/`
- Images are stored in a directory format using skopeo
- A mapping file `image-list.txt` is created for runtime reference

### Runtime (Systemd Service)
- `microshift-embed.service` runs before MicroShift starts
- `copy_embed.sh` imports embedded images into podman's container storage
- MicroShift can then pull images locally without network access

## Usage

1. **Boot the system** from the created disk image
2. **MicroShift starts automatically** with embedded images
3. **Access the cluster:**
   ```bash
   export KUBECONFIG=/var/lib/microshift/resources/kubeadmin/kubeconfig
   kubectl get nodes
   kubectl get pods -A
   ```

4. **Deploy test applications:**
   - Test manifests are pre-installed in `/etc/microshift/manifests.d/`
   - Access the hello-world app at the configured route

## Configuration

### Networking
- Firewall rules are pre-configured for MicroShift ports
- Kindnet CNI is used for pod networking
- Isolated network setup script available for testing

### Storage
- TopoLVM is configured with loopback LVM (20GB backing file)
- Storage setup runs automatically on boot

### Embedded Images
- Modify `image-list.txt` to add/remove images to embed
- Images include MicroShift components, OLM, TopoLVM, and test applications

## Scripts Overview

- **`embed_image.sh`**: Downloads and stores images in build-time storage
- **`copy_embed.sh`**: Imports images to runtime container storage
- **`setup.sh`**: Configures LVM storage and DNS for demo routes
- **`local-registry.sh`**: Mirrors images to a local registry for air-gapped environments
- **`setup-isolate-net.sh`**: Sets up isolated network configuration

## Variants

- `Containerfile.4.20`: Specific to MicroShift 4.20
- `Containerfile.bcp`: Base containerfile variant
- `Containerfile.c10`: For CentOS 10 base image (bootc switch demos)

## Troubleshooting

- **Image embedding fails**: Check network connectivity and registry access during build
- **MicroShift won't start**: Verify systemd services are enabled and storage is set up
- **Pods can't pull images**: Ensure `microshift-embed.service` ran successfully
- **Large files warning**: Repository uses Git LFS for RPM files

## Contributing

Contributions welcome! Please open issues for bugs or feature requests.

## References

- [MicroShift Bootc Documentation](https://github.com/microshift-io/microshift/blob/main/docs/run-bootc.md)
- [MicroShift Build Guide](https://github.com/microshift-io/microshift/blob/main/docs/build.md)
- [Red Hat Build of MicroShift with Image Mode](https://docs.redhat.com/en/documentation/red_hat_build_of_microshift/4.20/html/installing_with_image_mode_for_rhel/creating-a-fully-self-contained-bootc-image)
- [Bootc Embedded Containers Reference](https://github.com/arthur-r-oliveira/bootc-embeeded-containers)
- [Red Hat Demo Platform MicroShift Showroom](https://github.com/rhpds/edge-applicances-rhim-microshift-showroom)

## License

This project is licensed under the Apache License 2.0.
