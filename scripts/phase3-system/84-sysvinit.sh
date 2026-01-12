#!/bin/bash
# LFS 12.4 - 8.84. SysVinit-3.14
source "/scripts/common.sh"
PKG_NAME="sysvinit"
ARCHIVE="sysvinit-3.14.tar.xz"
DIR_NAME="sysvinit-3.14"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
patch -Np1 -i /sources/sysvinit-3.14-consolidated-1.patch
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
