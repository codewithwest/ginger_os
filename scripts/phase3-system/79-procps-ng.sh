#!/bin/bash
# LFS 12.4 - 8.79. Procps-ng-4.0.5
source "$(dirname "$(readlink -f "$0")")/common.sh"
PKG_NAME="procps-ng"
check_built "$PKG_NAME" && exit 0
extract "procps-ng"
./configure --prefix=/usr                            \
            --docdir=/usr/share/doc/procps-ng-4.0.5  \
            --disable-static                         \
            --disable-kill
make $MAKEFLAGS
make install
cd .. && rm -rf "procps-ng-"*
mark_built "$PKG_NAME"
