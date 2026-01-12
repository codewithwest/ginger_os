#!/bin/bash
# LFS 12.4 - 8.23. MPC-1.3.1
source "/scripts/common.sh"
PKG_NAME="mpc"
ARCHIVE="mpc-1.3.1.tar.gz"
DIR_NAME="mpc-1.3.1"
check_built "$PKG_NAME" && exit 0
extract "$ARCHIVE" "$DIR_NAME"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.3.1
make $MAKEFLAGS
make install
cd .. && rm -rf "$DIR_NAME"
mark_built "$PKG_NAME"
