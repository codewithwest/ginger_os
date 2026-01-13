#!/bin/bash
# LFS 12.4 - 8.78. Man-DB-2.14.0
source "/scripts/common.sh"
PKG_NAME="man-db"
check_built "$PKG_NAME" && exit 0
extract "man-db"
./configure --prefix=/usr                        \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=no         \
            --with-systemdsystemunitdir=no
make $MAKEFLAGS
make install
cd .. && rm -rf "man-db-"*
mark_built "$PKG_NAME"
