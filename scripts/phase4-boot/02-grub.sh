#!/bin/bash
# LFS 12.2 - 8.4. Portable GRUB Setup (Fixing LVM Probe)

source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="grub-setup"

log "PROCESS" "Configuring portable GRUB..."

# 1. Identify the root partition UUID
ROOT_DEV="/dev/sda2"
ROOT_UUID=$(blkid -s UUID -o value $ROOT_DEV)

if [ -z "$ROOT_UUID" ]; then
    log "ERROR" "Could not determine UUID for $ROOT_DEV."
    exit 1
fi

# 2. CREATE THE DEVICE MAP (Crucial Fix)
# This prevents GRUB from looking at your Ubuntu host's LVM volumes
echo "(hd0) /dev/sda" > /boot/grub/device.map
log "INFO" "Created /boot/grub/device.map to bypass host LVM."

# 3. Install GRUB using the map
# We add --no-floppy to speed things up
grub-install --target=i386-pc --force --no-floppy /dev/sda

# 4. Generate the grub.cfg
cat > /boot/grub/grub.cfg << EOF
set default=0
set timeout=5

insmod part_gpt
insmod ext2

search --no-floppy --fs-uuid --set=root $ROOT_UUID

menuentry "GingerOS (LFS 12.2)" {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 root=UUID=$ROOT_UUID ro console=ttyS0,115200
}
EOF

# Clean up the map so it doesn't cause issues in the final image
rm /boot/grub/device.map

log "INFO" "GRUB installation complete."

mark_built "$PKG_NAME"
