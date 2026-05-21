#!/bin/bash
# LFS 13.0  - 8.27. Libxcrypt-4.4.38
source "/lfs/lib/common.sh"
PKG_NAME="libxcrypt"
check_built "$PKG_NAME" && exit 0
extract "libxcrypt"

./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-failure-tokens

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
