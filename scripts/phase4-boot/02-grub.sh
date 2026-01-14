#!/bin/bash
# LFS 12.2 - 8.4. Using GRUB to Set Up the Boot Process

source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="grub-setup"

log "PROCESS" "Installing GRUB to the disk..."

# 1. Force GRUB to install modules to /boot/grub
# We use --force because grub-install often complains about loop devices
grub-install --target=i386-pc --force /dev/sda

# 2. Get the UUID of the root partition for a "valid" bundle
# This ensures the image boots even if the device name changes
ROOT_UUID=$(blkid -s UUID -o value /dev/sda2)

# 3. Create grub.cfg
cat > /boot/grub/grub.cfg << EOF
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

# Support for Serial Console (Good for QEMU -nographic)
serial --unit=0 --speed=115200
terminal_input serial console
terminal_output serial console

insmod part_gpt
insmod ext4

# Set root partition for GRUB
set root=(hd0,gpt2)

menuentry "GingerOS (LFS 12.2) - Kernel 6.16.1" {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 root=UUID=$ROOT_UUID ro console=ttyS0,115200
}
EOF

log "INFO" "GRUB configured with UUID=$ROOT_UUID"

mark_built "$PKG_NAME"
