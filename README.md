# Airgapped MicroShift Deployment Workshop

This workshop demonstrates building offline-ready MicroShift systems using bootc embedded containers. By embedding MicroShift community edition and required container images directly into the OS image during build time, systems can start up fully functional without any network access or external registry pulls.

## Workshop Overview

Running Kubernetes workloads in disconnected, remote, or bandwidth-restricted environments is challenging—especially when cluster components and application images must be pulled before anything can start. MicroShift, a lightweight upstream-friendly Kubernetes distribution, is ideal for edge deployments but still depends on pulling images from a registry on first boot.

This workshop demonstrates a community-driven approach using bootc embedded containers to build offline-ready Linux OS images. Participants will learn how to:

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

## Workshop Modules

### Module 1: Foundation - Environment Setup & Bootc Basics

**Objective:** Understand the edge challenge and get familiar with bootc image mode fundamentals.

**Topics covered:**
- The Edge Challenge: Bandwidth constraints and disconnected environments
- Introduction to bootc and image mode
- Workshop environment setup
- Helper files and repository structure

**Hands-on exercises:**
- Clone the repository and explore the structure
- Understand the MicroShift RPM packages and container images
- Review the embedded container workflow

### Module 2: Building the Appliance (v4.19/v4.20)

**Objective:** Learn how to build bootc images with embedded MicroShift and applications.

**Topics covered:**
- Physically-bound images: Ship it with the bootc image
- Containerfile structure and variants
- Building different MicroShift versions
- Embedding container images during build time

**Hands-on exercises:**
- Build the base MicroShift bootc image
- Embed MicroShift payload and application containers
- Create ISO images for deployment
- Test image building with different Containerfile variants

### Module 3: Deploying the Appliance

**Objective:** Deploy and boot the self-contained MicroShift appliance.

**Topics covered:**
- Boot the system from embedded ISO
- MicroShift automatic startup
- Runtime image import process
- Accessing the MicroShift cluster

**Hands-on exercises:**
- Create a test VM environment
- Boot from the generated ISO
- Verify MicroShift cluster startup
- Deploy test applications from embedded manifests

### Module 4: Bootc Switch & Updates

**Objective:** Demonstrate bootc's upgrade and switching capabilities in disconnected environments.

**Topics covered:**
- Bootc switch vs traditional updates
- Atomic updates with embedded containers
- CentOS 10 base image demonstrations
- Seamless OS transitions

**Hands-on exercises:**
- Build CentOS 10 variant with Containerfile.c10
- Perform bootc switch operations
- Demonstrate atomic upgrades
- Show the ease of OS transitions

### Module 5: Advanced Scenarios & Conclusion

**Objective:** Explore advanced use cases and wrap up the workshop.

**Topics covered:**
- Local registry setup for air-gapped environments
- Isolated network configurations
- Troubleshooting common issues
- Production deployment considerations

**Hands-on exercises:**
- Set up local container registry
- Configure isolated networking
- Deploy complex applications
- Workshop recap and Q&A

## Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/hsirsulw/airgapped-microshift-deployment-centos.git
   cd airgapped-microshift-deployment-centos
   ```

2. **Build the base image:**
   ```bash
   podman build -f Containerfile -t microshift-bootc:latest .
   ```

3. **Create bootable ISO:**
   ```bash
   bootc install to-disk --image microshift-bootc:latest /dev/sdX
   ```

4. **Boot and access MicroShift:**
   ```bash
   export KUBECONFIG=/var/lib/microshift/resources/kubeadmin/kubeconfig
   kubectl get nodes
   ```

## Bootc Switch Demonstration

This repository includes `Containerfile.c10` for demonstrating bootc switch and upgrade capabilities:

```bash
# Build CentOS 10 variant
podman build -f Containerfile.c10 -t microshift-bootc:c10 .

# Switch running system to new image
sudo bootc switch localhost/microshift-bootc:c10
sudo bootc upgrade --apply
```

## How Image Embedding Works

### Build Time (Containerfile)
- `embed_image.sh` downloads images from registries and stores them in `/usr/lib/containers/storage/`
- Images are stored in a directory format using skopeo
- A mapping file `image-list.txt` is created for runtime reference

### Runtime (Systemd Service)
- `microshift-embed.service` runs before MicroShift starts
- `copy_embed.sh` imports embedded images into podman's container storage
- MicroShift can then pull images locally without network access

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
