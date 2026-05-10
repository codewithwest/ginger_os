#!/bin/bash
# LFS 12.4 - 7.10. Python-3.13.7 (Temporary)
source "/lfs/lib/common.sh"
PKG_NAME="python-bridge"
check_built "$PKG_NAME" && exit 0
extract "Python"

./configure --prefix=/usr       \
            --enable-shared     \
            --without-ensurepip \
            --without-static-libpython

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
