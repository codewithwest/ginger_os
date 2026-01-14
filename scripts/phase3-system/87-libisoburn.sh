#!/bin/bash
# LFS 12.4 - Libisoburn-1.5.6 (xorriso)
source "/scripts/common.sh"
PKG_NAME="libisoburn"

check_built "$PKG_NAME" && exit 0
extract "libisoburn"

./configure --prefix=/usr              \
            --disable-static           \
            --enable-pkg-check-modules &&
make

make install

cd .. && rm -rf "libisoburn-"*
mark_built "$PKG_NAME"
