#!/bin/bash
# LFS 12.4 - 8.23. MPC-1.3.1
source "$(dirname "$(readlink -f "$0")")/../common.sh"
PKG_NAME="mpc"
check_built "$PKG_NAME" && exit 0
extract "mpc"
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.3.1
make $MAKEFLAGS
make install
cd .. && rm -rf "mpc-"*
mark_built "$PKG_NAME"
