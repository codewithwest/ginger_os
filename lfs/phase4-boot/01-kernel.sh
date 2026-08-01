#!/bin/bash
# LFS 13.0  - 10.3. Linux-6.16.1 (Kernel)
source "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
PKG_NAME="kernel"
check_built "$PKG_NAME" && exit 0
extract "linux"

log "PROCESS" "Configuring Kernel..."
make mrproper
make defconfig

if [ -f "$GINGER_ROOT/config/kernel.config" ]; then
    log "INFO" "Merging GingerOS custom kernel requirements..."
    cat "$GINGER_ROOT/config/kernel.config" >> .config
    # olddefconfig accepts all defaults for symbols not in the file
    make olddefconfig
fi

log "PROCESS" "Compiling Kernel and Modules..."
# Adding '|| exit 1' ensures the script stops if compilation fails
make $MAKEFLAGS || { log "ERROR" "Kernel compilation failed!"; exit 1; }
make modules_install || { log "ERROR" "Module installation failed!"; exit 1; }

log "PROCESS" "Installing Kernel..."
# Verify bzImage exists and is not empty before copying
if [ -s arch/x86/boot/bzImage ]; then
    cp -fv arch/x86/boot/bzImage /boot/vmlinuz-${LINUX_VERSION}-lfs-13.0
    cp -fv System.map /boot/System.map-${LINUX_VERSION}
    cp -fv .config /boot/config-${LINUX_VERSION}
    cp -r Documentation -T /usr/share/doc/linux-${LINUX_VERSION}
    # Fix ownership as recommended by LFS 13.0
    chown -R 0:0 .
else
    log "ERROR" "Kernel image (bzImage) is missing or 0 bytes!"
    exit 1
fi

cd ..
cleanup

mark_built "$PKG_NAME"
