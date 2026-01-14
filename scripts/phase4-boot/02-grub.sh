#!/bin/bash
# LFS 12.2 - Final Hybrid GRUB Setup

source "$(dirname "$(readlink -f "$0")")/../common.sh"

log "PROCESS" "Starting Hybrid GRUB Installation..."

# 1. Ensure device nodes exist so blkid works
if [ ! -b /dev/sda1 ]; then
    mknod /dev/sda b 8 0
    mknod /dev/sda1 b 8 1
fi

# 2. Identify the REAL root partition UUID
ROOT_UUID=$(blkid -s UUID -o value /dev/sda1)
log "INFO" "Syncing with UUID: $ROOT_UUID"

# 3. Create /etc/fstab (If it's missing, the kernel will panic)
if [ ! -f /etc/fstab ]; then
    log "INFO" "Creating missing /etc/fstab..."
    cat > /etc/fstab << EOF
UUID=$ROOT_UUID  /      ext4     defaults            1     1
proc               /proc  proc     nosuid,noexec,nodev 0     0
sysfs              /sys   sysfs    nosuid,noexec,nodev 0     0
EOF
fi

# 4. Physical Install (Your Module approach + LVM fix)
echo "(hd0) /dev/sda" > /boot/grub/device.map
grub-install /dev/sda \
    --target=i386-pc \
    --modules="part_msdos ext2 biosdisk" \
    --force \
    --no-floppy

# 5. Logical Config (Portable UUID approach)
cat > /boot/grub/grub.cfg << EOF
set default=0
set timeout=2

# Load modules just in case
insmod part_msdos
insmod ext2

# Search by UUID for bundle-safety
search --no-floppy --fs-uuid --set=root $ROOT_UUID

menuentry "GingerOS (LFS 12.2)" {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 root=UUID=$ROOT_UUID ro console=ttyS0,115200
}
EOF

rm /boot/grub/device.map
log "SUCCESS" "Image is now boot-ready and bundle-safe."