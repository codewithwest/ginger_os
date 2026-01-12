#!/bin/bash
# LFS 12.4 - 8.13. M4-1.4.19
source "/scripts/common.sh"
PKG_NAME="m4"
ARCHIVE="m4-1.4.19.tar.xz"
DIR_NAME="m4-1.4.19"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
