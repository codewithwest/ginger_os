#!/bin/bash
# LFS 12.4 - 8.63. Findutils-4.10.0
source "$(dirname "$(readlink -f "$0")")/scripts/common.sh"
PKG_NAME="findutils"
check_built "$PKG_NAME" && exit 0
extract "findutils"
./configure --prefix=/usr --localstatedir=/var/lib/locate
make $MAKEFLAGS
make install
cd .. && rm -rf "findutils-"*
mark_built "$PKG_NAME"
