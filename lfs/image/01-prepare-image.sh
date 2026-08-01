#!/bin/bash
# GingerOS - Disk Image Preparation
# Creates a *GB raw image, partitions it, and mounts it to $LFS


SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

source "${SCRIPT_DIR}/../lib/common.sh"

IMAGE_NAME="${IMAGE_NAME:-ginger_os.img}"
IMAGE_SIZE="${IMAGE_SIZE:-32G}"
IMAGE_PATH="${GINGER_ROOT}/${IMAGE_NAME}"
BUILD_TYPE="${BUILD_TYPE:-image}"

if [ "$BUILD_TYPE" = "native" ]; then
    log "INFO" "Native build detected. Skipping disk image preparation."
    if grep -q "$LFS " /proc/mounts; then
        log "INFO" "$LFS is already mounted. Ready."
        exit 0
    else
        log "ERROR" "LFS partition is not mounted at $LFS. Please mount it manually for native builds."
        exit 1
    fi
fi

NEEDS_FORMAT=false

if [ ! -f "$IMAGE_PATH" ]; then
    log "INFO" "Creating ${IMAGE_SIZE} sparse disk image..."
    truncate -s "${IMAGE_SIZE}" "$IMAGE_PATH"
    NEEDS_FORMAT=true
else
    log "INFO" "Disk image already exists, skipping creation."
fi

log "INFO" "Checking loopback device..."
# Attach loop device first — parted requires a block device, not a plain file
LOOP_DEV=$(sudo losetup -j "$IMAGE_PATH" | cut -d: -f1 | head -n1)

if [ -z "$LOOP_DEV" ]; then
    log "INFO" "Setting up loopback device..."
    LOOP_DEV=$(sudo losetup -fP --show "$IMAGE_PATH")
else
    log "INFO" "Using existing loopback device: $LOOP_DEV"
    sudo partprobe "$LOOP_DEV"
fi

if [ "$NEEDS_FORMAT" = true ]; then
    log "INFO" "Partitioning image via loop device $LOOP_DEV..."
    sudo parted -s "$LOOP_DEV" mklabel msdos
    sudo parted -s "$LOOP_DEV" mkpart primary ext4 1MiB 100%
    sudo parted -s "$LOOP_DEV" set 1 boot on
    sudo partprobe "$LOOP_DEV"

    log "INFO" "Formatting partition..."
    sudo mkfs.ext4 "${LOOP_DEV}p1"
fi

log "INFO" "Mounting to $LFS..."
[ -d "$LFS" ] || sudo mkdir -p "$LFS"

if grep -q "$LFS " /proc/mounts; then
    log "INFO" "$LFS is already mounted."
else
    sudo mount "${LOOP_DEV}p1" "$LFS"
fi

if ! grep -q "$LFS " /proc/mounts; then
    log "ERROR" "Failed to mount LFS filesystem at $LFS"
    exit 1
fi

log "INFO" "Image ready at $LFS (Loop device: $LOOP_DEV)"
log "INFO" "Don't forget to unmount and detach after build."
mark_built "01_create_qemu_img"
