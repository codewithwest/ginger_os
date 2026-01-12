#!/bin/bash
# LFS 12.4 - 8.13. M4-1.4.20
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="m4"
check_built "$PKG_NAME" && exit 0
extract "m4"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "m4-"*
mark_built "$PKG_NAME"
