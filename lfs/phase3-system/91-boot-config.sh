#!/bin/bash
# GingerOS - Systemd Boot Configuration (LFS 13.0 systemd branch)
source "/lfs/lib/common.sh"
PKG_NAME="boot-config"
check_built "$PKG_NAME" && exit 0

log "INFO" "Configuring systemd boot settings..."

mkdir -pv /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf << "CONF"
[Service]
TTYVTDisallocate=no
CONF

mkdir -pv /etc/udev/rules.d
cat > /etc/udev/rules.d/83-duplicate_devs.rules << "RULES"
# Persistent symlinks for duplicate devices (e.g. webcams, tuners)
# Figure out attributes with: udevadm info -a -p /sys/class/video4linux/video0
# KERNEL=="video*", ATTRS{idProduct}=="1910", ATTRS{idVendor}=="0d81", SYMLINK+="webcam"
RULES

mark_built "$PKG_NAME"
