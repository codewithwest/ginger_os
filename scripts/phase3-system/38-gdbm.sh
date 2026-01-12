#!/bin/bash
# LFS 12.4 - 8.38. GDBM-1.24
source "/scripts/common.sh"
PKG_NAME="gdbm"
ARCHIVE="gdbm-1.24.tar.gz"
DIR_NAME="gdbm-1.24"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
