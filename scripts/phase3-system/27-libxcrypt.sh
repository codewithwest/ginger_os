#!/bin/bash
# LFS 12.4 - 8.27. Libxcrypt-4.4.38
source "/scripts/common.sh"
PKG_NAME="libxcrypt"
ARCHIVE="libxcrypt-4.4.38.tar.xz"
DIR_NAME="libxcrypt-4.4.38"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-werror
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
