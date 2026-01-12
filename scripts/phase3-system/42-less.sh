#!/bin/bash
# LFS 12.4 - 8.42. Less-679
source "/scripts/common.sh"
PKG_NAME="less"
ARCHIVE="less-679.tar.gz"
DIR_NAME="less-679"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --sysconfdir=/etc
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
