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

if [ -z "${LFS:-}" ]; then
    log "ERROR" "LFS variable is not set"
    exit 1
fi

log "INFO" "Using LFS directory: $LFS"

# Warn if LFS is on the host root filesystem
if ! mountpoint -q "$LFS"; then
    log "ERROR" "$LFS is not a mounted filesystem"
    log "ERROR" "Mount the LFS disk or image at $LFS before continuing"
    exit 1
fi

if [ "$(stat -c %d /)" = "$(stat -c %d "$LFS")" ]; then
    log "ERROR" "$LFS is on the host root filesystem"
    log "ERROR" "This will corrupt the host system and break LFS"
    exit 1
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
