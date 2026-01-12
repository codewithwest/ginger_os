#!/bin/bash
# LFS 12.4 - 8.66. Gzip-1.14
source "/scripts/common.sh"
PKG_NAME="gzip-final"
ARCHIVE="gzip-1.14.tar.xz"
DIR_NAME="gzip-1.14"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
