#!/bin/bash
# LFS 12.4 - 6.13. Patch-2.8
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="patch-temp"
ARCHIVE="patch-2.8.tar.xz"
DIR_NAME="patch-2.8"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
