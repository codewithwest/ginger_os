#!/bin/bash
# LFS 12.4 - 8.8. Xz-5.8.1
source "/scripts/common.sh"
PKG_NAME="xz"
ARCHIVE="xz-5.8.1.tar.xz"
DIR_NAME="xz-5.8.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.1
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
