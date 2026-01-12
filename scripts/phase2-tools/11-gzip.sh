#!/bin/bash
# LFS 12.4 - 6.11. Gzip-1.14
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gzip-temp"
ARCHIVE="gzip-1.14.tar.xz"
DIR_NAME="gzip-1.14"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --host=$LFS_TGT
make $MAKEFLAGS
make DESTDIR=$LFS install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
