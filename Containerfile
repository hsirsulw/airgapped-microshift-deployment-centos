FROM quay.io/centos-bootc/centos-bootc:stream9

# --------------------------------------------------
# Global speed optimizations
# --------------------------------------------------
RUN echo "install_weak_deps=False" >> /etc/dnf/dnf.conf

ARG ARCH=x86_64
ENV MICROSHIFT_RPM_URL=https://github.com/microshift-io/microshift/releases/download/4.21.0_gbc8e20c07_4.21.0_okd_scos.ec.14/microshift-rpms-${ARCH}.tgz

# --------------------------------------------------
# Repositories (NO dnf config-manager)
# --------------------------------------------------
RUN printf "[openshift-mirror-beta]\n\
name=OpenShift Mirror Beta Repository\n\
baseurl=https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rpms/4.21-el9-beta/\n\
enabled=1\n\
gpgcheck=0\n\
skip_if_unavailable=1\n" \
> /etc/yum.repos.d/openshift.repo

# --------------------------------------------------
# Install ALL required tools in ONE go
# --------------------------------------------------
RUN dnf install -y \
    curl \
    tar \
    createrepo_c \
    jq \
    skopeo \
    firewalld \
    containernetworking-plugins \
    policycoreutils \
 && dnf clean all

# --------------------------------------------------
# Download MicroShift RPMs and build local repo
# --------------------------------------------------
RUN set -eux; \
    mkdir -p /tmp/local-rpms; \
    curl -L --fail --retry 5 "${MICROSHIFT_RPM_URL}" -o /tmp/microshift-rpms.tgz; \
    tar -xzf /tmp/microshift-rpms.tgz -C /tmp/local-rpms; \
    createrepo_c /tmp/local-rpms; \
    printf "[microshift-local]\n\
name=MicroShift Local\n\
baseurl=file:///tmp/local-rpms\n\
enabled=1\n\
gpgcheck=0\n" > /etc/yum.repos.d/microshift-local.repo

# --------------------------------------------------
# Install MicroShift stack (single DNF transaction)
# --------------------------------------------------
RUN dnf install -y --nogpgcheck \
    microshift \
    microshift-kindnet \
    microshift-networking \
    microshift-topolvm \
    microshift-olm \
    microshift-selinux \
 && dnf clean all \
 && rm -rf /tmp/local-rpms /tmp/microshift-rpms.tgz \
 && rm -f /etc/yum.repos.d/microshift-local.repo

# --------------------------------------------------
# Copy assets (grouped for cache efficiency)
# --------------------------------------------------
RUN mkdir -p /etc/cni/net.d \
             /etc/microshift/manifests.d/001-test-app \
             /usr/local/bin \
             /usr/libexec/cni

COPY assets/13-microshift-kindnet.conf /etc/crio/crio.conf.d/
COPY assets/10-kindnet.conflist /etc/cni/net.d/
COPY assets/99-offline.conf /etc/containers/registries.conf.d/

COPY scripts/setup.sh /usr/local/bin/setup-storage.sh
COPY scripts/embed_image.sh /usr/local/bin/embed_image.sh
COPY scripts/copy_embed.sh /usr/local/bin/copy_embed.sh

COPY manifests/test-app.yaml /etc/microshift/manifests.d/001-test-app/
COPY image-list.txt /tmp/image-list.txt

COPY assets/fix-network.sh /usr/bin/fix-network.sh
COPY assets/fix-network.service /etc/systemd/system/

# --------------------------------------------------
# Permissions + embedding (minimal restorecon)
# --------------------------------------------------
RUN chmod +x /usr/local/bin/*.sh /usr/bin/fix-network.sh && \
    chmod 644 /etc/systemd/system/*.service || true

RUN /usr/local/bin/embed_image.sh /tmp/image-list.txt

RUN restorecon -v /usr/local/bin/* \
               /usr/bin/fix-network.sh \
               /etc/systemd/system/* \
               /etc/microshift/manifests.d/001-test-app/*

# --------------------------------------------------
# Firewall + user + systemd units (combined)
# --------------------------------------------------
RUN firewall-offline-cmd --zone=public --add-port=22/tcp \
 && firewall-offline-cmd --zone=public --add-port=80/tcp \
 && firewall-offline-cmd --zone=public --add-port=443/tcp \
 && firewall-offline-cmd --zone=public --add-port=6443/tcp \
 && firewall-offline-cmd --zone=public --add-port=30000-32767/tcp \
 && firewall-offline-cmd --zone=trusted --add-source=10.42.0.0/16 \
 && firewall-offline-cmd --zone=trusted --add-source=169.254.169.1 \
 && useradd -m -d /var/home/hrushabh -G wheel hrushabh \
 && echo "hrushabh:redhat" | chpasswd

# --------------------------------------------------
# Systemd services
# --------------------------------------------------
COPY scripts/microshift-embed.service /usr/lib/systemd/system/

RUN printf "[Unit]\nDescription=Setup Storage\nBefore=microshift.service\n\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/setup-storage.sh\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n" \
    > /etc/systemd/system/microshift-storage-setup.service

RUN printf "[Unit]\nDescription=Make root filesystem shared\nBefore=microshift.service\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/mount --make-rshared /\n\n[Install]\nWantedBy=multi-user.target\n" \
    > /usr/lib/systemd/system/microshift-make-rshared.service

# --------------------------------------------------
# Final cleanup + enable services
# --------------------------------------------------
RUN rm -rf /usr/lib/microshift/manifests/microshift-olm && \
    systemctl enable \
      firewalld \
      microshift-make-rshared.service \
      microshift-embed.service \
      microshift-storage-setup.service \
      fix-network.service \
      microshift.service
