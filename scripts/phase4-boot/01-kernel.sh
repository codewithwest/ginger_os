#!/bin/bash
# LFS 12.2 - 8.3. Linux-6.10.5 Kernel
# The heart of the operating system.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="kernel"
PKG_VERSION="$LINUX_VERSION"
ARCHIVE="linux-$LINUX_VERSION.tar.xz"
DIR_NAME="linux-$LINUX_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Configuring Kernel..."

# In a fully scripted build, we should provide a pre-made config.
# If config doesn't exist, we use defconfig as a base.
if [ -f "$GINGER_ROOT/config/kernel.config" ]; then
    cp "$GINGER_ROOT/config/kernel.config" .config
else
    make defconfig
    log "WARN" "Using defconfig. For a production system, use a tailored config."
fi

log "PROCESS" "Compiling Kernel..."
make $MAKEFLAGS

log "PROCESS" "Installing Kernel..."
make modules_install
cp -iv arch/x86/boot/bzImage /boot/vmlinuz-$LINUX_VERSION-lfs-12.4
cp -iv System.map /boot/System.map-$LINUX_VERSION
cp -iv .config /boot/config-$LINUX_VERSION

# Install documentation
install -d /usr/share/doc/linux-$LINUX_VERSION
cp -r Documentation/* /usr/share/doc/linux-$LINUX_VERSION

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
