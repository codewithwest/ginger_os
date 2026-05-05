#!/bin/bash
# GingerOS - Host Setup
# Prepares the host system for LFS Phase 1
# MUST be run as root
# Assumes $LFS is already mounted

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

source "${SCRIPT_DIR}/../lib/common.sh"

# ---------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "This script must be run as root"
    exit 1
fi

# LFS="" is valid inside chroot (means we are already at the LFS root)
# Only fail if LFS is completely unset
if [ -z "${LFS+x}" ]; then
    log "ERROR" "LFS variable is not set"
    exit 1
fi

log "INFO" "Using LFS directory: $LFS"

# NOTE: mountpoint/same-device checks from LFS book are intentionally omitted.
# In our containerized build, chroot /mnt/lfs provides equivalent isolation —
# all operations are confined to the img filesystem regardless.

# ---------------------------------------------------------------------
# Create lfs user if it doesn't exist
# ---------------------------------------------------------------------
if ! id lfs &>/dev/null; then
    log "INFO" "Creating lfs user and group..."
    groupadd lfs 2>/dev/null || true
    useradd -s /bin/bash -g lfs -m -k /dev/null lfs
    log "INFO" "lfs user created."
fi

# ---------------------------------------------------------------------
# Prepare base LFS directory
# ---------------------------------------------------------------------
log "INFO" "Ensuring base LFS directory exists..."
mkdir -pv "$LFS"
chown -v root:root "$LFS"

# ---------------------------------------------------------------------
# Create required directory layout
# ---------------------------------------------------------------------
log "INFO" "Creating directory structure..."

# Sources
mkdir -pv "$LFS/sources"
chmod -v a+wt "$LFS/sources"

# Tools directory (temporary toolchain)
mkdir -pv "$LFS/tools"
chown -v lfs "$LFS/tools"

# GingerOS state directory and var structure
mkdir -pv "$LFS/var/lib/ginger"
chown -v lfs "$LFS/var"
chown -v lfs "$LFS/var/lib"
chown -R lfs "$LFS/var/lib/ginger"

# Merged-usr layout (LFS 12.x)
mkdir -pv "$LFS/usr/bin" \
         "$LFS/usr/lib" \
         "$LFS/usr/sbin" \
         "$LFS/usr/include"

for dir in bin lib sbin; do
    if [ ! -L "$LFS/$dir" ]; then
        ln -snv "usr/$dir" "$LFS/$dir"
    fi
done

# Architecture-specific dynamic linker setup
case "$(uname -m)" in
    x86_64)
        mkdir -pv "$LFS/lib64"
        if [ ! -L "$LFS/lib64/ld-linux-x86-64.so.2" ]; then
            ln -sfv ../lib/ld-linux-x86-64.so.2 \
                "$LFS/lib64/ld-linux-x86-64.so.2"
        fi
        ;;
esac

# ---------------------------------------------------------------------
# Copy sources if available
# ---------------------------------------------------------------------
if [ -d "${GINGER_SOURCES:-}" ] && [ "$(ls -A "$GINGER_SOURCES" 2>/dev/null)" ]; then
    log "INFO" "Copying existing sources into $LFS/sources..."
    cp -r "$GINGER_SOURCES/"* "$LFS/sources/"
else
    log "WARN" "No sources found in \$GINGER_SOURCES. Run the download script later."
fi

chown -R lfs "$LFS/sources"
chown -v lfs "$LFS/usr/include"

# ---------------------------------------------------------------------
# Final ownership sanity
# ---------------------------------------------------------------------
log "INFO" "Final ownership checks..."
chown -v lfs "$LFS/tools"
chown -v lfs "$LFS/sources"

chown -R lfs:lfs $LFS

log "INFO" "Host setup complete."
log "INFO" "Switch to the 'lfs' user to begin Phase 1:"
log "INFO" "  su - lfs"
mark_built "03_install_os_base"
