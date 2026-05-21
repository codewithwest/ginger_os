#!/bin/bash
# LFS 13.0  - 8.23. MPC-1.3.1
source "/lfs/lib/common.sh"
PKG_NAME="mpc"
check_built "$PKG_NAME" && exit 0
extract "mpc"

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.3.1

make $MAKEFLAGS
make html

make install
make install-html

cleanup
mark_built "$PKG_NAME"
