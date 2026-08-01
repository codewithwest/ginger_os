#!/bin/bash
# GingerOS - QEMU Execution Script

source "$(dirname "$(readlink -f "$0")")/lfs/lib/common.sh"

IMAGE_PATH="${GINGER_ROOT}/ginger_os.img"

if [ ! -f "$IMAGE_PATH" ]; then
    log "ERROR" "Image $IMAGE_PATH not found. Build the system first."
    exit 1
fi

log "INFO" "Starting GingerOS in QEMU..."

# Detect if host has enough RAM for cache=unsafe
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -ge 8 ]; then
    DISK_CACHE="unsafe"
else
    DISK_CACHE="none"
fi

qemu-system-x86_64 \
    -m 2G \
    -drive file="$IMAGE_PATH",format=raw,if=virtio,aio=native,cache="$DISK_CACHE",discard=on \
    -enable-kvm \
    -serial stdio \
    -vga std \
    -display gtk
