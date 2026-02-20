#!/bin/bash
# LFS 12.4 - 8.6. Zlib-1.3.1
source "/scripts/lib/common.sh"
PKG_NAME="zlib"

check_built "$PKG_NAME" && exit 0

extract "zlib"

./configure --prefix=/usr

make $MAKEFLAGS
make install

rm -fv /usr/lib/libz.a

cleanup

mark_built "$PKG_NAME"
