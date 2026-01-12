#!/bin/bash
# LFS 12.4 - 8.40. Expat-2.7.1
source "/scripts/common.sh"
PKG_NAME="expat"
ARCHIVE="expat-2.7.1.tar.xz"
DIR_NAME="expat-2.7.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.7.1
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
