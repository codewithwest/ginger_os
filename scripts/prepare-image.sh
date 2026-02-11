#!/bin/bash
# GingerOS - Disk Image Preparation
# Creates a 20GB raw image, partitions it, and mounts it to $LFS


SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "${SCRIPT_DIR}/../config/env.sh"
source "${SCRIPT_DIR}/common.sh"

IMAGE_PATH="${GINGER_ROOT}/ginger_os.img"

log "INFO" "Creating 20GB sparse disk image..."
# Use truncate instead of dd to create a sparse file (takes almost 0 space until used)
[ -f "$IMAGE_PATH" ] && rm "$IMAGE_PATH"
truncate -s 20G "$IMAGE_PATH"

log "INFO" "Partitioning image..."
# Create a single primary bootable partition
sudo parted -s "$IMAGE_PATH" mklabel msdos
sudo parted -s "$IMAGE_PATH" mkpart primary ext4 1MiB 100%
sudo parted -s "$IMAGE_PATH" set 1 boot on

log "INFO" "Setting up loopback device..."
# Find next available loop device
LOOP_DEV=$(sudo losetup -fP --show "$IMAGE_PATH")

# echo "$LOOP_DEV" > "$GINGER_ROOT/.loopdev"

log "INFO" "Formatting partition..."
sudo mkfs.ext4 "${LOOP_DEV}p1"

log "INFO" "Mounting to $LFS..."
[ -d "$LFS" ] || sudo mkdir -p "$LFS"
sudo mount "${LOOP_DEV}p1" "$LFS"
sudo chown -v lfs:lfs "$LFS"
if ! mountpoint -q "$LFS"; then
    log "ERROR" "Failed to mount LFS filesystem at $LFS"
    exit 1
fi

log "INFO" "Image ready at $LFS (Loop device: $LOOP_DEV)"
log "INFO" "Don't forget to unmount and detach after build."
