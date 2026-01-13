#!/bin/bash
# LFS 12.4 - 8.14. Bc-1.08.1
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="bc"
check_built "$PKG_NAME" && exit 0
extract "bc"

CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r

make $MAKEFLAGS
make install

cd .. && rm -rf "bc-"*
mark_built "$PKG_NAME"
