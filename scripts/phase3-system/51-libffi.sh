#!/bin/bash
# LFS 12.4 - 8.51. Libffi-3.5.2
source "/scripts/common.sh"
PKG_NAME="libffi"
check_built "$PKG_NAME" && exit 0
extract "libffi"

./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=native

make $MAKEFLAGS
make install

cd .. && rm -rf "libffi-"*
mark_built "$PKG_NAME"
