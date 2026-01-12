#!/bin/bash
# LFS 12.4 - 8.22. MPFR-4.2.2
source "/scripts/common.sh"
PKG_NAME="mpfr"
ARCHIVE="mpfr-4.2.2.tar.xz"
DIR_NAME="mpfr-4.2.2"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
