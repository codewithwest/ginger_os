#!/bin/bash
# LFS 12.4 - 8.70. Make-4.4.1
source "/scripts/lib/common.sh"
PKG_NAME="make"
check_built "$PKG_NAME" && exit 0
extract "make"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "make-"*
mark_built "$PKG_NAME"
