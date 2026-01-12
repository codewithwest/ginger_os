#!/bin/bash
# LFS 12.4 - 10.3. Linux-6.16.1 (Kernel)
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="kernel"
check_built "$PKG_NAME" && exit 0
extract "linux"

log "PROCESS" "Configuring Kernel..."
make mrproper
# If a pre-existing config exists, use it. Otherwise, use defconfig.
if [ -f "$GINGER_ROOT/config/kernel.config" ]; then
    cp "$GINGER_ROOT/config/kernel.config" .config
else
    make defconfig
fi

log "PROCESS" "Compiling Kernel and Modules (this will take a while)..."
make $MAKEFLAGS
make modules_install

log "PROCESS" "Installing Kernel..."
cp -iv arch/x86/boot/bzImage /boot/vmlinuz-6.16.1-lfs-12.4
cp -iv System.map /boot/System.map-6.16.1
cp -iv .config /boot/config-6.16.1
cp -r Documentation -T /usr/share/doc/linux-6.16.1

cd .. && rm -rf "linux-"*
mark_built "$PKG_NAME"
# Note: Root required for /boot and module installation.
