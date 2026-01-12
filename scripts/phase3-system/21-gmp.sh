#!/bin/bash
# LFS 12.4 - 8.21. GMP-6.3.0
source "/scripts/common.sh"
PKG_NAME="gmp"
ARCHIVE="gmp-6.3.0.tar.xz"
DIR_NAME="gmp-6.3.0"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
