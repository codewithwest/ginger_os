#!/bin/bash
# LFS 12.4 - 8.6. Zlib-1.3.1
source "/scripts/common.sh"
PKG_NAME="zlib"
ARCHIVE="zlib-1.3.1.tar.gz"
DIR_NAME="zlib-1.3.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
rm -fv /usr/lib/libz.a
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
