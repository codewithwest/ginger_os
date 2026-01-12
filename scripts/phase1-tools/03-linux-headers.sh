#!/bin/bash
# LFS 12.2 - 5.4. Linux-6.10.5 API Headers
# The headers let Glibc communicate with the kernel features.

source "$(dirname "$(readlink -f "$0")")/../common.sh"

PKG_NAME="linux-headers"
PKG_VERSION="$LINUX_VERSION"
ARCHIVE="linux-$LINUX_VERSION.tar.xz"
DIR_NAME="linux-$LINUX_VERSION"

check_built "$PKG_NAME" && exit 0

extract "$ARCHIVE" "$DIR_NAME"

log "PROCESS" "Installing Linux API Headers..."

make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include/* $LFS/usr/include

cd ..
rm -rf "$DIR_NAME"

mark_built "$PKG_NAME"
