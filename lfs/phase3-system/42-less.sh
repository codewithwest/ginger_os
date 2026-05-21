#!/bin/bash
# LFS 13.0  - 8.42. Less-679
source "/lfs/lib/common.sh"
PKG_NAME="less"
check_built "$PKG_NAME" && exit 0
extract "less"

./configure --prefix=/usr --sysconfdir=/etc

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
