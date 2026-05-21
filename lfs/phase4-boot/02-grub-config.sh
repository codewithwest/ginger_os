#!/bin/bash
# GingerOS - System Configuration (Chroot Phase)
# Sets up fstab and GRUB configuration inside the system.
# NO USERS are created here to ensure a clean rootfs for the installer.

source "/lfs/lib/common.sh"
PKG_NAME="grub-config"

check_built "$PKG_NAME" && exit 0

log "PROCESS" "Configuring GingerOS internal structure..."

# 1. FSTAB
log "INFO" "Generating /etc/fstab..."
# We use /dev/sda1 as a generic fallback.
# The installer or host-side finalization will refine this with the real UUID.
cat > /etc/fstab << EOF
# /etc/fstab: static file system information.
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/sda1      /               ext4    defaults        1       1
proc           /proc           proc    nosuid,noexec,nodev 0       0
sysfs          /sys            sysfs   nosuid,noexec,nodev 0       0
devpts         /dev/pts        devpts  gid=5,mode=620      0       0
tmpfs          /run            tmpfs   defaults            0       0
devtmpfs       /dev            devtmpfs mode=0755,nosuid    0       0
EOF

# 2. GRUB Config
log "INFO" "Creating GRUB configuration template..."
mkdir -p /boot/grub

set -- /boot/vmlinuz-*
if [ "$#" -eq 0 ] || [ "$1" = '/boot/vmlinuz-*' ]; then
    log "ERROR" "Could not find kernel image in /boot"
    exit 1
fi
KERNEL_FILE=$(basename "$1")

cat > /boot/grub/grub.cfg << GRUB_EOF
set default=0
set timeout=5

insmod part_gpt
insmod part_msdos
insmod ext2
set gfxpayload=1024x768x32

menuentry 'GingerOS (LFS 13.0)' {
    linux /boot/$KERNEL_FILE root=/dev/sda1 rw systemd.show_status=1
}
GRUB_EOF

mark_built "$PKG_NAME"
log "SUCCESS" "Internal system structure initialized."
