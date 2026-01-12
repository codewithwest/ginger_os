#!/bin/bash
# LFS 12.4 - 8.79. Procps-ng-4.0.5
source "/scripts/common.sh"
PKG_NAME="procps-ng"
ARCHIVE="procps-ng-4.0.5.tar.xz"
DIR_NAME="procps-ng-4.0.5"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                            \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static                         \
            --disable-kill
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
