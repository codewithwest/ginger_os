#!/bin/bash
# LFS 12.4 - 8.71. Patch-2.8
source "/scripts/common.sh"
PKG_NAME="patch-final"
ARCHIVE="patch-2.8.tar.xz"
DIR_NAME="patch-2.8"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
