#!/bin/bash
# LFS 12.2 - 8.4. Using GRUB to Set Up the Boot Process

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="grub-setup"

check_built "$PKG_NAME" && exit 0

log "PROCESS" "Installing GRUB to the disk..."
# Assuming we are building into a disk image or device
# We need to know the target device. Usually passed as an env var.

DEVICE=${BOOT_DEVICE:-/dev/sda}

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
