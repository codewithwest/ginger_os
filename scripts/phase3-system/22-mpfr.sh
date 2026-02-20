#!/bin/bash
# LFS 12.4 - 8.22. MPFR-4.2.2
source "/scripts/lib/common.sh"
PKG_NAME="mpfr"
check_built "$PKG_NAME" && exit 0
extract "mpfr"

./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2

make $MAKEFLAGS
make html

make install
make install-html

cleanup
mark_built "$PKG_NAME"
