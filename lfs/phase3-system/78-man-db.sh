#!/bin/bash
# LFS 13.0  - 8.78. Man-DB-2.14.0
source "/lfs/lib/common.sh"
PKG_NAME="man-db"
check_built "$PKG_NAME" && exit 0
extract "man-db"

./configure --prefix=/usr                         \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc                     \
            --disable-setuid                      \
            --enable-cache-owner=bin              \
            --with-browser=/usr/bin/lynx          \
            --with-vgrind=/usr/bin/vgrind         \
            --with-grap=/usr/bin/grap             \
            --with-systemdtmpfilesdir=            \
            --with-systemdsystemunitdir=
            
make $MAKEFLAGS
make install
cleanup
mark_built "$PKG_NAME"
