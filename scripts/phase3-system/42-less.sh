#!/bin/bash
# LFS 12.4 - 8.42. Less-679
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="less"
check_built "$PKG_NAME" && exit 0
extract "less"
./configure --prefix=/usr --sysconfdir=/etc
make $MAKEFLAGS
make install
cd .. && rm -rf "less-"*
mark_built "$PKG_NAME"
