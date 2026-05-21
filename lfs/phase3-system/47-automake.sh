#!/bin/bash
# LFS 13.0  - 8.47. Automake-1.17
source "/lfs/lib/common.sh"
PKG_NAME="automake"
check_built "$PKG_NAME" && exit 0
extract "automake"
./configure --prefix=/usr --docdir=/usr/share/doc/automake-${AUTOMAKE_VERSION}

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
