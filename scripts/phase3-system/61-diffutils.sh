#!/bin/bash
# LFS 12.4 - 8.61. Diffutils-3.12
source "/scripts/common.sh"
PKG_NAME="diffutils-final"
ARCHIVE="diffutils-3.12.tar.xz"
DIR_NAME="diffutils-3.12"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
