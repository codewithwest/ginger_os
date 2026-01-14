#!/bin/bash
# LFS 12.4 - 10.3. Linux-6.16.1 (Kernel)
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="kernel"
check_built "$PKG_NAME" && exit 0
extract "linux"

log "PROCESS" "Configuring Kernel..."
# Only use mrproper for a fresh build; it wipes existing .config
make mrproper

if [ -f "$GINGER_ROOT/config/kernel.config" ]; then
    cp "$GINGER_ROOT/config/kernel.config" .config
else
    make defconfig
fi

log "PROCESS" "Compiling Kernel and Modules..."
# Adding '|| exit 1' ensures the script stops if compilation fails
make $MAKEFLAGS || { log "ERROR" "Kernel compilation failed!"; exit 1; }
make modules_install || { log "ERROR" "Module installation failed!"; exit 1; }

log "PROCESS" "Installing Kernel..."
# Verify bzImage exists and is not empty before copying
if [ -s arch/x86/boot/bzImage ]; then
    cp -iv arch/x86/boot/bzImage /boot/vmlinuz-6.16.1-lfs-12.4
    cp -iv System.map /boot/System.map-6.16.1
    cp -iv .config /boot/config-6.16.1
    cp -r Documentation -T /usr/share/doc/linux-6.16.1
    # Fix ownership as recommended by LFS 12.4
    chown -R 0:0 .
else
    log "ERROR" "Kernel image (bzImage) is missing or 0 bytes!"
    exit 1
fi

cd ..
# LFS 12.4 advises keeping the source tree for BLFS
# If you must remove it, ensure the above copy succeeded.
# rm -rf "linux-"* 

mark_built "$PKG_NAME"
