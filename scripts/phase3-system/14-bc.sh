#!/bin/bash
# LFS 12.4 - 8.14. Bc-1.08.1
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="bc"
check_built "$PKG_NAME" && exit 0
extract "bc"
./configure --prefix=/usr --with-readline
make $MAKEFLAGS
make install
cd .. && rm -rf "bc-"*
mark_built "$PKG_NAME"
