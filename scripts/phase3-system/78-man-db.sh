#!/bin/bash
# LFS 12.4 - 8.78. Man-DB-2.13.1
source "/scripts/common.sh"
PKG_NAME="man-db"
ARCHIVE="man-db-2.13.1.tar.xz"
DIR_NAME="man-db-2.13.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind       \
            --with-grap=/usr/bin/grap
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
