#!/bin/bash
# GingerOS - Disk Image Preparation
# Creates a 12GB raw image, partitions it, and mounts it to $LFS


SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

source "${SCRIPT_DIR}/../lib/common.sh"

IMAGE_NAME="${IMAGE_NAME:-ginger_os.img}"
IMAGE_SIZE="${IMAGE_SIZE:-12G}"
IMAGE_PATH="${GINGER_ROOT}/${IMAGE_NAME}"

if [ ! -f "$IMAGE_PATH" ]; then
    log "INFO" "Creating ${IMAGE_SIZE} sparse disk image..."
    truncate -s "${IMAGE_SIZE}" "$IMAGE_PATH"

    log "INFO" "Partitioning image..."
    sudo parted -s "$IMAGE_PATH" mklabel msdos
    sudo parted -s "$IMAGE_PATH" mkpart primary ext4 1MiB 100%
    sudo parted -s "$IMAGE_PATH" set 1 boot on
    NEEDS_FORMAT=true
else
    log "INFO" "Disk image already exists, skipping creation."
    NEEDS_FORMAT=false
fi

log "INFO" "Checking loopback device..."
# Check if image is already mapped to a loop device
LOOP_DEV=$(sudo losetup -j "$IMAGE_PATH" | cut -d: -f1 | head -n1)

if [ -z "$LOOP_DEV" ]; then
    log "INFO" "Setting up loopback device..."
    LOOP_DEV=$(sudo losetup -fP --show "$IMAGE_PATH")
else
    log "INFO" "Using existing loopback device: $LOOP_DEV"
    # Ensure partitions are scanned
    sudo partprobe "$LOOP_DEV"
fi

if [ "$NEEDS_FORMAT" = true ]; then
    log "INFO" "Formatting partition..."
    sudo mkfs.ext4 "${LOOP_DEV}p1"
fi

log "INFO" "Mounting to $LFS..."
[ -d "$LFS" ] || sudo mkdir -p "$LFS"

if mountpoint -q "$LFS"; then
    log "INFO" "$LFS is already mounted."
else
    sudo mount "${LOOP_DEV}p1" "$LFS"
    sudo chown -v lfs:lfs "$LFS"
fi

if ! mountpoint -q "$LFS"; then
    log "ERROR" "Failed to mount LFS filesystem at $LFS"
    exit 1
fi

log "INFO" "Image ready at $LFS (Loop device: $LOOP_DEV)"
log "INFO" "Don't forget to unmount and detach after build."
mark_built "04_prepare_image"
