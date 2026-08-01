#!/bin/bash
# LFS 13.0  - 8.14. Bc-1.08.1
source "/lfs/lib/common.sh"
PKG_NAME="bc"
check_built "$PKG_NAME" && exit 0
extract "bc"

CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
