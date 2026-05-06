#!/bin/bash
# LFS 12.4 - Libisofs-1.5.6
source "/scripts/lib/common.sh"
PKG_NAME="libisofs"

check_built "$PKG_NAME" && exit 0
extract "libisofs"

./configure --prefix=/usr --disable-static && 

make $MAKEFLAGS 
make install

cleanup
mark_built "$PKG_NAME"
