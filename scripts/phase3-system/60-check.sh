#!/bin/bash
# LFS 12.4 - 8.60. Check-0.15.2
source "/scripts/common.sh"
PKG_NAME="check"
ARCHIVE="check-0.15.2.tar.gz"
DIR_NAME="check-0.15.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --disable-static
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
