#!/bin/bash
# LFS 12.4 - 8.31. Sed-4.9
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="sed"
check_built "$PKG_NAME" && exit 0
extract "sed"
./configure --prefix=/usr
make $MAKEFLAGS
make install
cd .. && rm -rf "sed-"*
mark_built "$PKG_NAME"
