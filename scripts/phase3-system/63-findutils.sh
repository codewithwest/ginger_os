#!/bin/bash
# LFS 12.4 - 8.63. Findutils-4.10.0
source "/scripts/common.sh"
PKG_NAME="findutils-final"
ARCHIVE="findutils-4.10.0.tar.xz"
DIR_NAME="findutils-4.10.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr --localstatedir=/var/lib/locate
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
