#!/bin/bash
# LFS 12.4 - 8.25. Acl-2.3.2
source "/scripts/common.sh"
PKG_NAME="acl"
ARCHIVE="acl-2.3.2.tar.xz"
DIR_NAME="acl-2.3.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
