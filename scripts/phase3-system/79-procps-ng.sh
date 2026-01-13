#!/bin/bash
# LFS 12.4 - 8.79. Procps-ng-4.0.5
source "/scripts/common.sh"
PKG_NAME="procps-ng"
check_built "$PKG_NAME" && exit 0
extract "procps-ng"

./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static                        \
            --disable-kill                          \
            --enable-watch8bit

make $MAKEFLAGS
make install

cd .. && rm -rf "procps-ng-"*
mark_built "$PKG_NAME"
