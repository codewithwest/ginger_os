#!/bin/bash
# LFS 12.4 - 8.24. Attr-2.5.2
source "/scripts/common.sh"
PKG_NAME="attr"
ARCHIVE="attr-2.5.2.tar.gz"
DIR_NAME="attr-2.5.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.2
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
