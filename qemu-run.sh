#!/bin/bash
# GingerOS - QEMU Execution Script

source "$(dirname "$(readlink -f "$0")")/config/env.sh"

IMAGE_PATH="${GINGER_ROOT}/ginger_os.img"

if [ ! -f "$IMAGE_PATH" ]; then
    log "ERROR" "Image $IMAGE_PATH not found. Build the system first."
    exit 1
fi

log "INFO" "Starting GingerOS in QEMU..."

qemu-system-x86_64 \
    -m 2G \
    -drive file="$IMAGE_PATH",format=raw \
    -enable-kvm \
    -serial stdio \
    -vga std \
    -display gtk
