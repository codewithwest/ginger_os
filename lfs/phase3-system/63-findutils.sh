#!/bin/bash
# LFS 13.0  - 8.63. Findutils-4.10.0
source "/lfs/lib/common.sh"
PKG_NAME="findutils"
check_built "$PKG_NAME" && exit 0
extract "findutils"

./configure --prefix=/usr --localstatedir=/var/lib/locate

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
