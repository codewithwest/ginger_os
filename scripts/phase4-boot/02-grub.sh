#!/bin/bash
# LFS 12.2 - 8.4. Portable GRUB Setup

source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="grub-setup"

log "PROCESS" "Configuring portable GRUB..."

# 1. Identify the root partition UUID
# We target the second partition (gpt2)
ROOT_DEV="/dev/sda2"
ROOT_UUID=$(blkid -s UUID -o value $ROOT_DEV)

if [ -z "$ROOT_UUID" ]; then
    log "ERROR" "Could not determine UUID for $ROOT_DEV. Check /dev nodes."
    exit 1
fi

log "INFO" "Found Root UUID: $ROOT_UUID"

# 2. Install GRUB to the MBR/GPT gap
# We use --force for loopback compatibility
grub-install --target=i386-pc --force /dev/sda

# 3. Generate a dynamic grub.cfg
cat > /boot/grub/grub.cfg << EOF
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

# Serial console for QEMU debugging
serial --unit=0 --speed=115200
terminal_input serial console
terminal_output serial console

insmod part_gpt
insmod ext2

# DYNAMIC SEARCH: This is the key to 'valid bundling'
# It finds the device by UUID and sets it as root, regardless of drive index
search --no-floppy --fs-uuid --set=root $ROOT_UUID

menuentry "GingerOS (LFS 12.2)" {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 root=UUID=$ROOT_UUID ro console=ttyS0,115200
}
EOF

log "INFO" "GRUB installation complete and portable."

mark_built "$PKG_NAME"
