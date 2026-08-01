#!/bin/bash
# LFS 13.0  - 7.8. Bison-3.8.2 (Temporary)
source "/lfs/lib/common.sh"
PKG_NAME="bison-bridge"
check_built "$PKG_NAME" && exit 0
extract "bison"

./configure --prefix=/usr --docdir=/usr/share/doc/bison-${BISON_VERSION}

make $MAKEFLAGS
make install

cleanup
mark_built "$PKG_NAME"
