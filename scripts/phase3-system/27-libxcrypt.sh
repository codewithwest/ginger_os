#!/bin/bash
# LFS 12.4 - 8.27. Libxcrypt-4.4.38
source "$(dirname "$(readlink -f "$0")")/../common.sh"
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

cd .. && rm -rf "libxcrypt-"*
mark_built "$PKG_NAME"
