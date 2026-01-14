#!/bin/bash
# LFS 12.2 - Final Bootloader Setup

source "$(dirname "$(readlink -f "$0")")/../common.sh"

log "PROCESS" "Starting Final GRUB Installation..."

# 1. Identify the UUID (Now that /dev/sda1 is confirmed)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda1)
log "INFO" "Syncing with UUID: $ROOT_UUID"

# 2. Ensure /etc/fstab exists (The 'Valid Bundle' Requirement)
log "INFO" "Updating /etc/fstab..."
cat > /etc/fstab << EOF
# file system      mount-point  type     options             dump  pass
UUID=$ROOT_UUID    /            ext4     defaults            1     1
proc               /proc        proc     nosuid,noexec,nodev 0     0
sysfs              /sys         sysfs    nosuid,noexec,nodev 0     0
EOF

# 3. Create directory and Map (Bypasses Ubuntu LVM error)
mkdir -p /boot/grub
echo "(hd0) /dev/sda" > /boot/grub/device.map

# 4. Physical Install with your requested modules
grub-install --target=i386-pc \
             --boot-directory=/boot \
             --modules="part_msdos ext2 biosdisk" \
             --force \
             --no-floppy /dev/sda

# 5. Create the configuration
cat > /boot/grub/grub.cfg << EOF
set default=0
set timeout=5

# Load essential modules
insmod part_msdos
insmod ext2

# Portable search
search --no-floppy --fs-uuid --set=root $ROOT_UUID

menuentry "GingerOS (LFS 12.2)" {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 root=UUID=$ROOT_UUID ro console=ttyS0,115200
}
EOF

# Clean up temporary map
rm /boot/grub/device.map

log "SUCCESS" "Bootloader is fully configured."