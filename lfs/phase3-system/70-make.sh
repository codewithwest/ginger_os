#!/bin/bash
# LFS 13.0  - 8.70. Make-4.4.1
source "/lfs/lib/common.sh"
PKG_NAME="make"
check_built "$PKG_NAME" && exit 0
extract "make"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cleanup
mark_built "$PKG_NAME"
