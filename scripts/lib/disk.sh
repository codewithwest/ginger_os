#!/bin/bash
# GingerOS - Disk Operations Library

disk_get_partition() {
    local DEV=$1
    local PART="${DEV}1"
    # Handle NVMe/MMC naming
    if [[ "$DEV" == *"nvme"* ]] || [[ "$DEV" == *"mmcblk"* ]]; then
        PART="${DEV}p1"
    fi
    echo "$PART"
}

disk_get_uuid() {
    local PART=$1
    blkid -s UUID -o value "$PART"
}

disk_get_loop() {
    local IMG=$1
    local LOOP=$(sudo losetup -j "$IMG" | cut -d: -f1 | head -n 1)
    if [ -z "$LOOP" ]; then
        LOOP=$(sudo losetup -fP --show "$IMG")
    fi
    echo "$LOOP"
}

# Ensures a device is ready for use (unmounted and wiped)
disk_prepare() {
    local DEV=$1
    sudo umount "$DEV"* 2>/dev/null || true
    sudo wipefs -a "$DEV" >/dev/null 2>&1
}
