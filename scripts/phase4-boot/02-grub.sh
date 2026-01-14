#!/bin/bash
# LFS 12.2 - 8.4. Using GRUB to Set Up the Boot Process

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="grub-setup"

check_built "$PKG_NAME" && exit 0

log "PROCESS" "Installing GRUB to the disk..."
# Assuming we are building into a disk image or device
# We need to know the target device. Usually passed as an env var.

# Auto-detect the device if not specified
if [ -z "${BOOT_DEVICE}" ]; then
    # Find the device mounted at /
    CURRENT_DEV=$(df --output=source / | tail -n1)
    
    # Handle loopback devices (e.g., /dev/loop0p1 -> /dev/loop0)
    if [[ "$CURRENT_DEV" == *loop* ]]; then
        DEVICE=$(echo "$CURRENT_DEV" | sed 's/p[0-9]\+$//')
    # Handle standard partitions (e.g., /dev/sda1 -> /dev/sda)
    elif [[ "$CURRENT_DEV" == *[0-9] ]]; then
        DEVICE=$(echo "$CURRENT_DEV" | sed 's/[0-9]\+$//')
    else
        DEVICE="/dev/loop0" # Fallback safe guess for this workflow
    fi
else
    DEVICE="${BOOT_DEVICE}"
fi

log "INFO" "Detected install device: $DEVICE (from $CURRENT_DEV)"

# Install GRUB files to /boot
grub-install "$DEVICE"

# Create grub.cfg
cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0,msdos1)

menuentry "GingerOS (LFS 12.4)" {
        linux   /boot/vmlinuz-$LINUX_VERSION-lfs-12.4 root=/dev/sda1 ro
}
EOF

mark_built "$PKG_NAME"
