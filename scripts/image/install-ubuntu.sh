#!/bin/bash
# GingerOS - Ubuntu Base Installer
# Installs a minimal Ubuntu Noble (24.04) base into the mounted QEMU image
# using debootstrap. No need to boot QEMU — this runs entirely from the host
# and writes directly into $LFS (the mounted image partition).
#
# Equivalent to: docker pull ubuntu:24.04
# After this step, all subsequent scripts target $LFS via chroot — like docker exec.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

UBUNTU_RELEASE="${UBUNTU_RELEASE:-noble}"
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"

# ─────────────────────────────────────────────
# Safety checks
# ─────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "This script must be run as root (or via sudo)"
    exit 1
fi

if [ -z "${LFS:-}" ]; then
    log "ERROR" "LFS variable is not set"
    exit 1
fi

if ! mountpoint -q "$LFS"; then
    log "ERROR" "$LFS is not mounted. Run the 'Create QEMU Image' step first."
    exit 1
fi

# ─────────────────────────────────────────────
# Ensure debootstrap is available on the host
# ─────────────────────────────────────────────
echo "__GINGER_PKG_MARKER__: Install debootstrap"
if ! command -v debootstrap &>/dev/null; then
    log "INFO" "debootstrap not found — installing on host..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq debootstrap
    log "INFO" "debootstrap installed successfully."
else
    log "INFO" "debootstrap already available: $(debootstrap --version)"
fi

# ─────────────────────────────────────────────
# Run debootstrap — installs Ubuntu into $LFS
# ─────────────────────────────────────────────
echo "__GINGER_PKG_MARKER__: Debootstrap Ubuntu ${UBUNTU_RELEASE}"

# Check if Ubuntu base is already installed (has /usr/bin/apt)
if [ -f "${LFS}/usr/bin/apt" ]; then
    log "INFO" "Ubuntu base already detected at $LFS, skipping debootstrap."
else
    log "INFO" "Installing Ubuntu ${UBUNTU_RELEASE} base into $LFS..."
    log "INFO" "Mirror: $UBUNTU_MIRROR"
    log "INFO" "This may take several minutes depending on network speed..."

    debootstrap \
        --arch=amd64 \
        --include=apt,wget,curl,sudo,bash,coreutils,util-linux,procps,net-tools \
        "${UBUNTU_RELEASE}" \
        "${LFS}" \
        "${UBUNTU_MIRROR}"

    log "INFO" "Ubuntu base installed successfully."
fi

# ─────────────────────────────────────────────
# Configure the Ubuntu base inside the image
# ─────────────────────────────────────────────
echo "__GINGER_PKG_MARKER__: Configure Ubuntu Base"
log "INFO" "Configuring Ubuntu base system..."

# Set hostname
echo "gingeros" | tee "${LFS}/etc/hostname" > /dev/null

# Configure apt sources
cat > "${LFS}/etc/apt/sources.list" <<EOF
deb ${UBUNTU_MIRROR} ${UBUNTU_RELEASE} main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_RELEASE}-updates main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_RELEASE}-security main restricted universe multiverse
EOF

# Copy host resolv.conf so the chroot has network access
if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf "${LFS}/etc/resolv.conf"
fi

# Set timezone
echo "UTC" > "${LFS}/etc/timezone"

# Create /etc/fstab stub inside the image
cat > "${LFS}/etc/fstab" <<EOF
# GingerOS fstab — populated by the build process
proc            /proc           proc    defaults        0 0
sysfs           /sys            sysfs   defaults        0 0
devpts          /dev/pts        devpts  gid=5,mode=620  0 0
tmpfs           /run            tmpfs   defaults        0 0
EOF

log "INFO" "Ubuntu base configuration complete."

# ─────────────────────────────────────────────
# Set correct ownership for subsequent LFS build
# ─────────────────────────────────────────────
echo "__GINGER_PKG_MARKER__: Set Ownership"
# Ensure root owns the LFS root (LFS user setup comes later in setup-host.sh)
chown -v root:root "${LFS}"

log "INFO" "Ubuntu ${UBUNTU_RELEASE} base is ready at $LFS"
log "INFO" "The image can now be used like a container — all subsequent"
log "INFO" "build steps run from the host and chroot into $LFS (like docker exec)."

mark_built "02_install_ubuntu"
