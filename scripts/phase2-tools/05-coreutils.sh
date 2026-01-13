#!/bin/bash
# LFS 12.4 - 6.5. Coreutils-9.7
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="coreutils-temp"
PKG_VERSION="$COREUTILS_VERSION"
ARCHIVE="coreutils-$COREUTILS_VERSION.tar.xz"
DIR_NAME="coreutils-$COREUTILS_VERSION"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
