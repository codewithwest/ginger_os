#!/bin/bash
# LFS 12.4 - 8.47. Automake-1.17
source "/scripts/common.sh"
PKG_NAME="automake"
check_built "$PKG_NAME" && exit 0
extract "automake"
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.17
make $MAKEFLAGS
make install
cd .. && rm -rf "automake-"*
mark_built "$PKG_NAME"
