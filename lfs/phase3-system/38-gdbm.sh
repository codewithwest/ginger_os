#!/bin/bash
# LFS 13.0  - 8.38. GDBM-1.24
source "/lfs/lib/common.sh"
PKG_NAME="gdbm"
check_built "$PKG_NAME" && exit 0
extract "gdbm"

./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
