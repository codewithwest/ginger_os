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

cat > /boot/grub/grub.cfg << GRUB_EOF
set default=0
set timeout=5

insmod part_msdos
insmod ext2

menuentry 'GingerOS (LFS 12.4)' {
    linux /boot/vmlinuz-6.16.1-lfs-12.4 root=/dev/sda1 rw quiet loglevel=3 console=tty0
}
GRUB_EOF

mark_built "$PKG_NAME"
log "SUCCESS" "Internal system structure initialized."
