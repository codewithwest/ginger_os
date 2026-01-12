#!/bin/bash
# LFS 12.4 - 6.16. Xz-5.8.1
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="xz-temp"
ARCHIVE="xz-5.8.1.tar.xz"
DIR_NAME="xz-5.8.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.8.1
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
