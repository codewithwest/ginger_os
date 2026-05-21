#!/bin/bash
# LFS 13.0  - 8.51. Libffi-3.5.2
source "/lfs/lib/common.sh"
PKG_NAME="libffi"
check_built "$PKG_NAME" && exit 0
extract "libffi"

./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=native

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
