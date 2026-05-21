#!/bin/bash
# LFS 13.0  - 8.21. GMP-6.3.0
source "/lfs/lib/common.sh"
PKG_NAME="gmp"
check_built "$PKG_NAME" && exit 0

extract "gmp"

sed -i '/long long t1;/,+1s/()/(...)/' configure

./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-${GMP_VERSION}
            
make $MAKEFLAGS

make html

make install
make install-html

cleanup
mark_built "$PKG_NAME"
