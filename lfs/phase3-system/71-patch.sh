#!/bin/bash
# LFS 12.4 - 8.71. Patch-2.8
source "/lfs/lib/common.sh"
PKG_NAME="patch"
check_built "$PKG_NAME" && exit 0
extract "patch"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cleanup
mark_built "$PKG_NAME"
