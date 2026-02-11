#!/bin/bash
# LFS 12.4 - 8.8. Xz-5.8.1
source "/scripts/lib/common.sh"
PKG_NAME="xz-final"
check_built "$PKG_NAME" && exit 0
extract "xz"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.1


make $MAKEFLAGS
make install

cd .. && rm -rf "xz-"*
mark_built "$PKG_NAME"
