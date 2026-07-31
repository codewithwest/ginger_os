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

# 2. Systemd Boot Configuration
log "INFO" "Configuring systemd for boot..."

# Fix nsswitch.conf to use systemd-resolved
sed -i 's/hosts:          files dns/hosts:          files resolve [!UNAVAIL=RETURN] dns/' /etc/nsswitch.conf

# Clean Ubuntu host services leaked into chroot
rm -f /etc/systemd/system/multi-user.target.wants/console-setup.service
rm -f /etc/systemd/system/multi-user.target.wants/cron.service
rm -f /etc/systemd/system/multi-user.target.wants/dmesg.service
rm -f /etc/systemd/system/multi-user.target.wants/e2scrub_reap.service
rm -f /etc/systemd/system/multi-user.target.wants/networkd-dispatcher.service
rm -f /etc/systemd/system/multi-user.target.wants/rsyslog.service
rm -f /etc/systemd/system/multi-user.target.wants/ua-reboot-cmds.service
rm -f /etc/systemd/system/multi-user.target.wants/ubuntu-advantage.service
rm -f /etc/systemd/system/sysinit.target.wants/keyboard-setup.service
rm -f /etc/systemd/system/sysinit.target.wants/setvtrgb.service
rm -f /etc/systemd/system/sysinit.target.wants/systemd-pstore.service
rm -f /etc/systemd/system/timers.target.wants/apt-daily*.timer
rm -f /etc/systemd/system/timers.target.wants/dpkg-db-backup.timer
rm -f /etc/systemd/system/timers.target.wants/e2scrub_all.timer
rm -f /etc/systemd/system/timers.target.wants/fstrim.timer
rm -f /etc/systemd/system/timers.target.wants/logrotate.timer
rm -f /etc/systemd/system/timers.target.wants/motd-news.timer
rm -f /etc/systemd/system/timers.target.wants/ua-timer.timer
rm -f /etc/systemd/system/syslog.service

# Ensure default target points to multi-user
ln -sf /usr/lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# 3. GRUB Config
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
