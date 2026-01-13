#!/bin/bash
# LFS 12.4 - 8.38. GDBM-1.24
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="gdbm"
check_built "$PKG_NAME" && exit 0
extract "gdbm"

./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat

make $MAKEFLAGS
make install

cd .. && rm -rf "gdbm-"*
mark_built "$PKG_NAME"
