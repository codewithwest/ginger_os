#!/bin/bash
# LFS 12.4 - 7.8. Bison-3.8.2 (Temporary)
source "/scripts/common.sh"
PKG_NAME="bison-bridge"
check_built "$PKG_NAME" && exit 0
extract "bison"

./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2

make $MAKEFLAGS
make install

cd .. && rm -rf "bison-"*
mark_built "$PKG_NAME"
