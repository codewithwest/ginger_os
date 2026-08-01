#!/bin/bash
# LFS 13.0  - 8.22. MPFR-4.2.2
source "/lfs/lib/common.sh"
PKG_NAME="mpfr"
check_built "$PKG_NAME" && exit 0
extract "mpfr"

./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-${MPFR_VERSION}

make $MAKEFLAGS
make html

make install
make install-html

cleanup
mark_built "$PKG_NAME"
