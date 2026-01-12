#!/bin/bash
# LFS 12.4 - 8.21. GMP-6.3.0
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gmp"
check_built "$PKG_NAME" && exit 0
extract "gmp"
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0
make $MAKEFLAGS
make install
cd .. && rm -rf "gmp-"*
mark_built "$PKG_NAME"
