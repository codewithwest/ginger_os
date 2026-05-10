#!/bin/bash
# LFS 12.4 - 8.79. Procps-ng-4.0.5
source "/lfs/lib/common.sh"
PKG_NAME="procps-ng"
check_built "$PKG_NAME" && exit 0
extract "procps-ng"
sed -i '/#include "xalloc.h"/a #include <stdbool.h>' src/watch.c

./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static                        \
            --disable-kill                          \
            --enable-watch8bit

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
